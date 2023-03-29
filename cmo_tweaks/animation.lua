local walk_speed = tonumber(minetest.settings:get("movement_speed_walk") or 4)
local sneak_speed = tonumber(minetest.settings:get("movement_speed_crouch") or 1.35)

local AIR_PUNCH_TIME = 0.1
local punching_players = {}

local function may_punch(player, time)
    local playername = player:get_player_name()
    local pointed_thing = cmo._get_pointed_thing(player)
    if pointed_thing.type == "node" then
        return true
    end
    if punching_players[playername] == nil then
        punching_players[playername] = time
        return true
    else
        return (time - punching_players[playername]) <= AIR_PUNCH_TIME
    end
end

function cmo.determine_animation(player, model, time)
    local playername = player:get_player_name()
    local controls = player:get_player_control()
    local physics = player:get_physics_override()
    local player_speed = physics.speed or 1
    local animation_speed_mod = model.animation_speed or 30

    animation_speed_mod = animation_speed_mod * player_speed

    if controls.sneak then
        animation_speed_mod = animation_speed_mod * sneak_speed / walk_speed
    end

    if player:get_hp() == 0 then
        punching_players[playername] = nil
        return "lay"
    elseif controls.up or controls.down or controls.left or controls.right then
        if controls.LMB or controls.RMB then
            if may_punch(player, time) then
                return "walk_mine", animation_speed_mod
            else
                return "walk", animation_speed_mod
            end
        else
            punching_players[playername] = nil
            return "walk", animation_speed_mod
        end
    elseif controls.LMB or controls.RMB then
        if may_punch(player, time) then
            return "mine"
        else
            return "stand", animation_speed_mod
        end
    else
        punching_players[playername] = nil
        return "stand"
    end
end

local time = 0
player_api.globalstep = function(dtime)
    time = time + dtime
    local players = minetest.get_connected_players()
    for _, player in ipairs(players) do
        local name = player:get_player_name()
        local data = player_api.get_animation(player)
        local model = data and player_api.registered_models[data.model]
        if model and not player_api.player_attached[name] then
            local animation, speed = cmo.determine_animation(player, model, time)
            if animation ~= nil then
                player_api.set_animation(player, animation, speed)
            end
        end
    end
end

minetest.register_on_joinplayer(function(player)
    local data = player_api.get_animation(player)
    local model = data and player_api.registered_models[data.model]
    local speed = (model and model.animation_speed) or 30
	player:set_local_animation({}, {}, {}, {}, speed)
end)