
if not minetest.global_exists("chat_controls") then chat_controls = {} end
chat_controls.modpath = minetest.get_modpath("chat_controls")
chat_controls.players = chat_controls.players or {}

-- Localize vector.distance() for performance.
local vector_distance = vector.distance



function chat_controls.player_ignored(pname, from)
	if not chat_controls.players[pname] then
		return
	end
	local tb = chat_controls.players[pname]
	local ignore = tb.ignore or {}
	for i = 1, #ignore do
		if ignore[i] == from then
			return true
		end
	end
end

function chat_controls.beep_enabled(pname)
	local tb = chat_controls.players[pname]
	if not tb then
		return
	end
	if tb.nobeep == "true" then
		return false
	end
	return true
end

function chat_controls.player_ignored_pm(pname, from)
	if not chat_controls.players[pname] then
		return
	end
	local tb = chat_controls.players[pname]
	local pm = tb.pm or {}
	for i = 1, #pm do
		if pm[i] == from then
			return true
		end
	end
end

function chat_controls.player_ignored_shout(pname, from)
	if not chat_controls.players[pname] then
		return
	end
	local tb = chat_controls.players[pname]
	local shout = tb.shout or {}
	for i = 1, #shout do
		if shout[i] == from then
			return true
		end
	end
end



function chat_controls.player_too_far(pname, from)
	if not chat_controls.players[pname] then
		return
	end
	local tb = chat_controls.players[pname]
	if tb.chathide ~= "true" then
		return
	end
	local dist = tb.distance
	local p1 = minetest.get_player_by_name(pname)
	local p2 = minetest.get_player_by_name(from)
	if not p1 or not p2 then
		return
	end
	local d1 = p1:get_pos()
	local d2 = p2:get_pos()
	if vector_distance(d1, d2) > dist then
		return true
	end
end



function chat_controls.non_citizen_ignored(pname, from)
	if not chat_controls.players[pname] then
		return
	end
	local tb = chat_controls.players[pname]
	if tb.nopochide ~= "true" then
		return
	end
	if not passport.player_registered(from) then
		return true
	end
end



function chat_controls.player_whitelisted(pname, from)
	if not chat_controls.players[pname] then
		return
	end
	local tb = chat_controls.players[pname]
	local white = tb.white
	for i = 1, #white do
		if white[i] == from then
			return true
		end
	end
end



function chat_controls.check_highlighting_filters(pname, from, message)
	if not chat_controls.players[pname] then
		return
	end
	local tb = chat_controls.players[pname]
	local filter = tb.filter
	local find = string.find

	-- Skip leading playername.
	local start = find(message, ">")
	if not start then start = 0 end
	start = start + 1

	local dfrom = rename.gpn(from)

	for i = 1, #filter do
		if filter[i] == from or filter[i] == dfrom then
			return true
		end
		if find(message, filter[i], start) then
			return true
		end
	end
end



-- Load lists from storage.
function chat_controls.load_lists_for_player(pname)
	local ms = chat_controls.modstorage
	local ignore = ms:get_string(pname .. ":i")
	local filter = ms:get_string(pname .. ":f")
	local white = ms:get_string(pname .. ":w")
	local chathide = ms:get_string(pname .. ":h")
	local nopochide = ms:get_string(pname .. ":n")
	local nobeep = ms:get_string(pname .. ":b")
	local distance = ms:get_int(pname .. ":d")
	local pm = ms:get_string(pname .. ":p")
	local shout = ms:get_string(pname .. ":s")

	-- Could be uninitialized if user never selected an option.
	if chathide == "" then
		chathide = "false"
	end
	if nobeep == "" then
		nobeep = "false"
	end
	if nopochide == "" then
		nopochide = "false"
	end

	ignore = minetest.deserialize(ignore)
	filter = minetest.deserialize(filter)
	white = minetest.deserialize(white)
	pm = minetest.deserialize(pm)
	shout = minetest.deserialize(shout)

	-- Ensure player entry exists.
	local entry = chat_controls.players[pname]
	if not entry then
		chat_controls.players[pname] = {}
		entry = chat_controls.players[pname]
	end

	entry.chathide = chathide
	entry.nopochide = nopochide
	entry.distance = distance
	entry.nobeep = nobeep

	if type(ignore) == "table" then
		entry.ignore = ignore
	else
		entry.ignore = {}
	end

	if type(filter) == "table" then
		entry.filter = filter
	else
		entry.filter = {}
	end

	if type(white) == "table" then
		entry.white = white
	else
		entry.white = {}
	end

	if type(pm) == "table" then
		entry.pm = pm
	else
		entry.pm = {}
	end

	if type(shout) == "table" then
		entry.shout = shout
	else
		entry.shout = {}
	end
end



-- Save current lists to storage.
function chat_controls.save_lists_for_player(pname)
	if not chat_controls.players[pname] then
		return
	end

	local tb = chat_controls.players[pname]
	local chathide = tb.chathide
	local nopochide = tb.nopochide
	local distance = tb.distance
	local nobeep = tb.nobeep

	-- Could be uninitialized if user never selected an option.
	if chathide == "" then
		chathide = "false"
	end
	if nobeep == "" then
		nobeep = "false"
	end
	if nopochide == "" then
		nopochide = "false"
	end

	-- Clamp to prevent data corruption.
	if distance < 0 then
		distance = 0
	end
	if distance > 30000 then
		distance = 30000
	end

	local ignore = minetest.serialize(tb.ignore or {}) or ""
	local filter = minetest.serialize(tb.filter or {}) or ""
	local white = minetest.serialize(tb.white or {}) or ""
	local pm = minetest.serialize(tb.pm or {}) or ""
	local shout = minetest.serialize(tb.shout or {}) or ""

	local ms = chat_controls.modstorage
	ms:set_string(pname .. ":i", ignore)
	ms:set_string(pname .. ":f", filter)
	ms:set_string(pname .. ":w", white)
	ms:set_string(pname .. ":h", chathide)
	ms:set_string(pname .. ":n", nopochide)
	ms:set_string(pname .. ":b", nobeep)
	ms:set_int(pname .. ":d", distance)
	ms:set_string(pname .. ":p", pm)
	ms:set_string(pname .. ":s", shout)
end



function chat_controls.on_joinplayer(pname, player)
	if passport.player_has_key(pname, player) then
		chat_controls.load_lists_for_player(pname)
	end
end



function chat_controls.on_leaveplayer(pname)
	chat_controls.players[pname] = nil
end



-- Update player lists from formspec fields.
function chat_controls.set_lists_from_fields(pname, fields)
	local ignore = string.gsub(fields.ignore, "^,", "")
	local filter = string.gsub(fields.filter, "^,", "")
	local white = string.gsub(fields.white, "^,", "")
	local pm = string.gsub(fields.pm, "^,", "")
	local shout = string.gsub(fields.shout, "^,", "")
	local distance = fields.dist

	ignore = ignore:trim()
	filter = filter:trim()
	white = white:trim()
	pm = pm:trim()
	shout = shout:trim()
	distance = distance:trim()

	distance = tonumber(distance) or 0
	if distance < 0 then
		distance = 0
	end
	if distance > 30000 then
		distance = 30000
	end

	ignore = string.split(ignore, ',') or {}
	filter = string.split(filter, ',') or {}
	white = string.split(white, ',') or {}
	pm = string.split(pm, ',') or {}
	shout = string.split(shout, ',') or {}

	local new_ignore = {}
	local new_filter = {}
	local new_white = {}
	local new_pm = {}
	local new_shout = {}

	-- Adjust renames in the ignore list.
	for i = 1, #ignore do
		local entry = string.trim(ignore[i])
		if #entry > 0 then
			new_ignore[#new_ignore+1] = rename.grn(entry)
		end
	end

	for i = 1, #white do
		local entry = string.trim(white[i])
		if #entry > 0 then
			new_white[#new_white+1] = rename.grn(entry)
		end
	end

	-- Don't use the rename algorithm on the filter list, since this often contains stuff other than player names.
	for i = 1, #filter do
		local entry = string.trim(filter[i])
		if #entry > 0 then
			new_filter[#new_filter+1] = (entry)
		end
	end

	for i = 1, #pm do
		local entry = string.trim(pm[i])
		if #entry > 0 then
			new_pm[#new_pm+1] = rename.grn(entry)
		end
	end

	for i = 1, #shout do
		local entry = string.trim(shout[i])
		if #entry > 0 then
			new_shout[#new_shout+1] = rename.grn(entry)
		end
	end

	chat_controls.players[pname] = chat_controls.players[pname] or {}
	local tb = chat_controls.players[pname]

	tb.ignore = new_ignore
	tb.filter = new_filter
	tb.white = new_white
	tb.pm = new_pm
	tb.shout = new_shout
	tb.distance = distance

	minetest.chat_send_player(pname, "# Server: Filters set!")
end



-- Get player lists in a format suitable for inclusion in a formspec.
function chat_controls.get_filters_as_text(pname)
	local ignore = ""
	local filter = ""
	local white = ""
	local distance = ""
	local pm = ""
	local shout = ""

	if chat_controls.players[pname] then
		local tb = table.copy(chat_controls.players[pname])

		ignore = tb.ignore or {}
		filter = tb.filter or {}
		white = tb.white or {}
		pm = tb.pm or {}
		shout = tb.shout or {}

		for i = 1, #ignore do
			ignore[i] = rename.gpn(ignore[i])
		end

		-- Filter list does not need renaming.

		for i = 1, #white do
			white[i] = rename.gpn(white[i])
		end

		for i = 1, #pm do
			pm[i] = rename.gpn(pm[i])
		end

		for i = 1, #shout do
			shout[i] = rename.gpn(shout[i])
		end

		ignore = table.concat(ignore, ",")
		filter = table.concat(filter, ",")
		white = table.concat(white, ",")
		pm = table.concat(pm, ",")
		shout = table.concat(shout, ",")

		distance = tostring(tb.distance)
	end

	return ignore, filter, white, distance, pm, shout
end



chat_controls.info = "* * * Documentation * * *\n" ..
	"\n" ..
	"Each of the three text fields uses the same format: separate names and words with commas. Whitespace does not matter.\n" ..
	"\n" ..
	"The ignore list is for players you don't want to hear from. If a player is listed here, you will not see their public chat or receive PMs from them. You might choose to ignore a player if they annoy you extremely, ruin your enjoyment of the server, or are just plain full of drama. There are two important points: an ignored player will still be able to get their messages through to you if they are standing very close -- the range is 64 meters. If you wish to prevent even this, you'll need to move away from them. An ignored player may also continue to send you mail using their Key of Citizenship.\n" ..
	"\n" ..
	"Also keep in mind that if an ignored player attempts to send you a PM, the server will inform them to the effect that you are not available for comment.\n" ..
	"\n" ..
	"The highlight list is for names or words that you want to see highlighed when players use them in chat. Note that you always see highlighted chat if your playername is used, so you don't need to include your name in this list. However, you will not see chat from an ignored player even if they include your name or a word you have put in this list.\n" ..
	"\n" ..
	"The whitelist entries are only needed if you choose to hide chat from players farther than a certain distance. In such a case, you will still see chat from whitelisted players no matter how far away they are. However, if that player is also ignored, the ignore list will take precedence.\n" ..
	"\n" ..
	"The <distance> field sets how many meters away you can see a player's chat from. You might choose to enable this filtering option if spawn is overrun by a horde of loud and annoying noobs. Alternatively, you could use this filter as a way to ignore all new players by default, unless they are close enough to you, while still receiving chat from everyone that you already know.\n" ..
	"\n" ..
	"Once you change your filter settings, you need to press 'Confirm Filters' in order to apply the settings. The settings will remain even after the server restarts.\n" ..
	"\n" ..
	"* * * End Docs * * *\n"

function chat_controls.compose_formspec(pname)
	local ignore, filter, white, distance, pm, shout =
		chat_controls.get_filters_as_text(pname)

	local chathide = "false"
	local nobeep = "false"
	local nopochide = "false"

	if chat_controls.players[pname] then
		chathide = chat_controls.players[pname].chathide or "false"
		nobeep = chat_controls.players[pname].nobeep or "false"
		nopochide = chat_controls.players[pname].nopochide or "false"
	end

  local formspec = ""
  formspec = formspec .. "size[12,9.5]" ..
    default.gui_bg ..
    default.gui_bg_img ..
    default.gui_slots ..
		"item_image[11,0;1,1;default:paper]" ..

    "label[0,0;Communication Filtering: Control who can send you messages!]" ..
		"field[0.3,1.2;8,1;ignore;" ..
			minetest.formspec_escape("Ignore list: names of players you do not want to see public chat from:") .. ";" ..
			minetest.formspec_escape(ignore) .. "]" ..
		"field[0.3,2.4;8,1;filter;" ..
			minetest.formspec_escape("Highlight list: words or names you want to know about, if mentioned:") .. ";" ..
			minetest.formspec_escape(filter) .. "]" ..
		"field[0.3,3.6;8,1;white;" ..
			minetest.formspec_escape("Whitelist: names of players you want to hear from:") .. ";" ..
			minetest.formspec_escape(white) .. "]" ..
		"field[0.3,5.5;2,1;dist;Distance;" ..
			minetest.formspec_escape(distance) .. "]" ..
		"field[0.3,6.8;8,1;pm;" ..
			minetest.formspec_escape("Ignore PM: names of players you don't want to PM you:") .. ";" ..
			minetest.formspec_escape(pm) .. "]" ..
		"field[0.3,8.0;8,1;shout;" ..
			minetest.formspec_escape("Ignore shout: names of players you don't want to hear shouts from:") .. ";" ..
			minetest.formspec_escape(shout) .. "]" ..
    "button[0,8.8;3,1;apply;Confirm Filters]" ..
    "button[6,8.8;2,1;close;Close]" ..

		"textarea[8.5,0.93;3.8,10.0;info;;" .. minetest.formspec_escape(chat_controls.info) .. "]" ..

		"tooltip[ignore;Separate names with commas. You may use aliases.]" ..
		"tooltip[filter;Separate strings with commas. You may use player-names and aliases.]" ..
		"tooltip[white;Separate names with commas. You may use aliases.]" ..
		"tooltip[dist;Min >= 0, max <= 30000.]" ..

		"checkbox[0,4.2;chathide;Hide chat from non-whitelisted users farther than DISTANCE meters.;" .. chathide .. "]" ..
		"checkbox[2,5.0;nopochide;Mute non-citizens (those not in whitelist).;" .. nopochide .. "]" ..
		"checkbox[3,8.8;nobeep;Disable audio alerts.;" .. nobeep .. "]"

  return formspec
end



-- API function (called from passport mod, for instance).
function chat_controls.show_formspec(pname)
  local formspec = chat_controls.compose_formspec(pname)
  minetest.show_formspec(pname, "chat_controls:main", formspec)
end



function chat_controls.on_receive_fields(player, formname, fields)
  local pname = player:get_player_name()
  if formname ~= "chat_controls:main" then
    return
  end

	if fields.quit then
		return true
	end

	if fields.apply then
		chat_controls.set_lists_from_fields(pname, fields)
		chat_controls.save_lists_for_player(pname)
		chat_controls.show_formspec(pname)
		return true
	end

	if fields.chathide then
		if chat_controls.players[pname] then
			chat_controls.players[pname].chathide = fields.chathide
		end
		-- Clicking the checkbox so far, does the same thing as clicking apply.
		chat_controls.set_lists_from_fields(pname, fields)
		chat_controls.save_lists_for_player(pname)
		chat_controls.show_formspec(pname)
		return true
	end

	if fields.nopochide then
		if chat_controls.players[pname] then
			chat_controls.players[pname].nopochide = fields.nopochide
		end
		-- Clicking the checkbox so far, does the same thing as clicking apply.
		chat_controls.set_lists_from_fields(pname, fields)
		chat_controls.save_lists_for_player(pname)
		chat_controls.show_formspec(pname)
		return true
	end

	if fields.nobeep then
		if chat_controls.players[pname] then
			chat_controls.players[pname].nobeep = fields.nobeep
		end
		-- Clicking the checkbox so far, does the same thing as clicking apply.
		chat_controls.set_lists_from_fields(pname, fields)
		chat_controls.save_lists_for_player(pname)
		chat_controls.show_formspec(pname)
		return true
	end

  if fields.close then
		-- Go back to the KoC control panel.
    passport.show_formspec(pname)
    return true
  end

	return true
end



if not chat_controls.run_once then
	chat_controls.modstorage = minetest.get_mod_storage()

  -- GUI input handler.
  minetest.register_on_player_receive_fields(function(...)
    return chat_controls.on_receive_fields(...)
  end)

	minetest.register_on_joinplayer(function(player)
		return chat_controls.on_joinplayer(player:get_player_name(), player)
	end)

	minetest.register_on_leaveplayer(function(player)
		return chat_controls.on_leaveplayer(player:get_player_name())
	end)

	local c = "chat_controls:core"
	local f = chat_controls.modpath .. "/init.lua"
	reload.register_file(c, f, false)

	chat_controls.run_once = true
end
