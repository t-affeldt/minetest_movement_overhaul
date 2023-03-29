if not minetest.settings:get_bool("cmo_dodge.enabled", true) then return end

local mod_hud_timers = minetest.get_modpath("hud_timers") ~= nil

local MAX_KEY_TIME = 0.8
local INVULNERABILTY_TIME = 1
local PUNCH_DELAY = 1

local DELAY_DAMAGE = minetest.settings:get_bool("cmo_dodge.delay_damage", true)
local STAMINA_COST = tonumber(minetest.settings:get("cmo_dodge.stamina_cost") or 0.2)
local SPEED_BOOST = tonumber(minetest.settings:get("cmo_dodge.speed_boost") or 20)
local DODGE_PARTICLES = tonumber(minetest.settings:get("cmo_dodge.particles") or 20)

if DELAY_DAMAGE then
    -- delay PvP punch damage until after animation
    minetest.after(0, function() -- ensure this gets called last
        minetest.register_on_player_hpchange(function(player, hp_change, reason)
            if hp_change >= 0 or reason.type ~= "punch" then
                return hp_change
            end
            if reason.object == nil or not reason.object:is_player() then
                return hp_change
            end
            minetest.after(PUNCH_DELAY, function()
                local health = player:get_hp() + hp_change
                player:set_hp(health, {
                    type = "set_hp",
                    subtype = "punch_delay",
                    object = reason.object
                })
            end)
            return 0, true
        end, true)
    end)
end

local directions = {
    left = vector.new({ x = -1, y = 0, z = 0 }),
    right = vector.new({ x = 1, y = 0, z = 0 }),
    up = vector.new({ x = 0, y = 0, z = 1 }),
    down = vector.new({ x = 0, y = 0, z = -1 })
}

local players = {}

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if reason.type ~= "punch" and reason.type ~= "set_hp" then return hp_change end
    if reason.type == "set_hp" and reason.subtype ~= "punch_delay" then return hp_change end
    local name = player:get_player_name()
    if players[name] ~= nil and players[name].state == "active" then
        return 0, true
    end
    return hp_change
end, true)

local function post_hook(player, properties_before)
    local playername = player:get_player_name()
    players[playername] = nil
    local properties = player:get_properties()
    for property, value in pairs(properties_before) do
        properties[property] = value
    end
    player:set_properties(properties)
end

local function perform_dodge(player, control_name)
    local playername = player:get_player_name()
    local stamina = unified_stamina.get(playername)
    -- cancel if insufficient stamina
    if stamina < STAMINA_COST then
        minetest.sound_play({ name = "cmo_dodge_fail", gain = 2 }, { to_player = playername }, true)
        players[playername] = nil
        return
    end
    -- cancel if in the air
    if not cmo._is_grounded(player) then
        minetest.sound_play({ name = "cmo_dodge_fail", gain = 2 }, { to_player = playername }, true)
        players[playername] = nil
        return
    end
    -- apply velocity bonus
    local lookdir = player:get_look_horizontal()
    local direction = cmo.get_absolute_vector(directions[control_name], lookdir)
    -- add speed boost into chosen direction
    local movement_speed = math.min((player:get_physics_override()).speed or 1, 1)
    local velocity = vector.multiply(direction, SPEED_BOOST * movement_speed)
    player:add_velocity(velocity)
    -- reduce stamina
    unified_stamina.add(playername, -STAMINA_COST)
    -- set indicator for invulnerability timer
    if mod_hud_timers then
        hud_timers.add_timer(playername, {
            name = "Dodge Evasion",
            color = "5daf99",
            duration = INVULNERABILTY_TIME,
            rounding_steps = 10
        })
    end
    -- spawn particles
    if DODGE_PARTICLES > 0 then
        local pos = player:get_pos()
        pos.y = pos.y - 0.01
        local node = minetest.get_node_or_nil(pos)
        local nodedef = node and minetest.registered_nodes[node.name]
        if nodedef and nodedef.drawtype == "normal" and nodedef.walkable then
            minetest.add_particlespawner({
                attached = player,
                amount = DODGE_PARTICLES * INVULNERABILTY_TIME,
                time = INVULNERABILTY_TIME,
                node = node,
                size = 1,
                pos = { x = 0, y = 0.1, z = 0 },
                radius = { x = 0.3, y = 0, z = 0.3 },
                vel = { x = 0, y = 0, z = 0 },
                exptime = 0.5
            })
        end
    end
    -- modify player properties during the dodge
    local properties = player:get_properties()
    local properties_before = {}
    properties_before.pointable = properties.pointable
    properties_before.collide_with_objects = properties.collide_with_objects
    properties.pointable = false
    properties.collide_with_objects = false
    player:set_properties(properties)
    -- reset player properties after some time
    minetest.after(INVULNERABILTY_TIME, function()
        if not player then return end
        post_hook(player, properties_before)
    end)
    -- play sound
    minetest.sound_play({ name = "cmo_dodge_perform" }, { to_player = playername }, true)
end

-- detect touble-tap of direction keys
controls.register_on_press(function(player, control_name)
    if not directions[control_name] then return end
    if not player or player:get_attach() ~= nil then return end
    local name = player:get_player_name()
    local last_press = players[name]
    if last_press and last_press.state == "active" then return end
    -- check whether second tap was timely
    local time = minetest.get_gametime()
    local timely = last_press and time - last_press.time <= MAX_KEY_TIME
    -- store first key tap
    if last_press == nil or last_press.key ~= control_name or not timely then
        players[name] = {
            state = "pre-active",
            key = control_name,
            time = minetest.get_gametime()
        }
    else
        players[name] = {
            state = "active",
            key = control_name,
            time = minetest.get_gametime()
        }
        perform_dodge(player, control_name)
    end
end)

-- cleanup when player logs out
minetest.register_on_leaveplayer(function(player, _)
    players[player:get_player_name()] = nil
end)
