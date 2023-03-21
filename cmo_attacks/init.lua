-- damage modifier: minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)

-- on_use = function(itemstack, user, pointed_thing)

local KNOCKBACK_HEIGHT_ADVANTAGE = tonumber(minetest.settings:get("cmo_attacks.knockback_elevation") or 1.5)
local KNOCKBACK_HEIGHT_SCALE = 4
local KNOCKBACK_AIR_BONUS = tonumber(minetest.settings:get("cmo_attacks.knockback_air") or 1.5)
local MOVEMENT_DAMAGE_MULTIPLIER = tonumber(minetest.settings:get("cmo_attacks.movement_bonus") or 2)
local MOVEMENT_DAMAGE_SCALE = 8
local BACKSTAB_MAX_ANGLE = 90
local BACKSTAB_DAMAGE_MULTIPLIER = tonumber(minetest.settings:get("cmo_attacks.backstabs") or 2)
local MISS_PENALTY = tonumber(minetest.settings:get("cmo_attacks.stamina_drain") or 0.15)
local MELEE_DISTANCE = 8

local knockback_calc = minetest.calculate_knockback
if KNOCKBACK_HEIGHT_ADVANTAGE > 1 or KNOCKBACK_AIR_BONUS > 1 then
    minetest.calculate_knockback = function(player, hitter, dtime, toolcaps, dir, distance, damage, ...)
        local knockback = knockback_calc(player, hitter, dtime, toolcaps, dir, distance, damage, ...)
        -- skip if no damage dealt or target immortal
        if damage == 0 or player:get_armor_groups().immortal then
            return knockback
        end
        local pos1 = player:get_pos()
        local pos2 = hitter:get_pos()
        -- do bonus knockback when positioned higher
        if KNOCKBACK_HEIGHT_ADVANTAGE > 1 then
            local height_diff = pos2.y - pos1.y
            local gravity = (player:get_physics_override()).gravity or 1
            if height_diff > 0 and gravity > 0 then
                local advantage = KNOCKBACK_HEIGHT_ADVANTAGE ^ gravity
                knockback = knockback * (advantage ^ math.min(height_diff / KNOCKBACK_HEIGHT_SCALE, 1))
            end
        end
        -- do bonus knockback when target is in the air
        if KNOCKBACK_AIR_BONUS > 1 then
            local node = minetest.get_node_or_nil({ x = pos1.x, y = pos1.y - 1, z = pos1.z })
            local node_def = node and minetest.registered_nodes[node.name]
            if node_def and not node_def.walkable then
                knockback = knockback * KNOCKBACK_AIR_BONUS
            end
        end
        return knockback
    end
end

if MOVEMENT_DAMAGE_MULTIPLIER > 1 then
    -- do bonus damage based on relative movement speed
    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if hp_change >= 0 then return hp_change end
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
        if hp_change >= 0 then return hp_change end
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

-- play sound effect on hit
minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change >= 0 then return end
    if reason.type ~= "punch" then return end
    if not reason.object or not reason.object:is_player() then return end
    local distance = vector.length(vector.subtract(player:get_pos(), reason.object:get_pos()))
    if distance > MELEE_DISTANCE then return end
    local sound = "cmo_hit_punch"
    local itemstack = reason.object:get_wielded_item()
    local itemname = (itemstack and itemstack:get_name()) or ""
    if minetest.registered_tools[itemname] ~= nil then sound = "cmo_hit_tool" end
    minetest.sound_play({ name = sound }, { to_player = reason.object:get_player_name() }, true)
end, false)

if MISS_PENALTY > 0 then
    -- prevent players from doing damage if out of stamina
    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if hp_change >= 0 then return hp_change end
        if reason.type ~= "punch" then return hp_change end
        if not reason.object or not reason.object:is_player() then return hp_change end
        local distance = vector.length(vector.subtract(player:get_pos(), reason.object:get_pos()))
        if distance > MELEE_DISTANCE then return hp_change end
        local attacker_name = reason.object:get_player_name()
        local stamina = unified_stamina.get(attacker_name)
        if stamina >= MISS_PENALTY then return hp_change end
        minetest.sound_play({ name = "cmo_hit_fail" }, { to_player = attacker_name }, true)
        return 0, true
    end, true)

    -- apply stamina penalty on missed hits
    controls.register_on_press(function(player, control_name)
        if control_name ~= "dig" then return end
        local playername = player:get_player_name()
        if unified_stamina.get(playername) < MISS_PENALTY then
            minetest.sound_play({ name = "cmo_hit_fail" }, { to_player = playername }, true)
            return
        end
        local itemstack = player:get_wielded_item()
        local itemdef = itemstack:get_definition()
        -- ignore using edible items
        if itemdef.on_use == minetest.item_eat then return end
        -- get object / node / nothing that player looks at
        local range = itemdef.range or 4
        local eye_height = (player:get_properties()).eye_height
        local pos1 = vector.add(player:get_pos(), vector.new({ x = 0, y = eye_height, z = 0 }))
        local pos2 = vector.add(pos1, vector.multiply(player:get_look_dir(), range))
        local ray = Raycast(pos1, pos2, true, true)
        local _ = ray() -- first object is player themselves
        local pointed_thing = ray()
        local reduce_stamina = true
        -- ignore successful hits
        if pointed_thing and pointed_thing.type == "object" then
            reduce_stamina = false
        -- ignore hits on minable nodes
        elseif pointed_thing and pointed_thing.type == "node" then
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
            minetest.sound_play({ name = "cmo_hit_miss" }, { to_player = playername }, true)
            unified_stamina.add(playername, -MISS_PENALTY)
        end
    end)
end