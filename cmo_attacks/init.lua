-- damage modifier: minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)

-- on_use = function(itemstack, user, pointed_thing)

local MISS_PENALTY = 0.2

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
        local groupcaps = (itemstack:get_tool_capabilities()).groupcaps
        local node = minetest.get_node(pointed_thing.under)
        local groups = minetest.registered_nodes[node.name].groups
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