if not minetest.settings:get_bool("cmo_fixes.enabled", true) then return end

local CYCLE_LENGTH = 0.2

local function is_grounded(pos)
    local node = minetest.get_node_or_nil({ x = pos.x, y = pos.y - 1, z = pos.z })
    local node_def = node and minetest.registered_nodes[node.name]
    return node_def == nil or node_def.walkable
end

local function is_climbable(pos)
    local node = minetest.get_node_or_nil(pos)
    local node_def = node and minetest.registered_nodes[node.name]
    return node_def == nil or (node_def.climbable or node_def.liquidtype ~= "none")
end

local timer = 0
minetest.register_globalstep(function(dtime)
     -- skip if not enough time has passed
     timer = timer + dtime
     if timer < CYCLE_LENGTH then return end
     timer = 0

    -- skip if no one is online
    local playerlist = minetest.get_connected_players()
    if #playerlist == 0 then return end

    for _, player in ipairs(playerlist) do
        local speed = 1
        local pos = player:get_pos()
        local may_fly = player:get_attach() ~= nil or minetest.check_player_privs(player, "fly")
        if not may_fly and not is_grounded(pos) and not is_climbable(pos) then speed = 0.25 end
        player_monoids.speed:add_change(player, speed, "cmo_fixes:ground_lock")
    end
end)
