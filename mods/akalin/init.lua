
minetest.register_node("akalin:ore", {
  description = "Akalin Ore",
  tiles = {"default_stone.png^gloopores_mineral_akalin.png"},
  groups = {level = 1, cracky = 3},
  drop = "akalin:lump",
  sounds = default.node_sound_stone_defaults(),
})

oregen.register_ore({
  ore_type         = "scatter",
  ore              = "akalin:ore",
  wherein          = "default:stone",
  clust_scarcity   = 8*8*8,
  clust_num_ores   = 2,
  clust_size       = 3,
  y_min       = -50,
  y_max       = 300,
})

minetest.register_craftitem("akalin:lump", {
  description = "Akalin Lump",
  inventory_image = "gloopores_akalin_lump.png",
})

minetest.register_craft({
  type = "cooking",
  output = "akalin:ingot",
  recipe = "akalin:lump",
})

minetest.register_craftitem("akalin:dust", {
  description = "Akalin Dust",
  inventory_image = "technic_akalin_dust.png"
})

minetest.register_craft({
  type = "cooking",
  output = "akalin:ingot",
  recipe = "akalin:dust",
})

minetest.register_craft({
  type = "grinding",
  output = 'akalin:dust 2',
  recipe = 'akalin:lump',
  time = 10,
})

minetest.register_craftitem("akalin:ingot", {
  description = "Akalin Ingot",
  inventory_image = "gloopores_akalin_ingot.png",
  groups = {ingot = 1},
})

minetest.register_craft({
  type = "grinding",
  output = 'akalin:dust',
  recipe = 'akalin:ingot',
  time = 10,
})

minetest.register_node("akalin:block", {
  description = "Akalin Block",
  tiles = {"gloopores_akalin_block.png"},
  is_ground_content = false,
  groups = {cracky = 1, level = 2},
  sounds = default.node_sound_metal_defaults(),
})

stairs.register_stair_and_slab(
  "akalin_block",
  "akalin:block",
  {cracky = 1},
  {"gloopores_akalin_block.png"},
  "Akalin Block",
  default.node_sound_metal_defaults()
)

minetest.register_craft({
  output = "akalin:block",
  recipe = {
    {"akalin:ingot", "akalin:ingot", "akalin:ingot"},
    {"akalin:ingot", "akalin:ingot", "akalin:ingot"},
    {"akalin:ingot", "akalin:ingot", "akalin:ingot"},
  },
})

minetest.register_craft({
  type = "shapeless",
  output = "akalin:ingot 9",
  recipe = {"akalin:block"},
})

minetest.register_node("akalin:glass", {
  description = "Akalin Glass",
  drawtype = "glasslike_framed_optional",
  tiles = {"glooptest_akalin_crystal_glass.png"},
  paramtype = "light",
  sunlight_propagates = true,
  is_ground_content = false,
  groups = {level = 1, cracky = 3},
  sounds = default.node_sound_glass_defaults(),
})

minetest.register_craft({
  type = "shapeless",
  output = "akalin:glass",
  recipe = {"default:glass", "akalin:ingot"},
})

