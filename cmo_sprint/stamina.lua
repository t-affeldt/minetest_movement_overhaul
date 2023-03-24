local CYCLE_LENGTH = 1

local REGEN_RATE = 0.1

cmo.stamina = {}

-- override this for custom conditions
cmo.regen_rate = function(playername, dtime)
    return REGEN_RATE * dtime
end

cmo.stamina.set = function(playername, value)
    local player = minetest.get_player_by_name(playername)
    if not player or not player:is_player() then
        return -1
    end
    local meta = player:get_meta()
    value = math.max(math.min(value, 1), 0)
    meta:set_float("cmo_sprint:stamina", value)
    return value
end

cmo.stamina.get = function(playername)
    local player = minetest.get_player_by_name(playername)
    if not player or not player:is_player() then
        return -1
    end
    local meta = player:get_meta()
    return meta:get_float("cmo_sprint:stamina")
end

cmo.stamina.add = function(playername, value)
    local player = minetest.get_player_by_name(playername)
    if not player or not player:is_player() then
        return -1
    end
    local meta = player:get_meta()
    local current = meta:get_float("cmo_sprint:stamina")
    local override = math.max(math.min(current + value, 1), 0)
    meta:set_float("cmo_sprint:stamina", override)
    return override
end

-- passively regenerate stamina
local timer = 0
minetest.register_globalstep(function(dtime)
    -- skip if not enough time has passed
    timer = timer + dtime
    if timer < CYCLE_LENGTH then return end

    local playerlist = minetest.get_connected_players()
    for _, player in pairs(playerlist) do
        local name = player:get_player_name()
        local stamina_regen = cmo.regen_rate(name, dtime)
        if stamina_regen ~= 0 then
            cmo.stamina.add(name, stamina_regen)
        end
    end

    timer = 0
end)

-- reset stamina bar upon respawn
minetest.register_on_player_hp_change(function(player, hp_change, reason)
    if reason ~= "respawn" then return end
    local playername = player:get_player_name()
    cmo.stamina.set(playername, 1)
end, false)