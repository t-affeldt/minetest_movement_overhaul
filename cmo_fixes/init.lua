if not minetest.settings:get_bool("cmo_fixes.enabled", true) then return end

minetest.register_globalstep(function(dtime)
    -- skip if no one is online
    local playerlist = minetest.get_connected_players()
    if #playerlist == 0 then return end

    for _, player in ipairs(playerlist) do
        local speed = 1
        local pos = player:get_pos()
        local node = minetest.get_node_or_nil({ x = pos.x, y = pos.y - 1, z = pos.z })
        local node_def = node and minetest.registered_nodes[node.name]
        local grounded = node_def and (node_def.walkable or node_def.liquidtype ~= "none")
        local may_fly = player:get_attach() ~= nil or minetest.check_player_privs(player, "fly")
        if not grounded and not may_fly then speed = 0.25 end
        player_monoids.speed:add_change(player, speed, "cmo_fixes:ground_lock")
    end
end)
