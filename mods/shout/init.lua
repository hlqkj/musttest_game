
if not minetest.global_exists("shout") then shout = {} end
shout.modpath = minetest.get_modpath("shout")
shout.worldpath = minetest.get_worldpath()
shout.datafile = shout.worldpath .. "/hints.txt"
shout.players = shout.players or {}

-- Localize for performance.
local math_floor = math.floor
local math_random = math.random



local SHOUT_COLOR = core.get_color_escape_sequence("#ff2a00")
local TEAM_COLOR = core.get_color_escape_sequence("#a8ff00")
local WHITE = core.get_color_escape_sequence("#ffffff")



shout.HINTS = {}
shout.BUILTIN_HINTS = {}

dofile(shout.modpath .. "/builtin_tips.lua")


function shout.hint_add(name, param)
	name = name:trim()
	param = param:trim()
	param = param:gsub("%s+", " ")

	if param:len() == 0 then
		minetest.chat_send_player(name, "# Server: Not adding an empty hint message.")
		return
	end

	minetest.chat_send_player(name, "# Server: Will add hint message: \"" .. param .. "\".")

	-- Will store all hints loaded from file.
	local loaded_hints = {}

	-- Load all hints from world datafile.
	local file, err = io.open(shout.datafile, "r")
	if err then
		minetest.chat_send_player(name, "# Server: Failed to open \"" .. shout.datafile .. "\" for reading: " .. err)
	else
		local datastring = file:read("*all")
		if datastring and datastring ~= "" then
			local records = string.split(datastring, "\n")
			for record_number, record in ipairs(records) do
				local data = record:trim()
				if data:len() > 0 then
					table.insert(loaded_hints, data)
				end
			end
		end
		file:close()
	end

	minetest.chat_send_player(name, "# Server: Loaded " .. #loaded_hints .. " previously saved hints.")

	-- Add the new hint message.
	table.insert(loaded_hints, param)

	-- Custom file format. minetest.serialize() is unusable for large tables.
	local datastring = ""
	for k, record in ipairs(loaded_hints) do
		datastring = datastring .. record .. "\n"
	end

	-- Now save all non-builtin hints back to the file.
	local file, err = io.open(shout.datafile, "w")
	if err then
		minetest.chat_send_player(name, "# Server: Failed to open \"" .. shout.datafile .. "\" for writing: " .. err)
	else
		file:write(datastring)
		file:close()
	end

	-- Recombine both tables.
	shout.HINTS = {}
	for k, v in ipairs(shout.BUILTIN_HINTS) do
		table.insert(shout.HINTS, v)
	end
	for k, v in ipairs(loaded_hints) do
		table.insert(shout.HINTS, v)
	end
end



-- Load any saved hints whenever mod is reloaded or server starts.
do
	-- Will store all hints loaded from file.
	local loaded_hints = {}

	-- Load all hints from world datafile.
	local file, err = io.open(shout.datafile, "r")
	if err then
		if not err:find("No such file") then
			minetest.log("error", "Failed to open " .. shout.datafile .. " for reading: " .. err)
		end
	else
		local datastring = file:read("*all")
		if datastring and datastring ~= "" then
			local records = string.split(datastring, "\n")
			for record_number, record in ipairs(records) do
				local data = record:trim()
				if data:len() > 0 then
					table.insert(loaded_hints, data)
				end
			end
		end
		file:close()
	end

	-- Recombine both tables.
	shout.HINTS = {}
	for k, v in ipairs(shout.BUILTIN_HINTS) do
		table.insert(shout.HINTS, v)
	end
	for k, v in ipairs(loaded_hints) do
		table.insert(shout.HINTS, v)
	end
end



local function get_non_admin_players()
	local t = minetest.get_connected_players()
	local b = {}
	for k, v in ipairs(t) do
		if not minetest.check_player_privs(v, "server") then
			b[#b + 1] = v
		end
	end
	return b
end



local HINT_DELAY_MIN = 60*45
local HINT_DELAY_MAX = 60*90

function shout.print_hint()
	local HINTS = shout.HINTS

	-- Only if hints are available.
	if #HINTS > 0 then
		-- Don't speak to an empty room.
		local players = get_non_admin_players()
		if #players > 0 then
			minetest.chat_send_all("# Server: " .. HINTS[math_random(1, #HINTS)])
		end
	end

	-- Print another hint after some delay.
	minetest.after(math_random(HINT_DELAY_MIN, HINT_DELAY_MAX), function() shout.print_hint() end)
end



-- Shout a message.
function shout.shout(name, param)
	param = string.trim(param)
	if #param < 1 then
		minetest.chat_send_player(name, "# Server: No message specified.")
		easyvend.sound_error(name)
		return
	end

	if command_tokens.mute.player_muted(name) then
		minetest.chat_send_player(name, "# Server: You cannot shout while gagged!")
		easyvend.sound_error(name)
		return
	end

	-- If this succeeds, the player was either kicked, or muted and a message about that sent to everyone else.
	if chat_core.check_language(name, param) then return end

	local mk = chat_core.generate_coord_string(name)
	local stats = chat_core.player_status(name)
	local dname = rename.gpn(name)
	local players = minetest.get_connected_players()

	for _, player in ipairs(players) do
		local target_name = player:get_player_name() or ""
		if not chat_controls.player_ignored_shout(target_name, name) or target_name == name then
			chat_core.alert_player_sound(target_name)
			minetest.chat_send_player(target_name, stats .. "<!" .. chat_core.nametag_color .. dname .. WHITE .. mk .. "!> " .. SHOUT_COLOR .. param)
		end
	end

	afk.reset_timeout(name)
	chat_logging.log_public_shout(name, stats, param, mk)
end



-- Get player's current "in-memory" channel name, or nil.
function shout.player_channel(pname)
	if shout.players[pname] and shout.players[pname] ~= "" then
		return shout.players[pname]
	end
end



-- Get list of all players in a channel.
function shout.channel_players(channel)
	local players = minetest.get_connected_players()
	local result = {}
	for k, v in ipairs(players) do
		local n = v:get_player_name()
		if shout.players[n] and shout.players[n] == channel then
			result[#result+1] = n
		end
	end
	return result
end



-- Use this only to send server messages to all players in a channel.
-- This bypasses players' chat filters.
function shout.notify_channel(channel, message)
	local players = minetest.get_connected_players()

	-- Send message to all players in the same channel.
	for k, v in ipairs(players) do
		local n = v:get_player_name()
		if shout.players[n] and shout.players[n] == channel then
			minetest.chat_send_player(n, TEAM_COLOR .. message)
		end
	end
end



-- let player join, leave channels
function shout.channel(name, param, on_join, on_leave)
	param = string.trim(param)
	local player = minetest.get_player_by_name(name)
	if not player or not player:is_player() then
		return
	end

	if shout.players[name] and shout.players[name] ~= "" and param ~= shout.players[name] then
		shout.notify_channel(shout.players[name],
			"# Server: User <" .. rename.gpn(name) .. "> has left channel '" ..
			shout.players[name] .. "'.")
	end

	if param == "" then
		if not on_join then
			if shout.players[name] then
				minetest.chat_send_player(name, "# Server: Channel cleared.")
			else
				minetest.chat_send_player(name, "# Server: Not on any channel.")
			end
		end

		shout.players[name] = nil
		if not on_leave then
			player:get_meta():set_string("active_channel", "")
		end
		return
	end

	if not on_join then
		if shout.players[name] and shout.players[name] == param then
			minetest.chat_send_player(name,
				"# Server: Already on channel '" .. param .. "'.")
			return
		end
	end

	-- Require channel names to match specific format.
	if not string.find(param, "^[_%w]+$") then
		minetest.chat_send_player(name,
			"# Server: Invalid channel name! Use only alphanumeric characters and underscores.")
		easyvend.sound_error(name)
		return
	end

	-- Only print this if called by explicit chatcommand.
	if not on_join then
		minetest.chat_send_player(name, "# Server: Chat channel set to '" .. param .. "'.")
	end

	shout.players[name] = param
	player:get_meta():set_string("active_channel", param)
	shout.notify_channel(shout.players[name],
		"# Server: User <" .. rename.gpn(name) .. "> has joined channel '" ..
		shout.players[name] .. "'.")
end



-- let player put a message onto a channel
function shout.x(name, param)
	param = string.trim(param)
	if not shout.players[name] then
		minetest.chat_send_player(name, "# Server: You have not specified a channel.")
		easyvend.sound_error(name)
		return
	end

	if #param < 1 then
		minetest.chat_send_player(name, "# Server: No message specified.")
		easyvend.sound_error(name)
		return
	end

	-- Allow player to use channel speak even while gagged.
	-- Rational: if the gagged player is on a channel with others,
	-- then probably they're in a group together, or are related.
	-- Chat between such shouldn't be blocked.
	--[[
	if command_tokens.mute.player_muted(name) then
		minetest.chat_send_player(name, "# Server: You cannot talk while gagged!")
		easyvend.sound_error(name)
		return
	end
	--]]

	local stats = chat_core.player_status(name)
	local dname = rename.gpn(name)
	local channel = shout.players[name]
	local players = minetest.get_connected_players()

	-- If this succeeds, the player was either kicked, or muted and a message about that sent to everyone else.
	if chat_core.check_language(name, param, channel) then return end

	local mk = chat_core.generate_coord_string(name)

	-- Send message to all players in the same channel.
	-- The player who sent the message always receives it.
	for k, v in ipairs(players) do
		local n = v:get_player_name()
		if shout.players[n] and shout.players[n] == channel then
			local ignored = false

			-- Don't send teamchat if player is ignored.
			if chat_controls.player_ignored(n, name) then
				ignored = true
			end

			if not ignored then
				minetest.chat_send_player(n, stats .. "<!" .. chat_core.nametag_color .. rename.gpn(name) .. WHITE .. mk .. "!> " .. TEAM_COLOR .. param)
			end
		end
	end

	--minetest.chat_send_all(SHOUT_COLOR .. "<!" .. dname .. mk .. "!> " .. param)
	--chat_logging.log_public_shout(name, param, shout.channelmk)

	chat_logging.log_team_chat(name, stats, param, channel)
	afk.reset_timeout(name)
end



-- Join channel on login, if no channel currently set.
function shout.join_channel(player)
	local pname = player:get_player_name()
	if not shout.player_channel(pname) then
		local channel = player:get_meta():get_string("active_channel")
		if channel and channel ~= "" then
			minetest.after(0, function() shout.channel(pname, channel, true) end)
		end
	end
end



-- Leave channel on logout, if a channel is currently set.
function shout.leave_channel(player)
	local pname = player:get_player_name()
	local curchan = shout.player_channel(pname)
	if curchan and curchan ~= "" then
		shout.channel(pname, "", false, true)
	end
end



if not shout.run_once then
	-- Post 'startup complete' message only in multiplayer.
	if not minetest.is_singleplayer() then
		minetest.after(0, function()
			minetest.chat_send_all("# Server: Startup complete.")
		end)
	end

	minetest.register_chatcommand("shout", {
		params = "<message>",
		description = "Yell a message to everyone on the server. You can also prepend your chat with '!'.",
		privs = {shout=true},
		func = function(name, param)
			shout.shout(name, param)
			return true
		end,
	})

	minetest.register_chatcommand("channel", {
		params = "<id>",
		description = "Set channel name.",
		privs = {shout=true},
		func = function(name, param)
			shout.channel(name, param)
			return true
		end,
	})

	minetest.register_chatcommand("x", {
		params = "<message>",
		description = "Speak on current channel.",
		privs = {shout=true},
		func = function(name, param)
			shout.x(name, param)
			return true
		end,
	})

	minetest.register_chatcommand("hint_add", {
		params = "<message>",
		description = "Add a hint message to the hint list. Example between quotes: '/hint_add This is a hint message. Another sentance.'",
		privs = {server=true},
		func = function(name, param)
			shout.hint_add(name, param)
			return true
		end,
	})

	-- Start hints. A hint is written into public chat every so often.
	-- But not too often, or it becomes annoying.
	minetest.after(math_random(HINT_DELAY_MIN, HINT_DELAY_MAX), function() shout.print_hint() end)

	minetest.register_on_joinplayer(function(...)
		return shout.join_channel(...) end)

	minetest.register_on_leaveplayer(function(...)
		return shout.leave_channel(...) end)

	local c = "shout:core"
	local f = shout.modpath .. "/init.lua"
	reload.register_file(c, f, false)

	shout.run_once = true
end
