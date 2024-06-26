
if not minetest.global_exists("shears") then shears = {} end
shears.modpath = minetest.get_modpath("shears")



local USES = 200
shears.on_place = function(itemstack, user, pointed_thing)
	if pointed_thing.type ~= "node" then
		return
	end

	local pos = pointed_thing.under
	local node = minetest.get_node(pos)

	-- Pass through interactions to nodes that define them (like chests).
	do
		local pdef = minetest.reg_ns_nodes[node.name]
		if pdef and pdef.on_rightclick and not user:get_player_control().sneak then
			return pdef.on_rightclick(pos, node, user, itemstack, pointed_thing)
		end
	end

	if minetest.is_protected(pos, user:get_player_name()) then
		minetest.record_protection_violation(pos, user:get_player_name())
		return
	end

	if node.name == "vines:rope" then
		itemstack:add_wear(65535 / (USES - 1))
		minetest.swap_node(pos, {name="vines:rope_bottom"}) -- Do not wipe metadata.
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p)
		if (n.name == 'vines:rope' or n.name == 'vines:rope_bottom') then
			-- This will trigger removal of the rope underneath.
			minetest.set_node(p, {name="vines:rope_top"})
		end
	end
end



if not shears.run_once then
	minetest.register_tool("shears:shears", {
		description = "Shears",
		inventory_image = "shears_shears.png",
		wield_image = "shears_shears.png",
		stack_max = 1,
		tool_capabilities = tooldata["shears_shears"],

		-- OnPlace is used to avoid interfering with regular digging actions on the client.
		-- The shears are allowed to dig leaves and ropes.
		on_place = function(...) return shears.on_place(...) end,

		sounds = {breaks = "basictools_tool_breaks"},
		groups = {flammable=2},
	})
	minetest.register_alias("vines:shears", "shears:shears")

	minetest.register_craft({
		output = 'shears:shears',
		recipe = {
			{'',				'default:steel_ingot',	''                   },
			{'group:stick',	'group:wood',			'default:steel_ingot'},
			{'',				'group:stick',		''                   },
		},
	})

	minetest.register_craft({
		output = 'shears:shears',
		recipe = {
			{'',				'moreores:tin_ingot',	''                    },
			{'group:stick',	'group:wood',			'moreores:tin_ingot'  },
			{'',				'group:stick',		''                    },
		},
	})

	-- Reloadable.
	local name = "shears:core"
	local file = shears.modpath .. "/init.lua"
	reload.register_file(name, file, false)

	shears.run_once = true
end





