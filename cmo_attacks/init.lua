-- damage modifier: minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)

-- on_use = function(itemstack, user, pointed_thing)

local KNOCKBACK_HEIGHT_ADVANTAGE = tonumber(minetest.settings:get("cmo_attacks.knockback_elevation") or 2)
local KNOCKBACK_HEIGHT_SCALE = 4
local MOVEMENT_DAMAGE_MULTIPLIER = tonumber(minetest.settings:get("cmo_attacks.movement_bonus") or 2)
local MOVEMENT_DAMAGE_SCALE = 10
local BACKSTAB_MAX_ANGLE = 90
local BACKSTAB_DAMAGE_MULTIPLIER = tonumber(minetest.settings:get("cmo_attacks.backstabs") or 2)
local MISS_PENALTY = 0.2

if KNOCKBACK_HEIGHT_ADVANTAGE > 1 then
    -- do bonus knockback when positioned higher
    local knockback_calc = minetest.calculate_kockback
    minetest.calculate_knockback = function(player, hitter, ...)
        local knockback = knockback_calc(player, hitter, ...)
        local pos1 = player:get_pos()
        local pos2 = hitter:get_pos()
        local height_diff = pos2.y - pos1.y
        if height_diff <= 0 then return knockback end
        return knockback * (KNOCKBACK_HEIGHT_ADVANTAGE ^ math.min(height_diff / KNOCKBACK_HEIGHT_SCALE, 1))
    end
end

if MOVEMENT_DAMAGE_MULTIPLIER > 1 then
    -- do bonus damage based on relative movement speed
    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if reason.type ~= "punch" then return hp_change end
        if not reason.object then return hp_change end
        local speed1 = player:get_velocity()
        local speed2 = reason.object:get_velocity()
        local diff = vector.length(vector.subtract(speed1, speed2))
        return hp_change * (MOVEMENT_DAMAGE_MULTIPLIER ^ math.min(diff / MOVEMENT_DAMAGE_SCALE, 1))
    end, true)
end

if BACKSTAB_DAMAGE_MULTIPLIER > 1 then
    -- do bonus damage for backstabs
    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if reason.type ~= "punch" then return hp_change end
        if not reason.object or not reason.object:is_player() then return hp_change end
        local lookdir = player:get_look_dir()
        -- vector from defender to attacker
        local attacker_dir = vector.subtract(reason.object:get_pos(), player:get_pos())
        local angle = vector.angle(lookdir, attacker_dir)
        local max_angle = BACKSTAB_MAX_ANGLE * math.pi / 180
        if 180 - (max_angle / 2) <= angle and angle <= 180 + (max_angle / 2) then
            hp_change = hp_change * BACKSTAB_DAMAGE_MULTIPLIER
        end
        return hp_change
    end, true)
end

if MISS_PENALTY > 0 then
    -- prevent players from doing damage if out of stamina
    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if reason.type ~= "punch" then return hp_change end
        if not reason.object or not reason.object:is_player() then return hp_change end
        local stamina = unified_stamina.get(reason.object:get_player_name())
        if stamina >= MISS_PENALTY then return hp_change end
        return 0, true
    end, true)

    -- apply stamina penalty on missed hits
    controls.register_on_press(function(player, control_name)
        if control_name ~= "dig" then return end
        local itemstack = player:get_wielded_item()
        -- get object / node / nothing that player looks at
        local range = (itemstack:get_definition()).range or 4
        local eye_height = (player:get_properties()).eye_height
        local pos1 = vector.add(player:get_pos(), vector.new({ x = 0, y = eye_height, z = 0 }))
        local pos2 = vector.add(pos1, vector.multiply(player:get_look_dir(), range))
        local ray = Raycast(pos1, pos2, true, true)
        local _ = ray() -- first object is player themselves
        local pointed_thing = ray()
        local reduce_stamina = true
        -- ignore hits on minable nodes
        if pointed_thing and pointed_thing.type == "node" then
            local groupcaps = (itemstack:get_tool_capabilities()).groupcaps or {}
            local node = minetest.get_node(pointed_thing.under)
            local groups = minetest.registered_nodes[node.name].groups or {}
            for capability, _ in pairs(groupcaps) do
                for group, _ in pairs(groups) do
                    if not reduce_stamina then break end
                    if capability == group then
                        reduce_stamina = false
                        break
                    end
                end
            end
        end
        -- apply stamina penalty
        if reduce_stamina then
            local playername = player:get_player_name()
            unified_stamina.add(playername, -MISS_PENALTY)
        end
    end)
end