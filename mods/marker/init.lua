
marker = marker or {}
marker.modpath = minetest.get_modpath("marker")
marker.players = marker.players or {}
marker.gui = marker.gui or {}
marker.steptime = 1
marker.max_waypoints = 100
marker.max_lists = 50

local timer = 0
local delay = marker.steptime
function marker.on_globalstep(dtime)
	timer = timer + dtime
	if timer < delay then return end
	timer = 0
	marker.update_huds()
end

function marker.update_huds()
	-- localize
	-- create gui for player if not created already
	local players = marker.players

	for k, v in pairs(players) do
		marker.update_single_hud(k)
	end
end

function marker.on_leaveplayer(pref, timeout)
	local pname = pref:get_player_name()
	marker.players[pname] = nil
	marker.gui[pname] = nil
end

function marker.update_single_hud(player)
	local allgui = marker.gui
	if not allgui[player] then
		marker.create_gui(player)
	end
	local gui = allgui[player]
	local waypoints = gui.waypoints

	local pref = minetest.get_player_by_name(player)
	if not pref or not pref:is_player() then
		return
	end
	local d = vector.distance
	local p2 = pref:get_pos()

	for i = 1, #waypoints, 1 do
		local data = waypoints[i]
		local dist = d(data.pos, p2)

		if dist > 10 and dist < 60 then
			-- add hud element if nearby and not already added
			if not data.hnd then
				local wp = vector.add(data.pos, {x=0, y=1, z=0})
				local number = "7902626"
				if data.highlight then
					number = "8739932"
				end
				data.hnd = pref:hud_add({
					hud_elem_type = "waypoint",
					name = "Marker",
					number = number,
					world_pos = wp,
				})
			end
		elseif dist < 10 or dist > 80 then
			-- remove hud element if too far and not yet removed
			if data.hnd then
				pref:hud_remove(data.hnd)
				data.hnd = nil
			end
		end

		if dist < 30 then
			if not data.pts then
				local wp = vector.add(data.pos, {x=0, y=0.5, z=0})
				local particles = {
					amount = 10,
					time = 0,
					minpos = wp,
					maxpos = wp,
					minvel = vector.new(-0.5, -0.5, -0.5),
					maxvel = vector.new(0.5, 0.5, 0.5),
					minacc = {x=0, y=0, z=0},
					maxacc = {x=0, y=0, z=0},
					minexptime = 0.5,
					maxexptime = 1.5,
					minsize = 1,
					maxsize = 1,
					collisiondetection = false,
					collision_removal = false,
					vertical = false,
					texture = "quartz_crystal_piece.png",
					glow = 14,
					playername = player,
				}
				data.pts = minetest.add_particlespawner_single(particles)
			end
		elseif dist > 35 then
			if data.pts then
				minetest.delete_particlespawner(data.pts, player)
				data.pts = nil
			end
		end
	end
end

function marker.update_hud_markers(player, list, highlight)
	-- localize
	local allgui = marker.gui
	if not allgui[player] then
		marker.create_gui(player)
	end
	local gui = allgui[player]
	local waypoints = gui.waypoints

	-- remove all existing hud elements
	local pref = minetest.get_player_by_name(player)
	if not pref or not pref:is_player() then
		return
	end
	for i = 1, #waypoints, 1 do
		local data = waypoints[i]
		if data.hnd then
			pref:hud_remove(data.hnd)
			data.hnd = nil
		end
		if data.pts then
			minetest.delete_particlespawner(data.pts, player)
			data.pts = nil
		end
		if data.highlight then
			data.highlight = nil
		end
	end

	-- update waypoint list data
	gui.waypoints = {}
	waypoints = gui.waypoints
	if gui.show and list and list ~= "" then
		local data = marker.get_list(player, list)
		for i = 1, #data, 1 do
			waypoints[#waypoints + 1] = {pos=table.copy(data[i])}

			if highlight and highlight == i then
				waypoints[#waypoints].highlight = true
			end
		end
	end

	marker.update_single_hud(player)
end

function marker.highlight_marker(player, index)
	-- localize
	local allgui = marker.gui
	if not allgui[player] then
		marker.create_gui(player)
	end
	local gui = allgui[player]
	local waypoints = gui.waypoints

	for i = 1, #waypoints, 1 do
		local data = waypoints[i]
		if data.highlight then
			data.highlight = nil

			-- return marker to regular color
			if data.hnd then
				local pref = minetest.get_player_by_name(player)
				if pref and pref:is_player() then
					pref:hud_change(data.hnd, "number", "7902626")
				end
			end
		end
	end

	if index >= 1 and index <= #waypoints then
		local data = waypoints[index]
		if not data.highlight then
			data.highlight = true

			-- change (highlight) marker color
			if data.hnd then
				local pref = minetest.get_player_by_name(player)
				if pref and pref:is_player() then
					pref:hud_change(data.hnd, "number", "8739932")
				end
			end
		end
	end
end

-- private: load player data
function marker.load_player(player)
	-- localize
	local players = marker.players

	-- load player data from mod storage
	local str = marker.storage:get_string(player)
	assert(type(str) == "string")

	if str == "" then
		players[player] = {}
		return
	end

	local lists = minetest.deserialize(str)

	if not lists then
		players[player] = {}
		return
	end

	-- data is now loaded
	assert(type(lists) == "table")
	players[player] = lists
end

-- private: save player data
function marker.save_player(player)
	-- localize
	local players = marker.players

	-- localize
	local lists = players[player] or {}

	local str = minetest.serialize(lists)
	assert(type(str) == "string")

	-- send data to mod storage
	marker.storage:set_string(player, str)
end

-- api: player name, position, list name
function marker.add_waypoint(player, pos, list)
	-- localize
	local players = marker.players

	-- load data for player if not loaded already
	if not players[player] then
		marker.load_player(player)
	end

	-- localize
	local lists = players[player]

	-- create waypoint list if not created already
	local found = false
	local positions
	for i = 1, #lists, 1 do
		if lists[i].name == list then
			found = true
			positions = lists[i].data
			break
		end
	end
	if not found then
		lists[#lists + 1] = {name=list, data={}}
		positions = lists[#lists].data
	end

	-- add position
	positions[#positions + 1] = vector.round(pos)

	-- save changes
	marker.save_player(player)
end

-- api: player name, index, list name
function marker.remove_waypoint(player, index, list)
	-- localize
	local players = marker.players

	-- load data for player if not loaded already
	if not players[player] then
		marker.load_player(player)
	end

	-- localize
	local lists = players[player]

	-- search player data for named list
	-- ignore if list doesn't exist
	local found = false
	local positions
	for i = 1, #lists, 1 do
		if lists[i].name == list then
			found = true
			positions = lists[i].data
			break
		end
	end
	if not found then
		return
	end

	-- localize
	local equals = vector.equals
	local changed = false
	local pos

	-- erase position from positions list
	if index >= 1 and index <= #positions then
		pos = positions[index]
		table.remove(positions, index)
		changed = true
	end

	-- save changes if needed
	if changed then
		marker.save_player(player)
	end

	-- return pos or nil
	return pos
end

-- private: get the list of positions for a given list name
--
-- important: the list can be modified, and if modified, must be saved afterward
-- by calling marker.save_player(), otherwise changes will be lost eventually
function marker.get_list(player, list)
	assert(type(list) == "string" and list ~= "")

	-- localize
	local players = marker.players

	-- load data for player if not loaded already
	if not players[player] then
		marker.load_player(player)
	end

	-- localize
	local lists = players[player]

	-- if named list doesn't exist, create it
	local found = false
	local positions
	for i = 1, #lists, 1 do
		if lists[i].name == list then
			found = true
			positions = lists[i].data
			break
		end
	end
	if not found then
		lists[#lists + 1] = {name=list, data={}}
		positions = lists[#lists].data

		-- a new list was added, need to save data
		marker.save_player(player)
	end

	-- return the named list
	-- the list can be modifed
	-- remember to save the data
	return positions
end

-- api: player name, list index
function marker.get_list_name(player, index)
	-- localize
	local players = marker.players

	-- load data for player if not loaded already
	if not players[player] then
		marker.load_player(player)
	end

	-- localize
	local lists = players[player]

	local name = ""
	for i = 1, #lists, 1 do
		if lists[i].name == "default" then
			if index >= i then
				index = index + 1

				-- fix corner case
				if index > #lists then
					index = #lists
				end
			end
		end
		if i == index then
			name = lists[i].name
			break
		end
	end

	return name
end

-- api: player name, list name
function marker.have_list(player, list)
	local players = marker.players
	if not players[player] then
		return false
	end

	local alists = players[player]
	local found = false
	for i = 1, #alists, 1 do
		if alists[i].name == list then
			found = true
			break
		end
	end
	return found
end

-- api: player name, list name
function marker.list_size(player, list)
	local players = marker.players
	if not players[player] then
		return 0
	end

	local alists = players[player]
	local size = 0
	for i = 1, #alists, 1 do
		if alists[i].name == list then
			size = #(alists[i].data)
			break
		end
	end
	return size
end

function marker.list_count(player)
	local players = marker.players
	if not players[player] then
		return 0
	end
	local alists = players[player]
	local size = 0
	for i = 1, #alists, 1 do
		if alists[i].name ~= "default" then
			size = size + 1
		end
	end
	return size
end

-- api: player name, list name
function marker.remove_list(player, list)
	local players = marker.players
	if not players[player] then
		return
	end

	local changed = false
	local alists = players[player]
	for i = 1, #alists, 1 do
		if alists[i].name == list then
			table.remove(alists, i)
			changed = true
			break
		end
	end

	if changed then
		marker.save_player(player)
	end
end

-- private: create gui-data for player
function marker.create_gui(player)
	marker.gui[player] = {
		index1 = -1,
		index2 = -1,
		index3 = -1,
		listname = "",
		playername = "",
		waypoints = {},
	}
end

-- private: assemble a formspec string
function marker.get_formspec(player)
	-- localize
	local players = marker.players
	local allgui = marker.gui

	-- load data for player if not loaded already
	if not players[player] then
		marker.load_player(player)
	end
	local alists = players[player]

	-- create gui for player if not created already
	if not allgui[player] then
		marker.create_gui(player)
	end
	local gui = allgui[player]

	local deflist = marker.get_list(player, "default")

	local formspec = "size[9,7]" ..
    default.gui_bg ..
    default.gui_bg_img ..
    default.gui_slots

	formspec = formspec ..
		"item_image[0,0;1,1;passport:passport_adv]" ..
    "label[1,0;Key Device Marker System]" ..
		"field[0.3,1.3;2.9,1;listname;;" .. minetest.formspec_escape(gui.listname) .. "]" ..
		"field[0.3,2.15;2.9,1;player;;" .. minetest.formspec_escape(gui.playername) .. "]"

	formspec = formspec ..
		"textlist[5.0,0.0;3.7,2.6;lists;"

	local comma = ""
	--minetest.log(dump(alists))
	for i = 1, #alists, 1 do
		local k = alists[i].name
		if k ~= "default" then
			formspec = formspec .. comma .. k
			comma = ","
		end
	end

	formspec = formspec .. ";" .. gui.index1 .. "]" ..
		"textlist[0.0,3.0;3.7,3.0;markers;"

	for i = 1, #deflist, 1 do
		local s = rc.pos_to_namestr(deflist[i])
		formspec = formspec .. minetest.formspec_escape(s)
		if i < #deflist then
			formspec = formspec .. ","
		end
	end

	formspec = formspec .. ";" .. gui.index2 .. "]" ..
		"textlist[5.0,3.0;3.7,4.0;positions;"

	local lname = marker.get_list_name(player, gui.index1)
	if lname and lname ~= "" then
		local data = marker.get_list(player, lname)
		comma = ""
		for i = 1, #data, 1 do
			local s = minetest.formspec_escape(rc.pos_to_namestr(data[i]))
			formspec = formspec .. comma .. s
			comma = ","
		end
	end

	formspec = formspec .. ";" .. gui.index3 .. "]"

	formspec = formspec ..
		"button[3.0,1.0;1,1;addlist;>]" ..
		"button[4.0,1.0;1,1;dellist;X]" ..
		"button[3.0,1.85;2,1;sendlist;Send List]" ..
		"button[4.0,3.0;1,1;ls;<]" ..
		"button[4.0,4.0;1,1;mark;Mark]" ..
		"button[4.0,5.0;1,1;rs;>]" ..
		"button[0.0,6.25;1,1;done;Done]" ..
		"button[1.0,6.25;1,1;delete;Erase]"

	if not gui.show then
		formspec = formspec .. "button[2.0,6.25;3,1;show;Enable Scan]"
	else
		formspec = formspec .. "button[2.0,6.25;3,1;hide;Disable Scan]"
	end

	return formspec
end

-- api: show formspec to player
function marker.show_formspec(player)
	local formspec = marker.get_formspec(player)
	minetest.show_formspec(player, "marker:fs", formspec)
end

marker.on_receive_fields = function(player, formname, fields)
  if formname ~= "marker:fs" then return end
  local pname = player:get_player_name()

	-- security check to make sure player can use this feature
	local inv = player:get_inventory()
	if not inv:contains_item("main", "passport:passport_adv") then
		return true
	end

	-- ensure user-data is loaded and available
	if not marker.players[pname] then
		marker.load_player(pname)
	end

	-- localize
	-- create gui for player if not created already
	local allgui = marker.gui
	if not allgui[pname] then
		marker.create_gui(pname)
	end
	local gui = allgui[pname]

	if fields.done or fields.quit then
    passport.show_formspec(pname)
		return true
	end

	if fields.listname then
		gui.listname = fields.listname
	end
	if fields.player then
		gui.playername = fields.player
	end

	if fields.show then
		gui.show = true
		if gui.listname and gui.listname ~= "" then
			marker.update_hud_markers(pname, gui.listname)
		end
	end
	if fields.hide then
		gui.show = nil
		marker.update_hud_markers(pname)
	end

  if fields.addlist then
		if marker.list_count(pname) < marker.max_lists then
			local name = fields.listname or ""
			name = name:trim()
			if name == "" then
				minetest.chat_send_player(pname, "# Server: Cannot add list with empty name.")
			elseif name == "default" then
				minetest.chat_send_player(pname, "# Server: Cannot add list with reserved name.")
			else
				if marker.have_list(pname, name) then
					minetest.chat_send_player(pname, "# Server: Cannot add list, it already exists.")
				else
					-- this automatically adds the list if it doesn't exist
					local pos = player:get_pos()
					marker.add_waypoint(pname, pos, name)
					gui.index1 = #(marker.players[pname])
					gui.index3 = -1
					marker.update_hud_markers(pname, name)
					minetest.chat_send_player(pname, "# Server: Added list.")
				end
			end
		else
			minetest.chat_send_player(pname, "# Server: Marker list roster is full, cannot create a new marker list.")
		end
  elseif fields.dellist then
		local name = fields.listname or ""
		name = name:trim()
		if name == "" then
			minetest.chat_send_player(pname, "# Server: Cannot remove list with empty name.")
		elseif name == "default" then
			minetest.chat_send_player(pname, "# Server: Cannot remove list with reserved name.")
		else
			if marker.have_list(pname, name) then
				marker.remove_list(pname, name)
				gui.index1 = -1
				gui.listname = ""
				marker.update_hud_markers(pname)
				minetest.chat_send_player(pname, "# Server: Removed marker list.")
			else
				minetest.chat_send_player(pname, "# Server: Cannot remove non-existent list.")
			end
		end
  elseif fields.sendlist then
		local targetname = fields.player or ""
		targetname = targetname:trim()
		if targetname ~= "" then
			targetname = rename.grn(targetname)
			if targetname ~= pname then
				local ptarget = minetest.get_player_by_name(targetname)
				if ptarget and ptarget:is_player() then
					if vector.distance(ptarget:get_pos(), player:get_pos()) < 5 then
						local inv = ptarget:get_inventory()
						if inv:contains_item("main", "passport:passport_adv") then
							local name = marker.get_list_name(pname, gui.index1)
							if name and name ~= "" then
								-- load data for target player if not loaded already
								-- otherwise checking to see if player already has list could fail
								-- in a very wrong way
								if not marker.players[targetname] then
									marker.load_player(targetname)
								end
								if marker.have_list(targetname, name) then
									minetest.chat_send_player(pname, "# Server: The other Key already hosts a marker list with that name. Cannot transfer data!")
								else
									local datafrom = marker.get_list(pname, name)
									local datato = marker.get_list(targetname, name)
									for i = 1, #datafrom, 1 do
										datato[#datato + 1] = table.copy(datafrom[i])
									end
									minetest.chat_send_player(pname, "# Server: Marker list sent!")
								end
							else
								minetest.chat_send_player(pname, "# Server: You must select a marker list, first.")
							end
						else
							minetest.chat_send_player(pname, "# Server: The other player does not have a Key!")
						end
					else
						minetest.chat_send_player(pname, "# Server: You need to stand close to the other player's Key to transfer a marker list.")
					end
				else
					minetest.chat_send_player(pname, "# Server: The specified player is not available.")
				end
			else
				minetest.chat_send_player(pname, "# Server: Cannot send marker list to your own Key.")
			end
		else
			minetest.chat_send_player(pname, "# Server: You must specify the name of a player to send a marker list to.")
		end
  elseif fields.ls then
		local name = marker.get_list_name(pname, gui.index1)
		if name and name ~= "" then
			if marker.list_size(pname, "default") < marker.max_waypoints then
				local data = marker.get_list(pname, name)
				if gui.index3 >= 1 and gui.index3 <= #data then
					local pos = marker.remove_waypoint(pname, gui.index3, name)
					if pos then
						marker.add_waypoint(pname, pos, "default")
						local deflist = marker.get_list(pname, "default")
						gui.index2 = #deflist
						gui.index3 = -1
						marker.update_hud_markers(pname, name)
						minetest.chat_send_player(pname, "# Server: Moved marker to free-list.")
					else
						minetest.chat_send_player(pname, "# Server: Could not remove marker from list.")
					end
				else
					minetest.chat_send_player(pname, "# Server: You need to have selected a marker to be moved.")
				end
			else
				minetest.chat_send_player(pname, "# Server: Cannot remove marker from list, free-list storage is full.")
			end
		else
			minetest.chat_send_player(pname, "# Server: You must select a marker list, first.")
		end
  elseif fields.rs then
		local name = marker.get_list_name(pname, gui.index1)
		if name and name ~= "" then
			if marker.list_size(pname, name) < marker.max_waypoints then
				local data = marker.get_list(pname, "default")
				if gui.index2 >= 1 and gui.index2 <= #data then
					local pos = marker.remove_waypoint(pname, gui.index2, "default")
					if pos then
						marker.add_waypoint(pname, pos, name)
						local thelist = marker.get_list(pname, name)
						gui.index3 = #thelist
						gui.index2 = -1
						marker.update_hud_markers(pname, name, gui.index3)
						minetest.chat_send_player(pname, "# Server: Moved unattached marker to list.")
					else
						minetest.chat_send_player(pname, "# Server: Could not remove marker from free-list.")
					end
				else
					minetest.chat_send_player(pname, "# Server: You need to have selected a marker to be moved.")
				end
			else
				minetest.chat_send_player(pname, "# Server: Cannot add marker to list, list storage is full.")
			end
		else
			minetest.chat_send_player(pname, "# Server: You must select a marker list, first.")
		end
  elseif fields.mark then
		if marker.list_size(pname, "default") < marker.max_waypoints then
			local pos = player:get_pos()
			marker.add_waypoint(pname, pos, "default")
			local deflist = marker.get_list(pname, "default")
			gui.index2 = #deflist
			minetest.chat_send_player(pname, "# Server: Placed marker at " .. rc.pos_to_namestr(vector.round(pos)) .. ".")
		else
			minetest.chat_send_player(pname, "# Server: Cannot place a new marker, storage is full.")
		end
  elseif fields.delete then
		local index = gui.index2
		local deflist = marker.get_list(pname, "default")
		if index >= 1 and index <= #deflist then
			local s = rc.pos_to_namestr(deflist[index])
			marker.remove_waypoint(pname, index, "default")
			gui.index2 = -1
			minetest.chat_send_player(pname, "# Server: Removed marker: " .. s .. ".")
		else
			minetest.chat_send_player(pname, "# Server: You must select a marker from the marker list, to erase it.")
		end
  elseif fields.lists then
		local event = minetest.explode_textlist_event(fields.lists)
		if event.type == "CHG" then
			local index = event.index
			gui.index1 = index
			gui.index3 = -1
			gui.listname = marker.get_list_name(pname, index)
			marker.update_hud_markers(pname, gui.listname)
		end
  elseif fields.markers then
		local event = minetest.explode_textlist_event(fields.markers)
		if event.type == "CHG" then
			local index = event.index
			gui.index2 = index
		end
  elseif fields.positions then
		local event = minetest.explode_textlist_event(fields.positions)
		if event.type == "CHG" then
			local index = event.index
			gui.index3 = index
			marker.highlight_marker(pname, index)
		end
  elseif fields.listname then
		-- nothing here atm
  elseif fields.player then
		-- nothing here atm
  end

	marker.show_formspec(pname)
  return true
end

if not marker.registered then
	marker.storage = minetest.get_mod_storage()

  minetest.register_on_player_receive_fields(function(...)
		return marker.on_receive_fields(...)
	end)

	minetest.register_globalstep(function(...)
		return marker.on_globalstep(...)
	end)

	minetest.register_on_leaveplayer(function(...)
		return marker.on_leaveplayer(...)
	end)

	local c = "marker:core"
	local f = marker.modpath .. "/init.lua"
	reload.register_file(c, f, false)

	marker.registered = true
end
