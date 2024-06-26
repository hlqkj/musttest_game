
if not minetest.global_exists("exile") then exile = {} end
exile.modpath = minetest.get_modpath("exile")
exile.eviction_notices = exile.eviction_notices or {}

-- Localize for performance.
local vector_distance = vector.distance
local vector_normalize = vector.normalize
local vector_subtract = vector.subtract
local vector_multiply = vector.multiply
local vector_round = vector.round
local vector_add = vector.add
local math_random = math.random

-- Helper to query whether there is a nearby non-cheating player (also not self)
-- within a certain range.
local function nearby_noncheater(pname, pos, range)
	local players = minetest.get_connected_players()
	for i=1, #players, 1 do
		local pref = players[i]
		local pn = pref:get_player_name()
		if pn ~= pname then
			if vector_distance(pref:get_pos(), pos) < range then
				if not sheriff.is_suspected_cheater(pn) then
					if not gdac.player_is_admin(pn) then
						return true
					end
				end
			end
		end
	end
end

local function move_player_to_exile(pname, target)
	local minp = vector.add(target, {x=-8, y=-100, z=-8})
	local maxp = vector.add(target, {x=8, y=100, z=8})

	local function callback(blockpos, action, calls_remaining, param)
		-- We don't do anything until the last callback.
		if calls_remaining ~= 0 then
			return
		end

		-- Check if there was an error on the LAST call.
		-- Note: this will usually fail if the area to emerge intersects the map edge.
		-- But usually we don't try to do that, here.
		if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
			return
		end

		local pos = table.copy(param.target)
		local orig_y = pos.y
		local pname = param.pname
		local get_node = minetest.get_node

		-- Locate ground level, or some area where the player can fit in air.
		-- Start from sky and work downwards, to reduce chance of tp'ing to cave.
		for y = 90, -90, -1 do
			pos.y = orig_y + y - 1
			local n1 = get_node(pos)
			pos.y = orig_y + y
			local n2 = get_node(pos)
			pos.y = orig_y + y + 1
			local n3 = get_node(pos)

			-- All 3 nodes must be loaded.
			if n1.name ~= "ignore" and n2.name ~= "ignore" and n3.name ~= "ignore" then
				local d1 = minetest.registered_nodes[n1.name]
				local d2 = minetest.registered_nodes[n2.name]
				local d3 = minetest.registered_nodes[n3.name]
				if d1 and d2 and d3 then
					if d1.walkable and not d2.walkable and not d3.walkable then
						pos.y = orig_y + y

						local post_cb = function(param)
							-- Report publicly, while avoiding chat spam.
							local pname = param.pname
							if not exile.eviction_notices[pname] then
								minetest.chat_send_all("# Server: Law enforcement evicted <" .. rename.gpn(pname) .. "> from town.")
								exile.eviction_notices[pname] = true
								minetest.after(60, function()
									exile.eviction_notices[pname] = nil
								end)
							end
						end

						-- Wrapped in minetest.after() to avoid *potential* callstack issues.
						minetest.after(0, function()
							preload_tp.execute({
								player_name = pname,
								target_position = pos,
								emerge_radius = 8,
								post_teleport_callback = post_cb,
								callback_param = param,
								force_teleport = true,
								send_blocks = false,
								particle_effects = true,
							})
						end)

						return
					end
				end
			end
		end
	end

	minetest.emerge_area(minp, maxp, callback,
		{target=table.copy(target), pname=pname})
end

-- A player is violating their exile if ...
function exile.player_in_violation(pname)
	-- They are a registered cheater ...
	if sheriff.is_cheater(pname) then
		local pref = minetest.get_player_by_name(pname)
		-- And they are logged in ...
		if pref then
			local pos = pref:get_pos()
			-- And there's a normal player near them ...
			if nearby_noncheater(pname, pos, 100) then
				-- And they are in a city area ...
				if city_block:in_city_suburbs(pos) then
					-- And not currently in jail ...
					if not jail.is_player_in_jail(pref) then
						return true
					end
				end
			end
		end
	end
end

function exile.send_to_exile(pname)
	local pref = minetest.get_player_by_name(pname)
	if pref then
		local pos = pref:get_pos()
		local rn1 = rc.current_realm_at_pos(pos)
		local cb = city_block:nearest_blocks_to_position(pos, 5, 100)

		-- No nearby city-blocks? Cannot move player (also avoid divide-by-zero).
		if #cb == 0 then
			return
		end

		-- Calculate the average postion of nearby city-blocks.
		local x, y, z, n = 0, 0, 0, #cb
		for i=1, n, 1 do
			local b = cb[i]
			local p = b.pos
			x = x + p.x
			y = y + p.y
			z = z + p.z
		end
		x = x / n
		y = y / n
		z = z / n

		-- Calculate a new position away from the city-blocks.
		pos.y = y -- Only move player in the X,Z dimensions.
		local center = {x=x, y=y, z=z}
		local dir = vector_normalize(vector_subtract(pos, center))
		local gpos = vector_round(vector_add(vector_multiply(dir, 100), center))
		gpos.y = y -- Only move player in the X,Z dimensions.
		local rn2 = rc.current_realm_at_pos(gpos)

		-- Only if we wouldn't cause player to change realms, or enter the void.
		if rn2 ~= "" and rn1 == rn2 then
			move_player_to_exile(pname, gpos)

			-- Damage caused by system/server/cheat, bypass regular processing.
			pref:set_hp(pref:get_hp() - (1*500))
		end
	end
end

-- Function shall return 'true' if player was confirmed to be in violation of their exile.
function exile.check_player(pname)
	if exile.player_in_violation(pname) then
		exile.send_to_exile(pname)
		return true
	end
end

function exile.repeating_check(pname)
	-- Only check confirmed cheaters, as no one else can be exiled.
	if sheriff.is_cheater(pname) then
		exile.check_player(pname)

		-- Schedule another check shortly.
		minetest.after(1, exile.repeating_check, pname)
	end
end

-- To be called if a cheater is confirmed/registered during game-play time.
function exile.notify_new_exile(pname)
	-- Just call the function as if they've just joined.
	exile.on_joinplayer(minetest.get_player_by_name(pname))
end

function exile.on_joinplayer(pref)
	if pref and pref:is_player() then
		local pname = pref:get_player_name()
		minetest.after(math_random(1, 10), exile.repeating_check, pname)
	end
end

if not exile.registered then
	local c = "exile:core"
	local f = exile.modpath .. "/init.lua"
	reload.register_file(c, f, false)

	minetest.register_on_joinplayer(function(...)
		exile.on_joinplayer(...) end)

	exile.registered = true
end
