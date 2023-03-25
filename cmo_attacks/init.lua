if cmo == nil then cmo = {} end
local MODPATH = minetest.get_modpath(minetest.get_current_modname())

local mod_x_enchanting = minetest.get_modpath("x_enchanting") ~= nil

local KNOCKBACK_HEIGHT_ADVANTAGE = tonumber(minetest.settings:get("cmo_attacks.knockback_elevation") or 1.5)
local KNOCKBACK_HEIGHT_SCALE = 4
local KNOCKBACK_AIR_BONUS = tonumber(minetest.settings:get("cmo_attacks.knockback_air") or 1.5)
local MOVEMENT_DAMAGE_MULTIPLIER = tonumber(minetest.settings:get("cmo_attacks.movement_bonus") or 1.5)
local MOVEMENT_DAMAGE_SCALE = 8
local BACKSTAB_MAX_ANGLE = 90
local BACKSTAB_DAMAGE_MULTIPLIER = tonumber(minetest.settings:get("cmo_attacks.backstabs") or 1.5)
local MISS_PENALTY = tonumber(minetest.settings:get("cmo_attacks.stamina_drain") or 0.15)
local PLAY_ATTACK_SOUNDS = minetest.settings:get_bool("cmo_attacks.play_attack_sounds", true)

local CYCLE_LENGTH = 0

local function sound_play(...)
    if PLAY_ATTACK_SOUNDS then
        return minetest.sound_play(...)
    end
end

local function chance_round(num)
    local rounded = math.floor(num)
    if num - rounded > math.random() then
        rounded = rounded + 1
    end
    return rounded
end

cmo.damage_modifiers = {}
cmo.skip_damage_groups = {}

function cmo.clean_itemstack(itemstack)
    if not itemstack then return itemstack end
    local itemdef = minetest.registered_tools[itemstack:get_name()]
    -- skip if not a tool and thus wasn't modified
    if not itemdef then return itemstack end
    local meta = itemstack:get_meta()
    local real_caps = meta:get_string("cmo_attacks:real_capabilities")
    if real_caps == "" then
        return itemstack
    else
        real_caps = minetest.deserialize(real_caps, true)
    end
    local tool_caps = itemstack:get_tool_capabilities()
    for group, _ in pairs(tool_caps.damage_groups) do
        if table.indexof(cmo.skip_damage_groups, group) == -1 then
            tool_caps.damage_groups[group] = real_caps[group]
        end
    end
    meta:set_tool_capabilities(tool_caps)
    meta:set_string("cmo_attacks:real_capabilities", "")
    meta:set_string("cmo_attacks:modifier", "")
    return itemstack
end

if mod_x_enchanting then
    dofile(MODPATH .. DIR_DELIM .. "compatibility" .. DIR_DELIM .. "x_enchanting.lua")
end

local knockback_calc = minetest.calculate_knockback
if KNOCKBACK_HEIGHT_ADVANTAGE > 1 or KNOCKBACK_AIR_BONUS > 1 then
    minetest.calculate_knockback = function(player, hitter, dtime, toolcaps, dir, distance, damage, ...)
        local knockback = knockback_calc(player, hitter, dtime, toolcaps, dir, distance, damage, ...)
        -- skip if no knockback dealt
        if knockback == 0 then return knockback end
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
    table.insert(cmo.damage_modifiers, function(player, pointed_thing)
        if pointed_thing.type ~= "object" then return 1 end
        local speed1 = player:get_velocity()
        local speed2 = pointed_thing.ref:get_velocity()
        local diff = vector.length(vector.subtract(speed1, speed2))
        local damage = MOVEMENT_DAMAGE_MULTIPLIER ^ math.min(diff / MOVEMENT_DAMAGE_SCALE, 1)
        damage = math.round(damage * 4) / 4
        return damage
    end)
end

if BACKSTAB_DAMAGE_MULTIPLIER > 1 then
    table.insert(cmo.damage_modifiers, function(player, pointed_thing)
        if pointed_thing.type ~= "object" then return 1 end
        -- determine look direction of pointed entity
        local lookdir
        if pointed_thing.ref:is_player() then
            lookdir = pointed_thing.ref:get_look_dir()
        elseif pointed_thing.ref.get_rotation then
            lookdir = pointed_thing.ref:get_rotation()
        else
            return 1
        end
        -- vector from defender to attacker
        local attacker_dir = vector.subtract(player:get_pos(), pointed_thing.ref:get_pos())
        local angle = vector.angle(lookdir, attacker_dir) / (2 * math.pi) * 360
        -- check if within critical angle
        local max_angle = BACKSTAB_MAX_ANGLE
        if 180 - (max_angle / 2) <= angle then
            return BACKSTAB_DAMAGE_MULTIPLIER
        end
        return 1
    end)
end

-- play sound effect on hit
if PLAY_ATTACK_SOUNDS then
    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if hp_change >= 0 then return end
        if reason.type ~= "punch" then return end
        if not reason.object or not reason.object:is_player() then return end
        if cmo._get_pointed_thing(reason.object).ref ~= player then return end
        local sound = "cmo_hit_punch"
        local itemstack = reason.object:get_wielded_item()
        local itemname = (itemstack and itemstack:get_name()) or ""
        if minetest.registered_tools[itemname] ~= nil then sound = "cmo_hit_tool" end
        sound_play({ name = sound }, { to_player = reason.object:get_player_name() }, true)
    end, false)
end

if MISS_PENALTY > 0 then
    -- prevent players from doing damage if out of stamina
    table.insert(cmo.damage_modifiers, function(player)
        local playername = player:get_player_name()
        local stamina = unified_stamina.get(playername)
        if stamina < MISS_PENALTY then
            return 0
        end
        return 1
    end)

    -- apply stamina penalty on missed hits
    controls.register_on_press(function(player, control_name)
        if control_name ~= "dig" then return end
        local playername = player:get_player_name()
        if unified_stamina.get(playername) < MISS_PENALTY then
            sound_play({ name = "cmo_hit_fail" }, { to_player = playername }, true)
            return
        end
        local itemstack = player:get_wielded_item()
        -- get object / node / nothing that player looks at
        local pointed_thing = cmo._get_pointed_thing(player)
        local reduce_stamina = true
        -- ignore successful hits
        if pointed_thing and pointed_thing.type == "object" then
            reduce_stamina = false
        -- ignore hits on mineable nodes
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
            sound_play({ name = "cmo_hit_miss" }, { to_player = playername }, true)
            unified_stamina.add(playername, -MISS_PENALTY)
        end
    end)
end

local timer = 0
minetest.register_globalstep(function(dtime)
    if #cmo.damage_modifiers == 0 then return end
    timer = timer + dtime
    if timer < CYCLE_LENGTH then return end
    local players = minetest.get_connected_players()
    for _, player in ipairs(players) do

        local itemstack = player:get_wielded_item()
        local itemdef = minetest.registered_tools[itemstack:get_name()]
        -- skip if not a tool and thus shouldn't be modified
        if not itemdef then return end
        local tool_caps = itemstack:get_tool_capabilities()
        -- skip if tool doesn't have any damage groups
        if not tool_caps.damage_groups or not next(tool_caps.damage_groups) then return end
        local pointed_thing = cmo._get_pointed_thing(player)

        local meta = itemstack:get_meta()
        -- NOTE: use string instead of int to set default to 1 instead of 0
        local last_modifier = tonumber(meta:get_string("cmo_attacks:modifier")) or 1
        local real_caps = meta:get_string("cmo_attacks:real_capabilities")
        local store_caps = false
        if real_caps == "" then
            store_caps = true
            real_caps = tool_caps.damage_groups
        else
            real_caps = minetest.deserialize(real_caps, true)
        end

        local modifier = 1
        local modifiers = {}
        for _, method in ipairs(cmo.damage_modifiers) do
            local damage = method(player, pointed_thing)
            table.insert(modifiers, damage)
            modifier = modifier * (damage or 1)
        end

        -- damage unchanged, skip
        if modifier == last_modifier then return end

        for group, _ in pairs(tool_caps.damage_groups) do
            if table.indexof(cmo.skip_damage_groups, group) == -1 then
                tool_caps.damage_groups[group] = chance_round(real_caps[group] * modifier)
            end
        end
        meta:set_tool_capabilities(tool_caps)
        if modifier == 1 then
            meta:set_string("cmo_attacks:modifier", "")
            meta:set_string("cmo_attacks:real_capabilities", "")
        else
            if store_caps then
                local serialized = minetest.serialize(real_caps)
                meta:set_string("cmo_attacks:real_capabilities", serialized)
            end
            meta:set_string("cmo_attacks:modifier", "" .. modifier)
        end
        player:set_wielded_item(itemstack)
    end
    timer = 0
end)