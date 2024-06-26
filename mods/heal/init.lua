
if not minetest.global_exists("heal") then heal = {} end
heal.modpath = minetest.get_modpath("heal")



minetest.register_privilege("heal", {
  description = "Player can heal other players or themselves.",
  give_to_singleplayer = false,
})



-- API function, can be called by other mods.
function heal.heal_health_and_hunger(pname)
  local player = minetest.get_player_by_name(pname)
  if not player then return end

  local was_dead = false
  if player:get_hp() == 0 then
    was_dead = true
  end

  local hp_max = pova.get_active_modifier(player, "properties").hp_max
  player:set_hp(hp_max, {reason="heal_command"})
  hunger.update_hunger(player, 30)
	sprint.set_stamina(player, SPRINT_STAMINA)
	portal_sickness.reset(pname)
	bones.nohack.on_respawnplayer(player)

	if was_dead then
    minetest.close_formspec(pname, "")
  end
end



minetest.register_chatcommand("heal", {
  params = "[playername]",
  description = "Heal specified player, or heal self if called without arguments.",
  privs = {heal=true},
  func = function(name, param)
    if param == nil or param == "" then
      minetest.chat_send_player(name, "# Server: Healing player <" .. rename.gpn(name) .. ">.")
      heal.heal_health_and_hunger(name)
      return true
    end
    
    assert(type(param) == "string")
    local player = minetest.get_player_by_name(param)
    if not player then
      minetest.chat_send_player(name, "# Server: Player <" .. rename.gpn(param) .. "> not found.")
      return false
    end
    
    minetest.chat_send_player(name, "# Server: Healing player <" .. rename.gpn(param) .. ">.")
    minetest.chat_send_player(param, "# Server: Player <" .. rename.gpn(name) .. "> healed you.")
    heal.heal_health_and_hunger(param)
    return true
  end
})
