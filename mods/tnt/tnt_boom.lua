
-- Localize for performance.
local vector_distance = vector.distance
local vector_round = vector.round
local math_floor = math.floor
local math_random = math.random
local math_min = math.min
local math_max = math.max

-- Fill a list with data for content IDs, after all nodes are registered
local cid_data = {}
minetest.register_on_mods_loaded(function()
	for name, def in pairs(minetest.registered_nodes) do
		cid_data[minetest.get_content_id(name)] = {
			name = name,

			-- Why is this misspelled? Not used? (drops: no such key)
			drops = def.drops,

			_tnt_drop = def._tnt_drop,
			flammable = def.groups.flammable,
			on_blast = def.on_blast,
      on_destruct = def.on_destruct,
      after_destruct = def.after_destruct,
      _is_bulk_mapgen_stone = def._is_bulk_mapgen_stone,
		}
	end
end)

-- loss probabilities array (one in X will be lost)
local stack_loss_prob = {}
stack_loss_prob["default:cobble"] = 4
stack_loss_prob["rackstone:redrack"] = 4
stack_loss_prob["default:ice"] = 4

local function rand_pos(center, pos, radius)
  pos.x = center.x + math_random(-radius, radius)
  pos.z = center.z + math_random(-radius, radius)
  
  -- Keep picking random positions until a position inside the sphere is chosen.
  -- This gives us a uniform (flattened) spherical distribution.
  while vector_distance(center, pos) >= radius do
    pos.x = center.x + math_random(-radius, radius)
    pos.z = center.z + math_random(-radius, radius)
  end
end

local function eject_drops(drops, pos, radius)
  local drop_pos = vector.new(pos)

  for _, item in pairs(drops) do
		local count = math_min(item:get_count(), item:get_stack_max())

		while count > 0 do
			local take = math_max(1, math_min(radius * radius, count, item:get_stack_max()))

			rand_pos(pos, drop_pos, radius*0.9)
			local dropitem = ItemStack(item)
			dropitem:set_count(take)

			local obj = minetest.add_item(drop_pos, dropitem)
			if obj then
				obj:get_luaentity().collect = true
				obj:set_acceleration({x = 0, y = -10, z = 0})
				obj:set_velocity({x = math_random(-3, 3), y = math_random(0, 10), z = math_random(-3, 3)})

				droplift.invoke(obj, math_random(3, 10))
			end

			count = count - take
		end
  end
end

local function add_drop(drops, item)
	-- Make sure it's an item stack.
	item = ItemStack(item)
	local name = item:get_name()
	
	-- Deal with trash.
	if stack_loss_prob[name] ~= nil and math_random(1, stack_loss_prob[name]) == 1 then
		return
	end

	local drop = drops[name]
	if drop == nil then
		drops[name] = item
	else
		-- Note: this should NOT get clamped by stack_max anymore.
		drop:set_count(drop:get_count() + item:get_count())
	end
end

local function destroy(drops, npos, cid, c_air, c_fire, on_blast_queue, on_destruct_queue, on_after_destruct_queue, fire_locations, ignore_protection, ignore_on_blast, pname)
	-- This, right here, is probably what slows TNT code down the most.
  -- Perhaps we can avoid the issue by not allowing TNT to be placed within
  -- a hundred meters of a city block?
  -- Must also consider: explosions caused by mobs, arrows, other code ...
  -- Idea: TNT blasts ignore protection, but TNT can only be placed away from
  -- cityblocks. Explosions from mobs and arrows respect protection as usual.
  if not ignore_protection then
    if minetest.test_protection(npos, pname) then
      return cid
    end
	end

  local def = cid_data[cid]
  if not def then
    return c_air
  end
  
  if def.on_destruct then
    -- Queue on_destruct callbacks only if ignoring on_blast.
    if ignore_on_blast or not def.on_blast then
      on_destruct_queue[#on_destruct_queue+1] = {
        pos = vector.new(npos),
        on_destruct = def.on_destruct,
      }
    end
  end

  if def.after_destruct then
    -- Queue after_destruct callbacks only if ignoring on_blast.
    if ignore_on_blast or not def.on_blast then
      on_after_destruct_queue[#on_after_destruct_queue+1] = {
        pos = vector.new(npos),
        after_destruct = def.after_destruct,
        oldnode = minetest.get_node(npos),
      }
    end
  end

	if not ignore_on_blast and def.on_blast then
		on_blast_queue[#on_blast_queue + 1] = {
      pos = vector.new(npos),
      on_blast = def.on_blast,
    }
		return cid
	elseif def.flammable then
    fire_locations[#fire_locations+1] = vector.new(npos)
		return c_fire
	elseif def._is_bulk_mapgen_stone then
		-- Ignore drops.
		return c_air
	elseif def._tnt_drop then
		local t = type(def._tnt_drop)
		if t == "string" then
			add_drop(drops, def._tnt_drop)
		elseif t == "table" then
			local b = def._tnt_drop
			for k = 1, #b do
				add_drop(drops, b[k])
			end
		end
		return c_air
	else
		local node_drops = minetest.get_node_drops(def.name, "")
		for k = 1, #node_drops do
			add_drop(drops, node_drops[k])
		end
		return c_air
	end
end

local function calc_velocity(pos1, pos2, old_vel, power)
	-- Avoid errors caused by a vector of zero length
	if vector.equals(pos1, pos2) then
		return old_vel
	end

	local vel = vector.direction(pos1, pos2)
	vel = vector.normalize(vel)
	vel = vector.multiply(vel, power)

	-- Divide by distance
	local dist = vector_distance(pos1, pos2)
	dist = math_max(dist, 1)
	vel = vector.divide(vel, dist)

	-- Add old velocity
	vel = vector.add(vel, old_vel)

	-- randomize it a bit
	vel = vector.add(vel, {
		x = math_random() - 0.5,
		y = math_random() - 0.5,
		z = math_random() - 0.5,
	})

	-- Limit to terminal velocity
	dist = vector.length(vel)
	if dist > 250 then
		vel = vector.divide(vel, dist / 250)
	end
	return vel
end

local function entity_physics(pos, radius, drops, boomdef)
	local objs = minetest.get_objects_inside_radius(pos, radius)
	for _, obj in pairs(objs) do
		local obj_pos = obj:get_pos()
		local dist = math_max(1, vector_distance(pos, obj_pos))

		-- Calculate damage to be applied to player or mob.
		local SCALE = 500
		local damage = ((8 / dist) * radius) * SCALE

		if obj:is_player() then
			local pname = obj:get_player_name()

			-- Admin is exempt from TNT blasts.
			if not gdac.player_is_admin(obj) then
				-- Damage player. For reasons having to do with bone placement, this
				-- needs to happen before any knockback effects. And knockback effects
				-- should only be applied if the player does not actually die.
				if obj:get_hp() > 0 then
					local dg = {
						boom = damage,
					}

					local hitter = obj

					-- If tnt was launched by a player, use them as the hitter.
					if boomdef.name and boomdef.name ~= "" and boomdef.from_arrow then
						dg.from_arrow = 0

						local pref = minetest.get_player_by_name(boomdef.name)
						if pref then
							hitter = pref
						end
					end

					armor.notify_punch_reason({reason="boom"})
					obj:punch(hitter, 1.0, {
						full_punch_interval = 1.0,
						max_drop_level = 0,
						damage_groups = dg,
					}, nil)

					if obj:get_hp() <= 0 then
						if player_labels.query_nametag_onoff(pname) == true and not cloaking.is_cloaked(pname) then
							minetest.chat_send_all("# Server: <" .. rename.gpn(pname) .. "> exploded.")
						else
							minetest.chat_send_all("# Server: Someone exploded.")
						end
					end
				end

				-- Do knockback only if player didn't die.
				if obj:get_hp() > 0 then
					-- HACK: do not apply knockback if the player is in a duel.
					-- This has a HIGH chance of causing fall damage leading to death, which would
					-- bypass the duel!
					-- This check is needed because it is way too easy to kill someone by fall damage
					-- when using TNT arrows.
					if not armor.dueling_players[obj:get_player_name()] then
						local dir = vector.normalize(vector.subtract(obj_pos, pos))
						local moveoff = vector.multiply(dir, 2 / dist * radius)
						moveoff = vector.multiply(moveoff, 3)
						moveoff.y = math.min(math.abs(moveoff.y), 20)
						obj:add_player_velocity(moveoff)
					end
				end
			end
		else
			local do_damage = true
			local do_knockback = true
			local entity_drops = {}
			local luaobj = obj:get_luaentity()

			-- Ignore mobs of the same type as the one that launched the TNT boom.
			local ignore = false
			if boomdef.mob and luaobj.mob and boomdef.mob == luaobj.name then
				ignore = true
			end

			if not ignore then
				local objdef = minetest.registered_entities[luaobj.name]

				if objdef and objdef.on_blast then
					do_damage, do_knockback, entity_drops = objdef.on_blast(luaobj, damage)
				end

				if do_knockback then
					local obj_vel = obj:get_velocity()
					obj:set_velocity(calc_velocity(pos, obj_pos,
							obj_vel, radius * 10))
				end

				if do_damage then
					if not obj:get_armor_groups().immortal then
						obj:punch(obj, 1.0, {
							full_punch_interval = 1.0,
							damage_groups = {boom = damage},
						}, nil)
					end
				end

				for k = 1, #entity_drops do
					add_drop(drops, entity_drops[k])
				end
			end
		end
	end
end

local function add_effects(pos, radius, drops)
	minetest.add_particle({
		pos = pos,
		velocity = vector.new(),
		acceleration = vector.new(),
		expirationtime = 0.4,
		size = radius * 10,
		collisiondetection = false,
		vertical = false,
		texture = "tnt_boom.png",
	})
	minetest.add_particlespawner({
		amount = 64,
		time = 0.5,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x = -10, y = -10, z = -10},
		maxvel = {x = 10, y = 10, z = 10},
		minacc = vector.new(),
		maxacc = vector.new(),
		minexptime = 1,
		maxexptime = 2.5,
		minsize = radius * 3,
		maxsize = radius * 5,
		texture = "tnt_smoke.png",
	})
	
	-- we just dropped some items. Look at the items entities and pick
	-- one of them to use as texture
	local texture = "tnt_blast.png" --fallback texture
	local most = 0
	for name, count in pairs(drops) do
		--local count = stack:get_count()
		if count > most then
			most = count
			local def = minetest.registered_nodes[name]
			if def and def.tiles and def.tiles[1] then
				if type(def.tiles[1]) == "string" then
					texture = def.tiles[1]
				end
			end
		end
	end

	minetest.add_particlespawner({
		amount = 64,
		time = 0.1,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x = -3, y = 0, z = -3},
		maxvel = {x = 3, y = 5,  z = 3},
		minacc = {x = 0, y = -10, z = 0},
		maxacc = {x = 0, y = -10, z = 0},
		minexptime = 0.8,
		maxexptime = 2.0,
		minsize = radius * 0.66,
		maxsize = radius * 2,
		texture = texture,
		collisiondetection = true,
	})
end



-- Quickly check for protection in an area.
local function check_protection(pos, radius, pname)
	-- How much beyond the radius to check for protections.
	local e = 10

	local minp = vector.new(pos.x-(radius+e), pos.y-(radius+e), pos.z-(radius+e))
	local maxp = vector.new(pos.x+(radius+e), pos.y+(radius+e), pos.z+(radius+e))

	-- Step size, to avoid checking every single node.
	-- This assumes protections cannot be smaller than this size.
	local ss = 5
	local check = minetest.test_protection

	for x=minp.x, maxp.x, ss do
		for y=minp.y, maxp.y, ss do
			for z=minp.z, maxp.z, ss do
				if check({x=x, y=y, z=z}, pname) then
					-- Protections are present.
					return true
				end
			end
		end
	end

	-- Nothing in the area is protected.
	return false
end



local function tnt_explode(pos, radius, ignore_protection, ignore_on_blast, pname, protection_name)
	pos = vector_round(pos)
	-- scan for adjacent TNT nodes first, and enlarge the explosion
	local vm1 = VoxelManip()
	local p1 = vector.subtract(pos, 3)
	local p2 = vector.add(pos, 3)
	local minp, maxp = vm1:read_from_map(p1, p2)
	local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	local data = vm1:get_data()
	local count = 0
	local c_tnt = minetest.get_content_id("tnt:tnt")
	local c_tnt_burning = minetest.get_content_id("tnt:tnt_burning")
	local c_tnt_boom = minetest.get_content_id("tnt:boom")
	local c_air = minetest.get_content_id("air")

	for z = pos.z - 3, pos.z + 3 do
	for y = pos.y - 3, pos.y + 3 do
	for x = pos.x - 3, pos.x + 3 do
		local vi = a:index(x, y, z)
		local cid = data[vi]
		if cid == c_tnt or cid == c_tnt_boom or cid == c_tnt_burning then
			count = count + 1
			data[vi] = c_air
		end
	end
	end
	end
	
	-- The variable 'count' may be 0 if the bomb exploded in a protected area. In
	-- which case no "tnt boom" flash (node) will have been created. Clamping
	-- 'count' to a minimum of 1 fixes the problem.
	-- [MustTest]
	if count < 1 then
		count = 1
	end
  
  -- Clamp to avoid massive explosions.
  if count > 64 then count = 64 end

	vm1:set_data(data)
	vm1:write_to_map()

	-- recalculate new radius
	radius = math_floor(radius * math.pow(count, 0.60))

	-- If no protections are present, we can optimize by skipping the protection
	-- check for individual nodes. If we have a small radius, then don't bother.
	if radius > 8 then
		if not check_protection(pos, radius, protection_name) then
			ignore_protection = true
		end
	end

	-- perform the explosion
	local vm = VoxelManip()
	local pr = PseudoRandom(os.time())
	p1 = vector.subtract(pos, radius)
	p2 = vector.add(pos, radius)
	minp, maxp = vm:read_from_map(p1, p2)
	a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	data = vm:get_data()

	local drops = {}
	local on_blast_queue = {}
  local on_destruct_queue = {}
  local on_after_destruct_queue = {}
  local fire_locations = {}

	local c_fire = minetest.get_content_id("fire:basic_flame")
  
	for z = -radius, radius do
	for y = -radius, radius do
	local vi = a:index(pos.x + (-radius), pos.y + y, pos.z + z)
	for x = -radius, radius do
		local r = vector.length(vector.new(x, y, z))
    local r2 = radius
    
    -- Roughen the walls a bit.
    if pr:next(0, 6) == 0 then
      r2 = radius - 0.8
    end
      
    if r <= r2 then
			local cid = data[vi]
			local p = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
			if cid ~= c_air then
				data[vi] = destroy(drops, p, cid, c_air, c_fire,
					on_blast_queue, on_destruct_queue, on_after_destruct_queue,
          fire_locations, ignore_protection, ignore_on_blast, protection_name)
			end
		end
    
		vi = vi + 1
	end
	end
	end
  
  -- Call on_destruct callbacks.
  for k = 1, #on_destruct_queue do
		local v = on_destruct_queue[k]
    v.on_destruct(v.pos)
  end

	vm:set_data(data)
	vm:write_to_map()
	vm:update_map()
	vm:update_liquids()

	-- Check unstable nodes for everything within blast effect.
	local minr = {x=pos.x-(radius+2), y=pos.y-(radius+2), z=pos.z-(radius+2)}
	local maxr = {x=pos.x+(radius+2), y=pos.y+(radius+2), z=pos.z+(radius+2)}

	for z=minr.z, maxr.z do
		for x=minr.x, maxr.x do
			for y=minr.y, maxr.y do
				local p = {x=x, y=y, z=z}
				local d = vector_distance(pos, p)
				if d < radius+2 and d > radius-2 then
					-- Check for nodes with 'falling_node' in groups.
					minetest.check_single_for_falling(p)

					-- Now check using additional falling node logic.
					instability.check_unsupported_single(p)
				end
			end
		end
	end

	-- Execute after-destruct callbacks.
	for k = 1, #on_after_destruct_queue do
		local v = on_after_destruct_queue[k]
    v.after_destruct(v.pos, v.oldnode)
  end

  for k = 1, #on_blast_queue do
		local queued_data = on_blast_queue[k]
		local dist = math_max(1, vector_distance(queued_data.pos, pos))
		local intensity = (radius * radius) / (dist * dist)
		local node_drops = queued_data.on_blast(queued_data.pos, intensity)
		if node_drops then
			for j = 1, #node_drops do
				add_drop(drops, node_drops[j])
			end
		end
	end
  
  -- Initialize flames.
  local fdef = minetest.registered_nodes["fire:basic_flame"]
  if fdef and fdef.on_construct then
		for k = 1, #fire_locations do
      fdef.on_construct(fire_locations[k])
    end
  end

	return drops, radius
end

--[[
{
	radius,
	ignore_protection,
	ignore_on_blast,
	damage_radius,
	disable_drops,
	name, -- Name to use when testing protection. Defaults to "".
}
--]]

function tnt.boom(pos, def)
	pos = vector_round(pos)
	-- The TNT code crashes sometimes, for no particular reason?
	local func = function()
		tnt.boom_impl(pos, def)
	end
	pcall(func)
end

-- Not to be called externally.
function tnt.boom_impl(pos, def)
	if def.make_sound == nil or def.make_sound == true then
		minetest.sound_play("tnt_explode", {pos = pos, gain = 1.5, max_hear_distance = 2*64}, true)
	end

	-- Make sure TNT never somehow gets keyed to the admin!
	if def.name and gdac.player_is_admin(def.name) then
		def.name = nil
	end
	if def.protection_name and gdac.player_is_admin(def.protection_name) then
		def.protection_name = nil
	end
	
	if not minetest.test_protection(pos, "") then
		local node = minetest.get_node(pos)
		-- Never destroy death boxes.
		if node.name ~= "bones:bones" then
			minetest.set_node(pos, {name = "tnt:boom"})
		end
	end
	
	local drops, radius = tnt_explode(pos, def.radius, def.ignore_protection,
		def.ignore_on_blast, (def.name or ""), (def.protection_name or ""))

	-- append entity drops
	local damage_radius = (radius / def.radius) * def.damage_radius
	entity_physics(pos, damage_radius, drops, def)
	if not def.disable_drops then
		eject_drops(drops, pos, radius)
	end
	add_effects(pos, radius, drops)
  
  minetest.log("action", "A TNT explosion occurred at " .. minetest.pos_to_string(pos) ..
    " with radius " .. radius)
end
