if not minetest.settings:get_bool("cmo_camera.enabled", true) then return end

local max_eye_offset = vector.new({ x = 10, y = 5, z = 5 })
local catchup_time = 1.2

local player_data = { }

local function scale(a,b)
    return -1 * a * b
end

-- transform absolute velocity into relation to look direction (in radians)
-- leaves y-axis untouched
local function get_relative_movement(velocity, lookdir)
    local axis = vector.new({ x = 0, y = 1, z = 0 })
    local velocity_horizontal = vector.new({ x = velocity.x, y = 0, z = velocity.z })
    local relative_horizontal = vector.rotate_around_axis(velocity_horizontal, axis, -lookdir)
    local relative = vector.new({ x = relative_horizontal.x, y = velocity.y, z = relative_horizontal.z })
    return relative
end

-- set neutral camera position on join
minetest.register_on_joinplayer(function(player, _)
    player_data[player:get_player_name()] = vector.new({ x = 0, y = 0, z = 0 })
end)

-- cleanup when player logs out
minetest.register_on_leaveplayer(function(player, _)
    player_data[player:get_player_name()] = nil
end)

-- adjust camera offset
minetest.register_globalstep(function(dtime)
    if not dtime then return end
    for _, player in pairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local vel = player:get_velocity()
        local dir = player:get_look_horizontal()
        -- get relative movement direction
        local movement = get_relative_movement(vel, dir)
        -- normalize direction and then scale with maximum
        local scaled = vector.combine(vector.normalize(movement), max_eye_offset, scale)
        -- smooth out camera movement over time
        local catchup = dtime / catchup_time
        local current = (scaled * catchup) + (player_data[name] * (1 - catchup))
        player_data[name] = current

        -- set camera offset
        local p1_offset, _ = player:get_eye_offset()
        player:set_eye_offset(p1_offset, current)
    end
end)