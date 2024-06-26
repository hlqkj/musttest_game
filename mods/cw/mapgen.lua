
-- Mapgen Environment ONLY.
-- Not reloadable!
cw = {}
cw.modpath = minetest.get_modpath("cw")
cw.worldpath = minetest.get_worldpath()

-- Localize for performance.
local math_random = math.random

-- Disable for testing terrain shapes without all that foliage.
local ENABLE_TREES = true
local TREE_HEIGHT_MOD = 13

-- Param2 horizontal branch rotations.
local branch_rotations = {4, 8, 12, 16}
local branch_directions = {2, 0, 3, 1}

cw.REALM_START = 3050
cw.BEDROCK_DEPTH = 4
cw.OCEAN_DEPTH = 16
cw.GROUND_DEPTH = 11
cw.GROUND_HEIGHT_VARIATION = 4

-- Controls land height.
cw.noise1param2d = {
	offset = 0,
	scale = 1,
	spread = {x=128, y=128, z=128},
	seed = 3717,
	octaves = 5,
	persist = 0.5,
	lacunarity = 2,
}

-- Large scale land height.
local LAND_SCALE = 2048
cw.noise3param2d = {
	offset = 0,
	scale = 1,
	spread = {x=LAND_SCALE, y=LAND_SCALE, z=LAND_SCALE},
	seed = 8872,
	octaves = 7,
	persist = 0.6,
	lacunarity = 1.8,
}

-- Rivers.
local RIVER_SCALE = 1024
local RIVER_WIDTH = 0.03
local RIVER_DEPTH = 8
local RIVER_OCEAN_LIMIT = 6
cw.noise4param2d = {
	offset = 0,
	scale = 1,
	spread = {x=RIVER_SCALE, y=RIVER_SCALE, z=RIVER_SCALE},
	seed = 7718,
	octaves = 2,
	persist = 0.5,
	lacunarity = 2.0,
}

cw.noise2param2d = {
	offset = 0,
	scale = 1,
	spread = {x=32, y=32, z=32},
	seed = 5817,
	octaves = 4,
	persist = 0.8,
	lacunarity = 2,
}

-- Content IDs used with the voxel manipulator.
local c_air             = minetest.get_content_id("air")
local c_ignore          = minetest.get_content_id("ignore")
local c_stone           = minetest.get_content_id("default:stone")
local c_bedrock         = minetest.get_content_id("bedrock:bedrock")
local c_water           = minetest.get_content_id("cw:water_source")
local c_dirt            = minetest.get_content_id("darkage:darkdirt")
local c_silt            = minetest.get_content_id("darkage:silt")
local c_mud             = minetest.get_content_id("darkage:mud")
local c_clay            = minetest.get_content_id("default:clay")
local c_lily            = minetest.get_content_id("flowers:waterlily")
local c_tree            = minetest.get_content_id("basictrees:jungletree_cube")
local c_tree2           = minetest.get_content_id("basictrees:jungletree_trunk")
local c_leaves          = minetest.get_content_id("basictrees:jungletree_leaves2")
local c_soil            = minetest.get_content_id("default:dirt_with_rainforest_litter")
local c_junglegrass     = minetest.get_content_id("default:junglegrass")
local c_grass           = minetest.get_content_id("default:grass_5")
local c_grass2          = minetest.get_content_id("default:dry_grass2_5")
local c_grass3          = minetest.get_content_id("default:marram_grass_3")
local c_papyrus2        = minetest.get_content_id("default:papyrus2")
local c_sand            = minetest.get_content_id("default:sand")

-- Externally located tables for performance.
local data = {}
local param2_data = {}
local noisemap1 = {}
local noisemap2 = {}
local noisemap3 = {}
local noisemap4 = {}

local JUNGLETREE_REPLACEMENTS = {
	["default:jungletree"] = "basictrees:jungletree_cube",
	["default:jungleleaves"] = "basictrees:jungletree_leaves2",
}

-- Offsets for tall trees (tree has a chance to lean, be not perfectly straight).
local RANDPOS = {
	{x=1, y=0, z=0},
	{x=-1, y=0, z=0},
	{x=0, y=0, z=1},
	{x=0, y=0, z=-1},

	-- 3 times to increase probability.
	{x=0, y=0, z=0},
	{x=0, y=0, z=0},
	{x=0, y=0, z=0},
}

local DRY_LEAVES_LIST = {
	minetest.get_content_id("dryleaves:leaves"),
	minetest.get_content_id("dryleaves:jungleleaves"),
	minetest.get_content_id("dryleaves:dry_leaves"),
	minetest.get_content_id("dryleaves:plantlike"),
}



cw.generate_realm = function(vm, minp, maxp, seed)
	local nstart = cw.REALM_START
	--minp = table.copy(minp)
	--maxp = table.copy(maxp)

	-- Don't run for out-of-bounds mapchunks.
	local nfinish = nstart + 100
	if minp.y > nfinish or maxp.y < nstart then
		return
	end

	-- Generate the full column all at once.
	--[[
	if minp.y > nstart then
		minp.y = nstart
	end
	if maxp.y < nfinish then
		maxp.y = nfinish
	end
	--]]

	-- Grab the voxel manipulator.
	-- Read current map data.
	--local vm = VoxelManip()
  --local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	--vm:read_from_map(vector.subtract(minp, 16), vector.add(maxp, 16))
	local emin, emax = vm:get_emerged_area()
	vm:get_data(data)
	local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})

	local pr = PseudoRandom(seed + 381)

	-- Special PRNG which MUST ensure the SAME output for all chunks in a column!
	-- This is required for the tall trees, which cross mapchunk boundaries.
	local column_pr = PseudoRandom(minetest.hash_node_position({x=minp.x, y=0, z=minp.z}))
	--local column_pr = pr

	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z

	-- Compute side lengths.
	local side_len_x = ((x1-x0)+1)
	local side_len_z = ((z1-z0)+1)
	local sides2D = {x=side_len_x, y=side_len_z}
	local bp2d = {x=x0, y=z0}

	-- Get noisemaps.
	local perlin1 = minetest.get_perlin_map(cw.noise1param2d, sides2D)
	perlin1:get_2d_map_flat(bp2d, noisemap1)
	local perlin2 = minetest.get_perlin_map(cw.noise2param2d, sides2D)
	perlin2:get_2d_map_flat(bp2d, noisemap2)
	local perlin3 = minetest.get_perlin_map(cw.noise3param2d, sides2D)
	perlin3:get_2d_map_flat(bp2d, noisemap3)
	local perlin4 = minetest.get_perlin_map(cw.noise4param2d, sides2D)
	perlin4:get_2d_map_flat(bp2d, noisemap4)

	-- Localize commonly used functions.
	local floor = math.floor
	local ceil = math.ceil
	local abs = math.abs

	local od = cw.OCEAN_DEPTH
	local bd = cw.BEDROCK_DEPTH
	local gd = cw.GROUND_DEPTH
	local ghv = cw.GROUND_HEIGHT_VARIATION

	local tree_positions1 = {}
	local lily_positions1 = {}

	-- First mapgen pass.
	for z = z0, z1 do
		for x = x0, x1 do
			-- Get index into 2D noise arrays.
			local nx = (x-x0)
			local nz = (z-z0)
			local ni2 = (side_len_z*nz+nx)
			-- Lua arrays start indexing at 1, not 0. Urrrrgh.
			ni2 = ni2 + 1

			local n1 = noisemap1[ni2]
			local n2 = noisemap2[ni2]
			local n3 = noisemap3[ni2]
			local n4 = noisemap4[ni2]

			-- Randomize height of the bedrock a bit.
			local bedrock_adjust = (nstart + bd + pr:next(0, pr:next(1, 2)))
			local clay_depth = (nstart + bd + pr:next(1, 2))

			-- Fixed ocean height.
			local ocean_depth = (nstart + od)
			local ocean_surface = ocean_depth + 1

			-- Ground height.
			local an1 = abs(n1) + ((n3 + 0.25) * 2)
			local ground_depth = (nstart + gd + floor(an1 * ghv))

			-- As land climbs above sea level, deepen rivers to compensate.
			local r_depth = RIVER_DEPTH
			if ground_depth > ocean_depth then
				r_depth = r_depth + (ground_depth - ocean_depth)
			end

			-- Large rivers.
			local r4 = abs(n4)
			if r4 <= RIVER_WIDTH then
				-- Don't forget to floor it, otherwise we get glitches.
				r4 = math.floor((((r4 / RIVER_WIDTH) * -1) + 1) * r_depth)
			else
				r4 = 0
			end

			-- Prevent rivers from digging too deep in the ocean.
			if (ground_depth - r4) < (ocean_depth - RIVER_OCEAN_LIMIT) then
				ground_depth = (ocean_depth - RIVER_OCEAN_LIMIT)
			else
				ground_depth = ground_depth - r4
			end

			local water_depth = (ocean_depth - ground_depth)
			local lily_chance = 1000

			if water_depth <= 2 then
				if column_pr:next(1, 10) == 1 then
					tree_positions1[#tree_positions1+1] = {x=x, y=ground_depth, z=z, w=an1}
				end
				lily_chance = 50
			elseif water_depth == 3 then
				if column_pr:next(1, 40) == 1 then
					tree_positions1[#tree_positions1+1] = {x=x, y=ground_depth, z=z, w=an1}
				end
				lily_chance = 150
			elseif water_depth == 4 then
				if column_pr:next(1, 300) == 1 then
					tree_positions1[#tree_positions1+1] = {x=x, y=ground_depth, z=z, w=an1}
				end
				lily_chance = 200
			end

			-- Enable waterlilies.
			local want_waterlily = false
			if pr:next(1, lily_chance) == 1 then
				want_waterlily = true
			end

			-- First pass through column.
			for y = y0, y1 do
				local vp = area:index(x, y, z)
				if y >= nstart and y <= nfinish then
					-- Get what's already here.
					local cid = data[vp]

					if cid == c_air or cid == c_ignore then
						-- Place bedrock layer.
						if y <= bedrock_adjust then
							data[vp] = c_bedrock
						elseif y <= clay_depth and water_depth >= 5 then
							data[vp] = c_clay
						elseif y < ground_depth then
							data[vp] = c_dirt
						elseif y == ground_depth then
							if ground_depth >= (ocean_depth + 3) then
								-- Mud turns to sand when ground is high enough.
								data[vp] = c_sand
							elseif ground_depth >= (ocean_depth - 1) then
								-- Mud appears when silt rises to water surface and above.
								data[vp] = c_mud
							else
								data[vp] = c_silt
							end
						elseif y <= ocean_depth then
							data[vp] = c_water
						elseif y == ocean_surface then
							if want_waterlily then
								data[vp] = c_lily
							end
						end
					end
				end

			end
		end
	end

	vm:set_data(data)

	if ENABLE_TREES then
	local JP = JUNGLETREE_REPLACEMENTS
	local FP = false -- Force place
	local strrnd = "random"

	local function PUT_SCHEM(vm, pos, schem, rot, replace, fp)
		-- Don't place trees intersecting chunk borders in the X,Z directions.
		local b = 5
		if pos.x >= (emin.x + b) and pos.x <= (emax.x - b) and
			 pos.z >= (emin.z + b) and pos.z <= (emax.z - b) then
			minetest.place_schematic_on_vmanip(vm, pos, schem, rot, replace, fp)
		end
	end

	local treebase = cw.worldpath .. "/cw_jungletree_base.mts"
	local treetop = cw.worldpath .. "/cw_jungletree_top.mts"
	local notrunk = cw.worldpath .. "/cw_jungletree_notrunk.mts"

	--local treebase = cw.worldpath .. "/cw_jungletree_base.mts"
	--local treetop = cw.worldpath .. "/cw_jungletree_base.mts"
	--local notrunk = cw.worldpath .. "/cw_jungletree_base.mts"

	for k, v_orig in ipairs(tree_positions1) do
		local v = table.copy(v_orig)
		local bottom = v.y
		local w = v.w
		if w > 1.0 then
			w = 1.0
		end
		local h = math.floor(TREE_HEIGHT_MOD * w)
		v.w = nil

		-- Schematic horizontal offset.
		v.x = v.x - 2
		v.z = v.z - 2

		-- Tree base.
		PUT_SCHEM(vm, v, treebase, strrnd, JP, FP)

		---[[
		local midleveltree = treetop
		if h >= (TREE_HEIGHT_MOD - 1) then
			-- Remove 1/3 of the trunks.
			if column_pr:next(1, 3) == 1 then
				midleveltree = notrunk
			end
		elseif h >= TREE_HEIGHT_MOD then
			-- Remove 2/3 of the trunks.
			if column_pr:next(1, 3) <= 2 then
				midleveltree = notrunk
			end
		elseif h > 10 then
			midleveltree = treebase
		end

		-- Require a minimum height step of 7 for taller trees.
		if column_pr:next(1, 5) <= 4 and h >= 7 then
			v.y = v.y + h
			if h > 10 then
				local rp = vector.add(v, RANDPOS[math_random(1, #RANDPOS)])
				PUT_SCHEM(vm, rp, midleveltree, strrnd, JP, FP)
			else
				PUT_SCHEM(vm, v, midleveltree, strrnd, JP, FP)
			end

			if column_pr:next(1, 3) <= 2 then
				v.y = v.y + h
				if h > 10 then
					local rp = vector.add(v, RANDPOS[math_random(1, #RANDPOS)])
					PUT_SCHEM(vm, rp, midleveltree, strrnd, JP, FP)
				else
					PUT_SCHEM(vm, v, midleveltree, strrnd, JP, FP)
				end

				-- Treetops.
				if h >= 10 then
					if column_pr:next(1, 2) == 1 then
						v.y = v.y + 13
						PUT_SCHEM(vm, v, treetop, strrnd, JP, FP)

						if h > 10 and column_pr:next(1, 3) == 1 then
							v.y = v.y + 13
							PUT_SCHEM(vm, v, treetop, strrnd, JP, FP)
						end
					end
				elseif h >= 8 then
					if column_pr:next(1, 3) == 1 then
						v.y = v.y + 12
						PUT_SCHEM(vm, v, treetop, strrnd, JP, FP)
					end
				end
			end
		end
		--]]

		-- Store tree bottom/top.
		v_orig.b = bottom
		v_orig.t = v.y + 17
	end
	end -- ENABLE_TREES

	-- Shall return true if ID is anything the mapgen places as part of forests.
	local function farsig(id)
		return (id == c_leaves or id == c_tree or id == c_tree2 or id == c_soil
			or id == c_junglegrass or id == c_grass)
	end

	-- Shall return true if ID is a supporting structural node.
	local function nearsup(id)
		return (id == c_leaves or id == c_soil or id == c_tree or id == c_tree2)
	end

	-- Final mapgen pass, for finding floors and ceilings in the forest.
	-- Have to "get_data" again because we placed a bunch of schematics on the vmanip.
	vm:get_data(data)
	vm:get_param2_data(param2_data)
  for x = x0, x1 do
    for z = z0, z1 do
      for y = y0, y1 do
				local center = area:index(x, y, z)
				local under = area:index(x, y-1, z)
				local above = area:index(x, y+1, z)
				local north = area:index(x, y, z+1)
				local south = area:index(x, y, z-1)
				local east = area:index(x+1, y, z)
				local west = area:index(x-1, y, z)
				local sevenup = area:index(x, y+7, z)
				local farnorth = area:index(x, y, z+7)
				local farsouth = area:index(x, y, z-7)
				local fareast = area:index(x+7, y, z)
				local farwest = area:index(x-7, y, z)

				local center_id = data[center]
				local above_id = data[above]
				local under_id = data[under]
				local north_id = data[north]
				local south_id = data[south]
				local west_id = data[west]
				local east_id = data[east]
				local sevenup_id = data[sevenup]
				local farnorth_id = data[farnorth]
				local farsouth_id = data[farsouth]
				local farwest_id = data[farwest]
				local fareast_id = data[fareast]

				-- Decorations not to be placed in the tops of forests.
				if y < (nstart + 60) then
					-- Check if we have neighboring supports directly adjacent to us.
					local border_count = 0
					if nearsup(north_id) then
						border_count = border_count + 1
					end
					if nearsup(south_id) then
						border_count = border_count + 1
					end
					if nearsup(west_id) then
						border_count = border_count + 1
					end
					if nearsup(east_id) then
						border_count = border_count + 1
					end

					-- Check if we have neighboring trees at a distance.
					-- This reduces border count at the edges of forest clusters, and
					-- at altitude where the trees are thinner.
					local far_count = 0
					if farsig(farnorth_id) then
						far_count = far_count + 1
					end
					if farsig(farsouth_id) then
						far_count = far_count + 1
					end
					if farsig(farwest_id) then
						far_count = far_count + 1
					end
					if farsig(fareast_id) then
						far_count = far_count + 1
					end

					local water_count = 0
					if north_id == c_water then
						water_count = water_count + 1
					end
					if south_id == c_water then
						water_count = water_count + 1
					end
					if west_id == c_water then
						water_count = water_count + 1
					end
					if east_id == c_water then
						water_count = water_count + 1
					end

					local roofed = (sevenup_id == c_tree or sevenup_id == c_tree2 or sevenup_id == c_leaves or sevenup_id == c_junglegrass)
					local support = (under_id == c_leaves or under_id == c_tree or under_id == c_tree2)
					local fillable = (center_id == c_air or (center_id == c_leaves and above_id == c_air))
					local grassable = (center_id == c_air)

					if roofed and fillable and support and border_count >= 4 and far_count >= 4 then
						data[center] = c_soil

						-- Put a horizontal branch peice underneath the soil.
						data[under] = c_tree2
						param2_data[under] = branch_rotations[math_random(1, 4)]
					elseif roofed and support and grassable and far_count >= 3 then
						-- Randomly place grass or junglegrass.
						if math_random(1, 3) == 1 then
							data[center] = c_grass
						else
							data[center] = c_junglegrass
						end
						param2_data[center] = 2
					elseif above_id == c_air and center_id == c_tree and water_count >= 2 then
						-- Place grass on trunks near water.
						if math_random(1, 3) == 1 then
							data[above] = c_grass
						else
							data[above] = c_grass2
						end
						param2_data[above] = 2
					elseif center_id == c_water and above_id == c_air and border_count >= 1 then
						-- Place lilies around tree trunks on water.
						if math_random(1, 4) == 1 then
							data[above] = c_lily
							param2_data[above] = math_random(0, 3)
						end
					elseif center_id == c_sand and above_id == c_air and border_count >= 1 then
						if math_random(1, 2) == 1 then
							data[above] = c_grass3
							param2_data[above] = 2
						end
					end

					-- Horizontal branch placement.
					if center_id == c_tree and roofed and (under_id == c_leaves or above_id == c_leaves) then
						if param2_data[center] == 0 then
							local diridx = math_random(1, 4)
							local facedir = branch_directions[diridx]
							data[center] = c_tree2
							param2_data[center] = branch_rotations[diridx]

							-- Extend branches horizontally.
							-- Branches get longer (2 + far_count) if trees are denser.
							local dir = minetest.facedir_to_dir(facedir)
							local n = math_random(0, 2 + far_count)
							local pos = {x=x, y=y, z=z}
							for k = 1, n, 1 do
								pos = vector.add(pos, dir)
								local idx = area:index(pos.x, pos.y, pos.z)
								data[idx] = c_tree2
								param2_data[idx] = branch_rotations[diridx]

								-- Place leaves at end of branch.
								local p2 = vector.add(pos, dir)
								local i2 = area:index(p2.x, p2.y, p2.z)
								if data[i2] == c_air then
									data[i2] = c_leaves
								end

								-- Place leaves hanging from branch.
								local p3 = vector.add(pos, {x=0, y=-1, z=0})
								local i3 = area:index(p3.x, p3.y, p3.z)
								if data[i3] == c_air then
									data[i3] = c_leaves
								end
							end
						end
					end
				end -- Y below (nstart + 60).

				-- Hanging papyrus.
				if center_id == c_air and above_id == c_leaves and under_id == c_air then
					if math_random(1, 50) == 1 then
						local pos = {x=x, y=y, z=z}
						local n = math_random(2, 8)
						for k = 1, n, 1 do
							local idx = area:index(pos.x, pos.y, pos.z)
							pos.y = pos.y - 1

							if data[idx] == c_air then
								data[idx] = c_papyrus2
							else
								break
							end
						end
					end
				end

				-- Convert a percentage of leaves into dry leaves.
				if center_id == c_leaves and under_id == c_leaves then
					if math_random(1, 100) <= 5 then
						data[center] = DRY_LEAVES_LIST[math_random(1, #DRY_LEAVES_LIST)]
						param2_data[center] = 2
					end
				end
      end
    end
  end
  vm:set_data(data)
  vm:set_param2_data(param2_data)

	-- Finalize voxel manipulator.
	-- Note: we specifically do not generate ores! The value of this realm is in
	-- its trees.
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	-- Liquid is never added in a way that would require flowing update.
	--vm:update_liquids()
	--vm:write_to_map()

	--[[
	for k, v in ipairs(tree_positions1) do
		local bottom = v.y
		local top = v.t

		-- This is somewhat intensive, so don't run for every single tree.
		if math_random(1, 5) == 1 then
			local minp = {x=v.x - 2, y=bottom, z=v.z - 2}
			local maxp = {x=v.x + 2, y=top, z=v.z + 2}
			dryleaves.replace_leaves(minp, maxp, 5)
		end
	end
	--]]
end



minetest.register_on_generated(function(...)
	cw.generate_realm(...)
end)
