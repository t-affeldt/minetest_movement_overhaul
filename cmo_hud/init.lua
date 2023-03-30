local MODPATH = minetest.get_modpath(minetest.get_current_modname())

if minetest.settings:get_bool("cmo_hud.show_cooldown ", true) then
    dofile(MODPATH .. DIR_DELIM .. "cooldown.lua")
end

dofile(MODPATH .. DIR_DELIM .. "hudbars.lua")

if minetest.settings:get_bool("cmo_hud.display_damage", true) then
    dofile(MODPATH .. DIR_DELIM .. "damage_numbers.lua")
end