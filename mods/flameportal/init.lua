
if not minetest.global_exists("flameportal") then flameportal = {} end
flameportal.modpath = minetest.get_modpath("flameportal")

-- Localize for performance.
local vector_round = vector.round
local math_random = math.random



-- Check if the position `pos` is the center of a portal ring.
flameportal.check_is_gateway = function(pos)
    local p = vector_round(pos)
    
    local positions = {
        -- North side.
        {x=p.x-1, y=p.y,   z=p.z+2},
        {x=p.x,   y=p.y,   z=p.z+2},
        {x=p.x+1, y=p.y,   z=p.z+2},
        
        -- South side.
        {x=p.x-1, y=p.y,   z=p.z-2},
        {x=p.x,   y=p.y,   z=p.z-2},
        {x=p.x+1, y=p.y,   z=p.z-2},
        
        -- West side.
        {x=p.x-2, y=p.y,   z=p.z+1},
        {x=p.x-2, y=p.y,   z=p.z  },
        {x=p.x-2, y=p.y,   z=p.z-1},
        
        -- East side.
        {x=p.x+2, y=p.y,   z=p.z+1},
        {x=p.x+2, y=p.y,   z=p.z  },
        {x=p.x+2, y=p.y,   z=p.z-1},
    }
    
    for k, v in ipairs(positions) do
        local n1 = minetest.get_node(v).name
        if n1 ~= "default:obsidian" then return false end
    end
    
    local pos_air = {
        {x=p.x,   y=p.y,   z=p.z  },
        {x=p.x,   y=p.y,   z=p.z+1},
        {x=p.x,   y=p.y,   z=p.z-1},
        {x=p.x+1, y=p.y,   z=p.z  },
        {x=p.x-1, y=p.y,   z=p.z  },
        {x=p.x+1, y=p.y,   z=p.z+1},
        {x=p.x+1, y=p.y,   z=p.z-1},
        {x=p.x-1, y=p.y,   z=p.z+1},
        {x=p.x-1, y=p.y,   z=p.z-1},
    }
    
    for k, v in ipairs(pos_air) do
        local n1 = minetest.get_node(v).name
        if n1 ~= "air" then return false end
    end
    
    return true
end



-- Attempt to find a gateway using a brute-force method, starting at position `pos`.
-- Note: the gateway can only be found if `pos` is the position of one of the obsidian blocks at the top.
flameportal.find_gateway = function(pos)
    local p = {x=pos.x, y=pos.y, z=pos.z}

    local positions = {
        -- North side.
        {x=p.x-2, y=p.y, z=p.z+2},
        {x=p.x-1, y=p.y, z=p.z+2},
        {x=p.x,   y=p.y, z=p.z+2},
        {x=p.x+1, y=p.y, z=p.z+2},
        {x=p.x+2, y=p.y, z=p.z+2},
        
        -- South side.
        {x=p.x-2, y=p.y, z=p.z-2},
        {x=p.x-1, y=p.y, z=p.z-2},
        {x=p.x,   y=p.y, z=p.z-2},
        {x=p.x+1, y=p.y, z=p.z-2},
        {x=p.x+2, y=p.y, z=p.z-2},
        
        -- West side.
        {x=p.x-2, y=p.y, z=p.z+2},
        {x=p.x-2, y=p.y, z=p.z+1},
        {x=p.x-2, y=p.y, z=p.z  },
        {x=p.x-2, y=p.y, z=p.z-1},
        {x=p.x-2, y=p.y, z=p.z-2},
        
        -- East side.
        {x=p.x+2, y=p.y, z=p.z+2},
        {x=p.x+2, y=p.y, z=p.z+1},
        {x=p.x+2, y=p.y, z=p.z  },
        {x=p.x+2, y=p.y, z=p.z-1},
        {x=p.x+2, y=p.y, z=p.z-2},
    }
    
    for k, v in ipairs(positions) do
        if flameportal.check_is_gateway(v) then return true, v end
    end
    
    return false, nil
end



-- Attempt to activate a gateway at the given position.
flameportal.activate_gateway = function(pos)
    if flameportal.check_is_gateway(pos) == false then return end
    
    local p = vector_round(pos)
    minetest.log("action", "Nether portal activated at (" .. minetest.pos_to_string(p) .. ")")
    
    local flames = {
        -- North side.
        {x=p.x-1, y=p.y+1, z=p.z+2},
        {x=p.x,   y=p.y+1, z=p.z+2},
        {x=p.x+1, y=p.y+1, z=p.z+2},
        
        -- South side.
        {x=p.x-1, y=p.y+1, z=p.z-2},
        {x=p.x,   y=p.y+1, z=p.z-2},
        {x=p.x+1, y=p.y+1, z=p.z-2},
        
        -- West side.
        {x=p.x-2, y=p.y+1, z=p.z+1},
        {x=p.x-2, y=p.y+1, z=p.z  },
        {x=p.x-2, y=p.y+1, z=p.z-1},
        
        -- East side.
        {x=p.x+2, y=p.y+1, z=p.z+1},
        {x=p.x+2, y=p.y+1, z=p.z  },
        {x=p.x+2, y=p.y+1, z=p.z-1},
    }
    
    for k, v in ipairs(flames) do
        if math_random(1, 3) == 1 then
            if minetest.get_node(v).name == "air" then
                minetest.add_node(v, {name="fire:nether_flame"})
            end
        end
    end
    
    local void = {
        {x=p.x,   y=p.y, z=p.z  },
        {x=p.x,   y=p.y, z=p.z+1},
        {x=p.x,   y=p.y, z=p.z-1},
        {x=p.x+1, y=p.y, z=p.z  },
        {x=p.x-1, y=p.y, z=p.z  },
        {x=p.x-1, y=p.y, z=p.z-1},
        {x=p.x+1, y=p.y, z=p.z-1},
        {x=p.x-1, y=p.y, z=p.z+1},
        {x=p.x+1, y=p.y, z=p.z+1},
    }
    
    for k, v in ipairs(void) do
        minetest.add_node(v, {name="voidstone:void"})
    end

    -- Success.
    return true
end



flameportal.make_platform = function(param)
  for x = param.minp.x, param.maxp.x, 1 do
    for y = param.minp.y, param.maxp.y, 1 do
      for z = param.minp.z, param.maxp.z, 1 do
        local pos = {x=x, y=y, z=z}
        local node = minetest.get_node(pos)
        --minetest.chat_send_all(minetest.pos_to_string(pos) .. "=" .. node.name)
        if node.name == "air" or node.name == "rackstone:redrack" then
          if not minetest.test_protection(pos, "") then
            minetest.add_node(pos, {name="rackstone:redrack"})
            
            if vector.equals(pos, param.top) then
              minetest.add_node(pos, {name="flameportal:redrack"})
            end
          end
        end
      end
    end
  end
end



flameportal.make_flame_pillar = function(param)
  for x = param.minp.x, param.maxp.x, 1 do
    for y = param.minp.y, param.maxp.y, 1 do
      for z = param.minp.z, param.maxp.z, 1 do
        if math_random(1, 7) == 1 then
          -- Leave a vertical tunnel clear for the player to drop down.
          if not (x == param.avoid_x and z == param.avoid_z) then
            local pos = {x=x, y=y, z=z}
            local node = minetest.get_node(pos)
            if node.name == "air" then
              minetest.set_node(pos, {name="fire:basic_flame"})
            end
          end
        end
      end
    end
  end
end



flameportal.teleport_player = function(name, voidpos)
  local player = minetest.get_player_by_name(name)
  if player and player:is_player() then
    -- Don't teleport dead players.
    if player:get_hp() > 0 then
      if minetest.get_node(voidpos).name ~= "voidstone:void" then return end

			if sheriff.is_cheater(name) then
				if sheriff.punish_probability(name) then
					sheriff.punish_player(name)
					return
				end
			end
      
      local pp = player:get_pos()
      if pp.y > -25000 then
        -- Player is not in nether. Teleport them to the nether.
        flameportal.teleport_player_to_nether(player, voidpos)
      else
        local pname = player:get_player_name()
        local storage = flameportal.modstorage
        local return_pos = minetest.string_to_pos(storage:get_string(pname))
        if return_pos then
          minetest.log("action", "Player " .. pname .. " returns from the nether at (" .. minetest.pos_to_string(voidpos) .. ")")

					preload_tp.execute({
						player_name = pname,
						target_position = return_pos,
						emerge_radius = 32,
						particle_effects = true,

						post_teleport_callback = function()
							-- Damage player on return journey only sometimes.
							if math_random(1, 30) == 1 then
								minetest.after(0.5, function()
									local pref = minetest.get_player_by_name(pname)
									if pref and pref:is_player() then
                    utility.damage_player(pref, "poison", (math_random(2, 15)*500), "portal")
									end
								end)
							end
							portal_sickness.on_use_portal(pname)
						end,

						force_teleport = false,
						teleport_sound = "nether_portal_usual",
						send_blocks = true,
					})
        end
      end
    end
  end
end

-- 18200,-30794,-22386

-- Teleport a player into or out of the nether.
flameportal.teleport_player_to_nether = function(player, voidpos)
  local pname = player:get_player_name()
  local meta = minetest.get_meta(voidpos)
  local spos = meta:get_string("target") or ""
  local target

  meta:mark_as_private("target")
  
  if spos == "" then
    -- If metadata target hasn't been initialized yet.
    local pos = vector_round(voidpos)
    --local pr = PcgRandom(pos.x+pos.y+pos.z)
    target = {x=0, y=-30790, z=0}
    --target.x = pr:next(-30000, 30000)
    --target.z = pr:next(-30000, 30000)

		-- Chose a wholy random location.
		target.x = math_random(-30000, 30000)
		target.z = math_random(-30000, 30000)

    meta:set_string("target", minetest.pos_to_string(target))
		meta:mark_as_private({"target"})
  else
    -- Target location already set, use it.
    target = minetest.string_to_pos(spos)
    if target == nil then return end
  end
  
  -- Create platform beneath player.
  local minp = {x=target.x-1, y=target.y-12,   z=target.z-1}
  local maxp = {x=target.x+1, y=target.y-6,    z=target.z+1}
  local tb = {minp=minp, maxp=maxp, top={x=target.x, y=target.y-6, z=target.z}}
    
  -- Create flame pillar.
  local minp2 = {x=target.x-1, y=target.y-3,   z=target.z-1}
  local maxp2 = {x=target.x+1, y=target.y+10,  z=target.z+1}
  local tb2 = {
    minp = minp2,
    maxp = maxp2,
    avoid_x = target.x,
    avoid_z = target.z,
  }
  
  target.y = target.y+10

	preload_tp.execute({
		player_name = pname,
		target_position = target,
		emerge_radius = 64,
		particle_effects = true,

		-- Test code.
		--spinup_time = 3,

		-- Map modifications have to be done here, instead of in 'pre_teleport_callback'
		-- because otherwise if we wait for the long spinup time, the map will become
		-- unloaded again and we won't spawn the platform or the flame pillar!
		on_map_loaded = function()
      --minetest.chat_send_all('pretp!')
			flameportal.make_platform(tb)
			flameportal.make_flame_pillar(tb2)
		end,

		post_teleport_callback = function()
			local storage = flameportal.modstorage
			local return_pos = {x=voidpos.x, y=voidpos.y+1, z=voidpos.z}
			storage:set_string(pname, minetest.pos_to_string(return_pos))
			minetest.log("action", "Player " .. pname .. " teleports into the nether @ (" .. minetest.pos_to_string(target) .. ")")
		end,

		teleport_sound = "nether_portal_usual",
		send_blocks = true,
	})
end



-- API function.
function flameportal.clear_return_location(pname)
  flameportal.modstorage:set_string(pname, nil)
end



-- Flint & steel should call this when used on obsidian.
-- This function should check if the player is standing on void, and teleport them.
flameportal.try_teleport_on_flint_use =
function(pref)
  if not pref or not pref:is_player() then return end
  local p1 = utility.node_under_pos(pref:get_pos())
  if minetest.get_node(p1).name == "voidstone:void" then
    flameportal.teleport_player(pref:get_player_name(), p1)
  end
end



-- This function should be called whenever a nodetype that takes part in portal construction is removed.
flameportal.after_portal_destruct = function(pos, oldnode)
    if oldnode.name == "fire:nether_flame" then
        local p = minetest.find_node_near(pos, 2, "voidstone:void")
        if p then
            minetest.add_node(p, {name="fire:basic_flame"})
        end
    elseif oldnode.name == "voidstone:void" then
        local void = {
            {x=pos.x+1, y=pos.y,   z=pos.z  },
            {x=pos.x-1, y=pos.y,   z=pos.z  },
            {x=pos.x,   y=pos.y,   z=pos.z+1},
            {x=pos.x,   y=pos.y,   z=pos.z-1},
            {x=pos.x,   y=pos.y+1, z=pos.z  },
            {x=pos.x,   y=pos.y-1, z=pos.z  },
        }
        
        for k, v in pairs(void) do
            local n = minetest.get_node(v).name
            if n == "voidstone:void" then
                minetest.add_node(v, {name="fire:basic_flame"})
            end
        end
    elseif oldnode.name == "default:obsidian" then
        local fp = {x=pos.x, y=pos.y+1, z=pos.z}
        if minetest.get_node(fp).name == "fire:nether_flame" then
            minetest.remove_node(fp)
        end
        
        local void = {
            {x=pos.x+1, y=pos.y,   z=pos.z  },
            {x=pos.x-1, y=pos.y,   z=pos.z  },
            {x=pos.x,   y=pos.y,   z=pos.z+1},
            {x=pos.x,   y=pos.y,   z=pos.z-1},
        }
        
        for k, v in pairs(void) do
            local n = minetest.get_node(v).name
            if n == "voidstone:void" then
                minetest.add_node(v, {name="fire:basic_flame"})
            end
        end
    end
end



if not flameportal.run_once then
  flameportal.modstorage = minetest.get_mod_storage()
  
  -- Special node which the player can land on safely when dropped into the nether.
  minetest.register_node("flameportal:redrack", {
    description = "Netherack",
    tiles = {"rackstone_redrack.png"},
    groups = utility.dig_groups("netherack", {fall_damage_add_percent=-100}),
    sounds = rackstone.rackstone_sounds(),
    drop = "rackstone:redrack",
  })
  minetest.register_alias("flameportal:no_fall_damage", "flameportal:redrack")

  minetest.override_item("default:obsidian", {
    after_destruct = function(pos, oldnode)
			minetest.after(0, ambiance.recheck_nearby_sound_beacons, {x=pos.x, y=pos.y, z=pos.z}, 16)
			return flameportal.after_portal_destruct(pos, oldnode)
		end,

    on_destruct = function(pos, oldnode)
			obsidian_gateway.on_damage_gate(pos)
		end,

		-- Note: default obsidian is blast resistent.
		-- 'on_blast' is defined in the default mod.
  })

  minetest.override_item("voidstone:void", {
    after_destruct = function(...) return flameportal.after_portal_destruct(...) end,
    on_blast = function(pos) minetest.remove_node(pos) end,
  })

  minetest.override_item("fire:nether_flame", {
    after_destruct = function(pos, oldnode)
      flameportal.after_portal_destruct(pos, oldnode)
      fireambiance.on_flame_addremove(pos)
			particles.del_flame_spawner(pos)
    end,
    
    on_blast = function(pos) minetest.remove_node(pos) end,
  })
  
  -- Reloadable.
  local file = flameportal.modpath .. "/init.lua"
  local name = "flameportal:core"
  reload.register_file(name, file, false)
  
  flameportal.run_once = true
end



