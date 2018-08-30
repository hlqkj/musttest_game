
minetest.register_node("moregrass:darkgrass", {
	description = "Dirt With Lush Grass",
	tiles = {
		"moregrass_darkgrass_top.png", "default_dirt.png",
		{
			name = "default_dirt.png^moregrass_darkgrass_side.png",
			tileable_vertical = false
		}
	},
	groups = {level = 1, crumbly = 3, falling_node = 1, soil = 1, spreading_dirt_type = 1},
	drop = 'default:dirt',
	sounds = default.node_sound_dirt_defaults({
		footstep = {name = "default_grass_footstep", gain = 0.25},
	}),
	on_timer = function(...)
		return dirtspread.dirt_on_timer(...)
	end,
  on_finish_collapse = function(pos, node)
    minetest.swap_node(pos, {name="default:dirt"})
  end,
	movement_speed_multiplier = default.SLOW_SPEED_GRASS,
})

