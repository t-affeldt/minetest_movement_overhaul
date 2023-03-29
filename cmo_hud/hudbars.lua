local mod_hudbars = minetest.get_modpath("hudbars") ~= nil
local mod_mana = mod_hudbars and minetest.get_modpath("mana") ~= nil
local mod_hbhunger = mod_hudbars and minetest.get_modpath("hbhunger") ~= nil
local mod_mcl_hunger = mod_hudbars and minetest.get_modpath("mcl_hunger") ~= nil

local enable_damage = minetest.settings:get_bool("enable_damage")
local HIDE_HUNGER = minetest.settings:get_bool("cmo_hud.autohide_hunger", true)
local HIDE_MANA = minetest.settings:get_bool("cmo_hud.autohide_mana", true)

local bars = {}
local CYCLE_SPEED = 1

if HIDE_HUNGER and mod_hbhunger and enable_damage then
    table.insert(bars, "satiation")
end

if HIDE_HUNGER and mod_mcl_hunger and mcl_hunger.active then
    table.insert(bars, "hunger")
end

if HIDE_MANA and mod_mana then
    table.insert(bars, "mana")
end

local function autotoggle_bars()
    local players = minetest.get_connected_players()
    for _, player in ipairs(players) do
        for _, bar in ipairs(bars) do
            local state = hb.get_hudbar_state(player, bar)
            if state.value == state.max then
                hb.hide_hudbar(player, bar)
            else
                hb.unhide_hudbar(player, bar)
            end
        end
    end
end

local timer = 0
if #bars > 0 then
    minetest.register_globalstep(function(dtime)
        timer = timer + dtime
        if timer < CYCLE_SPEED then return end
        timer = 0
        autotoggle_bars()
    end)
end