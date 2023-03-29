if cmo == nil then cmo = {} end
local MODPATH = minetest.get_modpath(minetest.get_current_modname())
local mod_hudbars = minetest.get_modpath("hudbars") ~= nil

local HUNGER_CONSUMPTION = tonumber(minetest.settings:get("cmo_stamina.hunger_consumption") or 0.1)

cmo.stamina = {}
cmo.stamina.REGEN_RATE_DEFAULT = 0.05
cmo.stamina.UPDATE_CYCLE = 0.2

local deduct_hunger = dofile(MODPATH .. DIR_DELIM .. "hunger.lua")

-- override this for custom conditions
function cmo.stamina.regen_rate(playername, dtime)
    return cmo.stamina.REGEN_RATE_DEFAULT * dtime
end

function cmo.stamina.set(playername, value)
    local player = minetest.get_player_by_name(playername)
    if not player or not player:is_player() then
        return -1
    end
    local meta = player:get_meta()
    local current = meta:get_float("cmo_sprint:stamina")
    local override = math.max(math.min(value, 1), 0)
    meta:set_float("cmo_sprint:stamina", override)
    cmo.stamina._update_bar(player, override)
    if override < current then
        deduct_hunger(player, (current - override) * HUNGER_CONSUMPTION)
    end
    return value
end

function cmo.stamina.get(playername)
    local player = minetest.get_player_by_name(playername)
    if not player or not player:is_player() then
        return -1
    end
    local meta = player:get_meta()
    return meta:get_float("cmo_sprint:stamina")
end

function cmo.stamina.add(playername, value)
    local player = minetest.get_player_by_name(playername)
    if not player or not player:is_player() then
        return -1
    end
    local meta = player:get_meta()
    local current = meta:get_float("cmo_sprint:stamina")
    local override = math.max(math.min(current + value, 1), 0)
    meta:set_float("cmo_sprint:stamina", override)
    cmo.stamina._update_bar(player, override)
    if override < current then
        deduct_hunger(player, (current - override) * HUNGER_CONSUMPTION)
    end
    return override
end

if mod_hudbars then
    dofile(MODPATH .. DIR_DELIM .. "hudbars.lua")
end

-- passively regenerate stamina
local timer = 0
minetest.register_globalstep(function(dtime)
    -- skip if not enough time has passed
    timer = timer + dtime
    if timer < cmo.stamina.UPDATE_CYCLE then return end

    local playerlist = minetest.get_connected_players()
    for _, player in pairs(playerlist) do
        local name = player:get_player_name()
        local stamina_regen = cmo.stamina.regen_rate(name, timer)
        if stamina_regen ~= 0 then
            cmo.stamina.add(name, stamina_regen)
        end
    end

    timer = 0
end)

-- reset stamina bar upon respawn
minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if reason ~= "respawn" then return end
    local playername = player:get_player_name()
    cmo.stamina.set(playername, 1)
end, false)