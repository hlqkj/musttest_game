
minetest.register_node("arol:ore", {
  description = "Arol Ore",
  tiles = {"default_stone.png^gloopores_mineral_arol.png"},
  groups = {level = 1, cracky = 3},
  drop = "arol:lump",
  sounds = default.node_sound_stone_defaults(),
})

oregen.register_ore({
  ore_type         = "scatter",
  ore              = "arol:ore",
  wherein          = "default:stone",
  clust_scarcity   = 8*8*8,
  clust_num_ores   = 2,
  clust_size       = 3,
  y_min       = -50,
  y_max       = 300,
})

minetest.register_craftitem("arol:lump", {
  description = "Arol Lump",
  inventory_image = "gloopores_arol_lump.png",
})

minetest.register_craft({
  type = "cooking",
  output = "arol:ingot",
  recipe = "arol:lump",
})

minetest.register_craftitem("arol:dust", {
  description = "Arol Dust",
  inventory_image = "technic_arol_dust.png"
})

minetest.register_craft({
  type = "cooking",
  output = "arol:ingot",
  recipe = "arol:dust",
})

minetest.register_craft({
  type = "grinding",
  output = 'arol:dust 2',
  recipe = 'arol:lump',
  time = 10,
})

minetest.register_craftitem("arol:ingot", {
  description = "Arol Ingot",
  inventory_image = "gloopores_arol_ingot.png",
  groups = {ingot = 1},
})

minetest.register_craft({
  type = "grinding",
  output = 'arol:dust',
  recipe = 'arol:ingot',
  time = 10,
})

minetest.register_node("arol:block", {
  description = "Arol Block",
  tiles = {"glooptest_arol_block.png"},
  is_ground_content = false,
  groups = {cracky = 1, level = 2},
  sounds = default.node_sound_metal_defaults(),
})

stairs.register_stair_and_slab(
  "arol_block",
  "arol:block",
  {cracky = 1},
  {"glooptest_arol_block.png"},
  "Arol Block",
  default.node_sound_metal_defaults()
)

minetest.register_craft({
  output = "arol:block",
  recipe = {
    {"arol:ingot", "arol:ingot", "arol:ingot"},
    {"arol:ingot", "arol:ingot", "arol:ingot"},
    {"arol:ingot", "arol:ingot", "arol:ingot"},
  },
})

minetest.register_craft({
  type = "shapeless",
  output = "arol:ingot 9",
  recipe = {"arol:block"},
})

minetest.register_node("arol:glass", {
  description = "Arol Glass",
  drawtype = "glasslike_framed_optional",
  tiles = {"glooptest_arol_crystal_glass.png"},
  paramtype = "light",
  sunlight_propagates = true,
  is_ground_content = false,
  groups = {level = 1, cracky = 3},
  sounds = default.node_sound_glass_defaults(),
})

minetest.register_craft({
  type = "shapeless",
  output = "arol:glass",
  recipe = {"default:glass", "arol:ingot"},
})

