
if not minetest.global_exists("glowstone") then glowstone = {} end
glowstone.modpath = minetest.get_modpath("glowstone")



minetest.register_craftitem("glowstone:glowing_dust", {
	description = "Radiant Dust",
	inventory_image = "glowstone_glowdust.png",
})



minetest.register_node("glowstone:luxore", {
	description = "Lux Ore",
	tiles = {"default_stone.png^glowstone_glowore.png"},
	paramtype = "light",
	light_source = 14,
	groups = utility.dig_groups("mineral", {glowmineral = 1}),
	drop = "glowstone:glowing_dust 2",
	silverpick_drop = true,
	sounds = default.node_sound_stone_defaults(),
	place_param2 = 10,
})

minetest.register_node("glowstone:cobble", {
	description = "Sunstone Deposit",
	tiles = {"glowstone_cobble.png"},
	paramtype = "light",
	light_source = 14,
	groups = utility.dig_groups("mineral", {glowmineral = 1}),
	sounds = default.node_sound_stone_defaults(),
})



minetest.register_node("glowstone:minerals", {
	description = "Radiant Minerals",
	tiles = {"glowstone_minerals.png"},
	paramtype = "light",
	light_source = 14,
	groups = utility.dig_groups("mineral", {glowmineral = 1}),
	drop = "glowstone:glowing_dust 2",
	silverpick_drop = true,
	sounds = default.node_sound_stone_defaults(),
	place_param2 = 10,
})



local function walk_glowstone(player)
	local pname = player:get_player_name()
	hb4.delayed_harm({
		name = pname,
		step = 10,
		min = 1*500,
		max = 2*500,
		msg = "# Server: <" .. rename.gpn(pname) .. "> was poisoned by glowstone.",
		poison = true,
	})
end

local function punch_glowstone(player)
	local pname = player:get_player_name()
	hb4.delayed_harm({
		name = pname,
		step = 3,
		min = 1*500,
		max = 2*500,
		msg = "# Server: <" .. rename.gpn(pname) .. "> was poisoned by glowstone.",
		poison = true,
	})
end



minetest.register_node("glowstone:glowstone", {
	description = "Toxic Glowstone",
	tiles = {"glowstone_glowstone.png"},
	paramtype = "light",
	light_source = 14,
	groups = utility.dig_groups("mineral", {glowmineral = 1}),
	drop = "glowstone:glowing_dust 2",
	silverpick_drop = true,
	sounds = default.node_sound_stone_defaults(),
	place_param2 = 10,

	-- Poison players who come into direct contact.
	on_player_walk_over = function(pos, player)
		if not player or not player:is_player() then
			return
		end
		return walk_glowstone(player)
	end,

	on_punch = function(pos, node, puncher, pt)
		if not puncher or not puncher:is_player() then
			return
		end
		return punch_glowstone(puncher)
	end,
})



minetest.register_craft({
    output = "glowstone:luxore",
    recipe = {
        {"glowstone:glowing_dust", "default:mossycobble", "glowstone:glowing_dust"},
    },
})



minetest.register_craft({
    output = "glowstone:minerals",
    recipe = {
        {"",                        "rackstone:redrack",    "",                         },
        {"glowstone:glowing_dust",  "rackstone:dauthsand",  "glowstone:glowing_dust",   },
    },
})



minetest.register_craft({
    output = "glowstone:glowstone",
    recipe = {
        {"",                        "rackstone:redrack",    "",                         },
        {"glowstone:glowing_dust",  "rackstone:blackrack",  "glowstone:glowing_dust",   },
    },
})



oregen.register_ore({
	ore_type = "scatter",
	ore = "glowstone:luxore",
	wherein = {"default:stone"},
	clust_scarcity = 18*18*18,
	clust_num_ores = 3,
	clust_size = 10,
	y_min = -25000,
	y_max = -1000,
})



minetest.register_alias("glowstone:ore",        "glowstone:luxore")
minetest.register_alias("glowstone:block",      "glowstone:luxore")
minetest.register_alias("glowstone:dust",       "glowstone:glowing_dust")
minetest.register_alias("glowrack:magma",       "glowstone:glowstone")
minetest.register_alias("glowrack:minerals",    "glowstone:minerals")

