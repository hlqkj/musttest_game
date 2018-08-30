
moretrees = moretrees or {}



moretrees.can_grow = function(pos)
	if pos.y < -30 then
		return false
	end

	local node_under = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
	if not node_under then
		return false
	end
	local name_under = node_under.name
	local is_soil = minetest.get_item_group(name_under, "soil")
	if is_soil == 0 then
		return false
	end
	local light_level = minetest.get_node_light(pos)
	if not light_level or light_level < 12 then
		return false
	end
	return true
end



moretrees.sapling_selection_box = {
    type = "fixed",
    fixed = {-0.3, -0.5, -0.3, 0.3, 0.35, 0.3},
}



moretrees.sapling_groups = {
    level = 1,
    snappy = 3,
    choppy = 3,
    oddly_breakable_by_hand = 3,
    --dig_immediate = 3,
        
    flammable = 2,
    attached_node = 1,
    sapling = 1,
}



moretrees.tree_groups = {
    tree = 1,
    level = 1,
    choppy = 1,
    flammable = 2,
}



moretrees.get_wood_groups = function(extra)
    local groups = extra or {}
    
    groups.level = 1
    groups.choppy = 2
    
    groups.flammable = 2
    groups.wood = 1
    return groups
end



moretrees.stair_groups = {
    level = 1,
    choppy = 2,
    
    flammable = 2,
}



moretrees.leaves_groups = {
    level = 1,
    snappy = 3,
    choppy = 2,
    oddly_breakable_by_hand = 3,
    
    leafdecay = 3,
    flammable = 2,
    leaves = 1,
    green_leaves = 1,
}



moretrees.get_leafdrop_table = function(chance, sapling, leaves)
    local drop = {
		max_items = 1,
		items = {
			{items={sapling}, rarity=chance},
			{items={"default:stick"}, rarity=10},
			{items={leaves}},
		}
	}
    return drop
end

