if not minetest.settings:get_bool("cmo_camera.enabled", true) then return end

local CYCLE_LENGTH = 0.05
local CATCHUP_TIME = 1.5
local OFFSET_THRESHOLD = 0.25

local max_eye_offset = vector.new({ x = 10, y = 5, z = 5 })

local player_data = { }

local function scale(a,b)
    return -1 * a * b
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
local timer = 0
minetest.register_globalstep(function(dtime)
    -- skip if not enough time has passed
    timer = timer + dtime
    if timer < CYCLE_LENGTH then return end

    -- skip if no one is online
    local playerlist = minetest.get_connected_players()
    if #playerlist == 0 then return end

    for _, player in pairs(playerlist) do
        local name = player:get_player_name()
        local vel = player:get_velocity()
        local dir = player:get_look_horizontal()
        -- get relative movement direction
        local movement = cmo.get_relative_vector(vel, dir)
        -- normalize direction and then scale with maximum
        local scaled = vector.combine(vector.normalize(movement), max_eye_offset, scale)
        -- skip if negligible
        local offset_1p, _ = player:get_eye_offset()
        local difference = scaled - player_data[name]
        local distance = vector.length(difference)
        if distance > OFFSET_THRESHOLD then
            -- smooth out camera movement over time
            local catchup = math.min(timer / CATCHUP_TIME, 1)
            local offset_new = player_data[name] + (difference) * catchup
            player_data[name] = offset_new
            -- set camera offset
            player:set_eye_offset(offset_1p, offset_new)
        end
    end

    timer = 0
end)