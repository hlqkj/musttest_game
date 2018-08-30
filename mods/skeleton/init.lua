
skeleton = skeleton or {}
skeleton.modpath = minetest.get_modpath("skeleton")



mobs.register_mob("skeleton:skeleton", {
	type = "monster",
	description = "Fleshless Skeleton",
	reach = 3,
	damage = 2,
	attack_type = "dogfight",
	hp_min = 62,
	hp_max = 72,
	armor = 100,
	collisionbox = {-0.4, 0, -0.4, 0.4, 2.5, 0.4},
	visual = "mesh",
	mesh = "skeleton_skeleton.b3d",
	textures = {
		{"skeleton_skeleton.png"},
	},
	blood_texture = "default_stone.png",
	visual_size = {x=0.7, y=0.7},
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 2.5,
	jump = true,
    jump_chance = 100,
    walk_chance = 10,
	drops = {
		{name = "bones:bones_type2", chance = 5, min = 3, max = 6},
		{name = "bonemeal:bone", chance = 1, min = 3, max = 6},
	},
	water_damage = 0,
	lava_damage = 2,
	light_damage = 1,
	fall_damage = 0,
	fear_height = 3,
	view_range = 14,
	animation = {
		speed_normal = 15,
		speed_run = 20,
		walk_start = 46,
		walk_end = 66,
		stand_start = 1,
		stand_end = 20,
		run_start = 46,
		run_end = 66,
		punch_start = 20,
		punch_end = 45,
	},
})



mobs.register_spawn({
	name = "skeleton:skeleton",
	nodes = {
    "rackstone:rackstone",
    "rackstone:redrack",
    "rackstone:mg_rackstone",
    "rackstone:mg_redrack",
  },
	min_light = 0,
	max_light = 6,
	interval = 360,
	chance = 17000,
	mob_limit = 1,
	mob_range = 100,
	max_height = -25000,
	min_count = 1,
	max_count = 2,
	player_max_range = 40,
	spawn_height = 3,
})



mobs.register_egg("skeleton:skeleton", "Skeleton", "default_dirt.png", 1)
