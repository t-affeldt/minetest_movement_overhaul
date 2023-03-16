local mod_hud_timers = minetest.get_modpath("hud_timers") ~= nil

local MAX_KEY_TIME = 1
local INVULNERABILTY_TIME = 1

local STAMINA_COST = tonumber(minetest.settings:get("cmo_dodge.stamina_cost") or 0.25)

local directions = {
    left = vector.new({ x = -1, y = 0, z = 0 }),
    right = vector.new({ x = 1, y = 0, z = 0 }),
    up = vector.new({ x = 0, y = 0, z = 1 }),
    down = vector.new({ x = 0, y = 0, z = -1 })
}

local players = {}

local function get_absolute_movement(velocity, lookdir)
    local axis = vector.new({ x = 0, y = 1, z = 0 })
    local velocity_horizontal = vector.new({ x = velocity.x, y = 0, z = velocity.z })
    local relative_horizontal = vector.rotate_around_axis(velocity_horizontal, axis, lookdir)
    local relative = vector.new({ x = relative_horizontal.x, y = velocity.y, z = relative_horizontal.z })
    return relative
end

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
    minetest.log(dump2(stamina, "stamina"))
    -- cancel if insufficient stamina
    if stamina < STAMINA_COST then return end
    local lookdir = player:get_look_horizontal()
    local direction = get_absolute_movement(directions[control_name], lookdir)
    -- add speed boost into chosen direction
    local velocity = vector.multiply(direction, 15)
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
    -- modify player properties during the dodge
    local properties = player:get_properties()
    local properties_before = {}
    properties_before.pointable = properties.pointable
    properties_before.physical = properties.physical
    properties.pointable = false
    properties.physical = false
    player:set_properties(properties)
    -- reset player properties after some time
    minetest.after(INVULNERABILTY_TIME, function()
        if not player then return end
        post_hook(player, properties_before)
    end)
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
