if cmo == nil then cmo = {} end
local MODPATH = minetest.get_modpath(minetest.get_current_modname())

if not minetest.settings:get_bool("cmo_sprint.enabled", true) then return end

local mod_mcl_sprint = minetest.get_modpath("mcl_sprint") ~= nil
if mod_mcl_sprint then
    dofile(MODPATH .. DIR_DELIM .. "compatibility" .. DIR_DELIM .. "mcl_sprint.lua")
end

local SLIDING_ENABLED = minetest.settings:get_bool("cmo_sprint.sliding_enabled", true)
local MAX_SPEED = tonumber(minetest.settings:get("cmo_sprint.max_speed") or 15)
local SPRINT_STAMINA_COST = tonumber(minetest.settings:get("cmo_sprint.stamina_cost") or 0.05)

local SPRINT_BOOST = 20
local MOVEMENT_CONTROL = 0.5
local SPRINT_JUMP_BOOST = 0.5
local RECOVERY_TIME = 0.5
local SLIDE_TIME = 2
local ANIMATION_SPEED = 1.5

local CYCLE_LENGTH = 0.2

cmo.sprint = {}

-- override this for custom requirements
cmo.sprint.allow_sprint = function(player)
    local playername = player:get_player_name()
    if player:get_attach() ~= nil or not cmo._is_grounded(player) then
        return false
    end
    local stamina = cmo.stamina.get(playername)
    local cycle = math.max(cmo.stamina.UPDATE_CYCLE, CYCLE_LENGTH, 0.1)
    if stamina < SPRINT_STAMINA_COST * cycle then
        return false
    end
    return true
end

local sprinting_players = {}
local stopping_players = {}

local directions = {
    up = { z = 1 },
    down = { z = -1 },
    left = { x = -1 },
    right = { x = 1 }
}

local stamina_regen = cmo.stamina.regen_rate
cmo.stamina.regen_rate = function(playername, ...)
    if sprinting_players[playername] or stopping_players[playername] then
        return 0
    end
    return stamina_regen(playername, ...)
end

local determine_animation = cmo.determine_animation
if cmo.determine_animation ~= nil then
    cmo.determine_animation = function(player, ...)
        local name = player:get_player_name()
        local anim, speed = determine_animation(player, ...)
        if anim == "walk" or anim == "walk_mine" then
            if sprinting_players[name] and speed ~= nil then
                speed = speed * (1 / MOVEMENT_CONTROL) * ANIMATION_SPEED
            elseif stopping_players[name] then
                if speed ~= nil then
                    speed = speed * (1 / MOVEMENT_CONTROL)
                end
                if anim == "walk" then
                    anim = "stand"
                else
                    anim = "mine"
                end
            end
        end
        return anim, speed
    end
end

local function ready_sprint(player)
    if not cmo.sprint.allow_sprint(player) then return end
    local playername = player:get_player_name()
    if stopping_players[playername] then return end
    sprinting_players[playername] = true
    -- remove walking speed modifiers
    if cmo.purge_base_modifiers ~= nil then
        cmo.purge_base_modifiers(player)
    end
    cmo.stamina.highlight_bar(player, true)
    player_monoids.speed:add_change(player, MOVEMENT_CONTROL, "cmo_sprint:sprint_boost")
end

local function stop_sprint(player, time_offset)
    local playername = player:get_player_name()
    sprinting_players[playername] = nil
    stopping_players[playername] = true
    minetest.after(time_offset, function()
        -- reapply walking speed modifiers
        if cmo.apply_base_modifiers ~= nil then
            cmo.apply_base_modifiers(player)
        end
        cmo.stamina.highlight_bar(player, false)
        player_monoids.speed:del_change(player, "cmo_sprint:sprint_boost")
        player_monoids.jump:del_change(player, "cmo_sprint:sprint_boost")
        stopping_players[playername] = nil
    end)
end

local function do_sprint(player, controls, dtime)
    local playername = player:get_player_name()
    if not sprinting_players[playername] then
        ready_sprint(player)
    end
    local remaining = cmo.stamina.add(playername, -SPRINT_STAMINA_COST * dtime)
    if remaining <= 0 then
        stop_sprint(player, RECOVERY_TIME)
        return
    end
    if not cmo._is_grounded(player) then
        return
    end
    -- initiate slide when tapping sneak key
    if SLIDING_ENABLED and controls.sneak then
        player_monoids.speed:add_change(player, 0.1, "cmo_sprint:sprint_boost")
        player_monoids.jump:add_change(player, 0, "cmo_sprint:sprint_boost")
        stop_sprint(player, SLIDE_TIME)
    end
    local movement = vector.new({ x = 0, y = 0, z = 0 })
    for key, dir in pairs(directions) do
        if controls[key] then
            for direction, val in pairs(dir) do
                movement[direction] = movement[direction] + val
            end
        end
    end
    local velocity = player:get_velocity()
    velocity.y = 0 -- ignore vertical speed
    local speed = vector.length(velocity) / MAX_SPEED
    local speed_boost = math.min((1 - speed) * MAX_SPEED, SPRINT_BOOST * dtime)
    movement = vector.normalize(movement)
    movement = cmo.get_absolute_vector(movement, player:get_look_horizontal())
    movement = vector.multiply(movement, speed_boost)
    local new_speed = vector.length(velocity + movement) / MAX_SPEED
    player_monoids.jump:add_change(player, 1 + ((new_speed^2) * SPRINT_JUMP_BOOST), "cmo_sprint:sprint_boost")
    player:add_velocity(movement)
end

local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < CYCLE_LENGTH then return end
    for _, player in ipairs(minetest.get_connected_players()) do
        local controls = player:get_player_control()
        local playername = player:get_player_name()
        if sprinting_players[playername] == nil
        and controls.up and controls.left and controls.right then
            ready_sprint(player)
        end
        if sprinting_players[playername] then
            if controls.up then
                do_sprint(player, controls, timer)
            else
                stop_sprint(player, RECOVERY_TIME)
            end
        end
    end
    timer = 0
end)

minetest.register_on_leaveplayer(function(player)
    local playername = player:get_player_name()
    sprinting_players[playername] = nil
    stopping_players[playername] = nil
end)
