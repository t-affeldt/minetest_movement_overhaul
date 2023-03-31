if cmo == nil then cmo = {} end

if not minetest.settings:get_bool("cmo_sprint.enabled", true) then return end

local SLIDING_ENABLED = minetest.settings:get_bool("cmo_sprint.sliding_enabled", true)
local MAX_SPEED = tonumber(minetest.settings:get("cmo_sprint.max_speed") or 15)
local SPRINT_STAMINA_COST = tonumber(minetest.settings:get("cmo_sprint.stamina_cost") or 0.05)
local SPRINT_PARTICLES = tonumber(minetest.settings:get("cmo_sprint.particles") or 20)

local SPRINT_BOOST = 18
local MOVEMENT_CONTROL = 0.5
local SPRINT_JUMP_BOOST = 0.4
local RECOVERY_TIME = 0.5
local RECOVERY_STAMINA_COST = 0.5
local SLIDE_TIME = 2
local ANIMATION_SPEED = 1.5
local SLIDE_THRESHOLD = 1

local CYCLE_LENGTH = 0.2

local sprinting_players = {}
local stopping_players = {}
local particle_spawners = {}
local particle_node = {}

cmo.sprint = {}

-- override this for custom requirements
cmo.sprint.allow_sprint = function(player)
    local playername = player:get_player_name()
    -- prevent if attached to something
    if player:get_attach() ~= nil then
        return false
    end
    -- prevent if sneaking
    local controls = player:get_player_control()
    if controls.sneak then
        return false
    end
    -- prevent if low on stamina
    local stamina = cmo.stamina.get(playername)
    local cycle = math.max(cmo.stamina.UPDATE_CYCLE, CYCLE_LENGTH, 0.1)
    if stamina < SPRINT_STAMINA_COST * cycle then
        return false
    end
    return true
end

function cmo.is_sprinting(playername)
    return sprinting_players[playername] or stopping_players[playername] or false
end

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
    cmo.stamina.highlight_bar(player, true)
    player_monoids.speed:add_change(player, MOVEMENT_CONTROL, "cmo_sprint:sprint_boost")
end

local function resolve_sprint_stop(player)
    local playername = player:get_player_name()
    stopping_players[playername] = nil
    cmo.stamina.highlight_bar(player, false)
    player_monoids.speed:del_change(player, "cmo_sprint:sprint_boost")
    player_monoids.jump:del_change(player, "cmo_sprint:sprint_boost")
    stopping_players[playername] = nil
    if particle_spawners[playername] ~= nil then
        minetest.delete_particlespawner(particle_spawners[playername])
        particle_spawners[playername] = nil
        particle_node[playername] = nil
    end
end

local function stop_sprint(player, time_offset)
    local playername = player:get_player_name()
    sprinting_players[playername] = nil
    -- deduct stamina for remaining time
    unified_stamina.add(playername, -SPRINT_STAMINA_COST * time_offset * RECOVERY_STAMINA_COST)
    -- allow for short period of sliding
    stopping_players[playername] = minetest.after(time_offset, resolve_sprint_stop, player)
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

local function spawn_particles(player)
    if SPRINT_PARTICLES <= 0 then return end
    local name = player:get_player_name()
    local pos = player:get_pos()
    pos.y = pos.y - 0.01
    local node = minetest.get_node_or_nil(pos)
    local nodename = node and node.name
    local nodedef = node and minetest.registered_nodes[nodename]
    if not nodedef or nodedef.drawtype ~= "normal" or not nodedef.walkable then
        nodename = nil
    end
    if nodename == particle_node[name] then return end
    particle_node[name] = nodename
    if particle_spawners[name] ~= nil then
        minetest.delete_particlespawner(particle_spawners[name])
    end
    if nodename == nil then return end
    particle_spawners[name] = minetest.add_particlespawner({
        attached = player,
        amount = SPRINT_PARTICLES,
        time = 0,
        node = node,
        size = 1,
        pos = { x = 0, y = 0.1, z = 0 },
        radius = { x = 0.3, y = 0, z = 0.3 },
        vel = { x = 0, y = 0, z = 0 },
        exptime = 0.5
    })
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
        if sprinting_players[playername] or stopping_players[playername] then
            spawn_particles(player)
        end
        if stopping_players[playername] then
            local speed = player:get_velocity()
            speed.y = 0
            if vector.length(speed) < SLIDE_THRESHOLD then
                stopping_players[playername]:cancel()
                resolve_sprint_stop(player)
            end
        end
    end
    timer = 0
end)

minetest.register_on_leaveplayer(function(player)
    local playername = player:get_player_name()
    sprinting_players[playername] = nil
    stopping_players[playername] = nil
    particle_spawners[playername] = nil
    particle_node[playername] = nil
end)
