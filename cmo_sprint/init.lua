if cmo == nil then cmo = {} end
local MODPATH = minetest.get_modpath(minetest.get_current_modname())

local mod_mcl_sprint = minetest.get_modpath("mod_mcl_sprint") ~= nil
if mod_mcl_sprint then
    dofile(MODPATH .. DIR_DELIM .. "compatibility" .. DIR_DELIM .. "mcl_sprint.lua")
end

local SPRINT_SPEED_BOOST = 1.4
local SPRINT_JUMP_BOOST = 1.3
local SPRINT_STAMINA_COST = 10

cmo.sprint = {}

-- override this for custom requirements
cmo.sprint.allow_sprint = function(player)
    local playername = player:get_player_name()
    if not cmo._is_grounded(player) then
        return false
    end
    local stamina = cmo.stamina.get(playername)
    local cycle = math.max(cmo.stamina.UPDATE_CYCLE, 0.1)
    if stamina < SPRINT_STAMINA_COST * cycle then
        return false
    end
    return true
end

local sprinting_players = {}

local function ready_sprint(player)
    if not cmo.sprint.allow_sprint(player) then return end
    local playername = player:get_player_name()
    sprinting_players[playername] = true
    player_monoids.speed:add_change(player, SPRINT_SPEED_BOOST, "cmo_sprint:sprint_boost")
    player_monoids.jump:add_change(player, SPRINT_JUMP_BOOST, "cmo_sprint:sprint_boost")
end

local function stop_sprint(player)
    local playername = player:get_player_name()
    sprinting_players[playername] = nil
    player_monoids.speed:del_change(player, "cmo_sprint:sprint_boost")
    player_monoids.jump:del_change(player, "cmo_sprint:sprint_boost")
end

local function do_sprint(player, dtime)
    local playername = player:get_player_name()
    if not sprinting_players[playername] then
        ready_sprint(player)
    end
    local remaining = cmo.stamina.add(playername, -SPRINT_STAMINA_COST * dtime)
    if remaining <= 0 then
        stop_sprint(player)
    end
end

--[[minetest.register_on_joinplayer(function(player)
    --if not player then return end
    minetest.after(2, function()
        player_monoids.speed:add_change(player, 0, "stop_movement" )
        player:add_velocity(vector.new({ x = 10, y = 0, z = 0 }))
    end)
end)]]