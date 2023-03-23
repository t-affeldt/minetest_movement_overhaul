local blocking_players = {}

local CYCLE_LENGTH = 0.5
local BLOCK_MAX_ANGLE = 90
local BLOCK_DAMAGE_MULTIPLIER = 0.3
local BLOCK_STAMINA_COST = 0.1

local function on_place(itemstack, player, pointed_thing)
    local name = player:get_player_name()
    blocking_players[name] = minetest.get_gametime()
end

controls.register_on_release(function(player, control_name)
    if control_name ~= "place" then return end
    local name = player:get_player_name()
    blocking_players[name] = nil
end)

-- block frontal damage
minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change >= 0 then return hp_change end
    if reason.type ~= "punch" then return hp_change end
    if not reason.object then return hp_change end
    local playername = player:get_player_name()
    local stamina = unified_stamina.get(playername)
    if not blocking_players[playername] or stamina <= 0 then return hp_change end
    local lookdir = player:get_look_dir()
    -- vector from defender to attacker
    local attacker_dir = vector.subtract(reason.object:get_pos(), player:get_pos())
    local angle = vector.angle(lookdir, attacker_dir)
    local max_angle = BLOCK_MAX_ANGLE * math.pi / 180
    if (360 - (max_angle / 2) <= angle and angle < 360) or (angle <= (max_angle / 2)) then
        hp_change = math.ceil(hp_change * BLOCK_DAMAGE_MULTIPLIER)
    end
    return hp_change
end, true)

local function override_shield(item, itemdef)
    --minetest.log(dump2(itemdef.armor_groups, item))
    local groups = itemdef.groups or {}
    local rating = (itemdef.armor_groups and itemdef.armor_groups.fleshy) or 0
    local use = itemdef.groups.armor_use or 1
    local negation = itemdef.groups.armor_heal or 0
    groups.armor_shield = nil
    groups.armor_use = nil
    groups.armor_heal = nil
    minetest.override_item(item, {
        groups = groups,
        armor_groups = {},
        on_place = on_place,
        on_secondary_use = on_place
    })
end

minetest.after(0, function()
    for tool, tooldef in pairs(minetest.registered_tools) do
        if tooldef.groups.armor_shield ~= nil then
            override_shield(tool, tooldef)
        end
    end
end)

local timer = 0
minetest.register_globalstep(function(dtime)
    -- skip if not enough time has passed
    timer = timer + dtime
    if timer < CYCLE_LENGTH then return end

    for playername, _ in pairs(blocking_players) do
        --minetest.log(dump2(-BLOCK_STAMINA_COST * timer, "val"))
        unified_stamina.add(playername, -BLOCK_STAMINA_COST * timer)
    end

    timer = 0
end)