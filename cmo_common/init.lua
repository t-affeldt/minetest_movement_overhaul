if cmo == nil then cmo = {} end

-- transform absolute velocity into relation to look direction (in radians)
-- leaves y-axis untouched
function cmo.get_relative_vector(direction, reference)
    local axis = vector.new({ x = 0, y = 1, z = 0 })
    local direction_horizontal = vector.new({ x = direction.x, y = 0, z = direction.z })
    local relative_horizontal = vector.rotate_around_axis(direction_horizontal, axis, -reference)
    local relative = vector.new({ x = relative_horizontal.x, y = direction.y, z = relative_horizontal.z })
    return relative
end

function cmo.get_absolute_vector(direction, reference)
    return cmo.get_relative_vector(direction, -reference)
end

function cmo._is_grounded(player)
    local pos = player:get_pos()
    local node = minetest.get_node_or_nil({ x = pos.x, y = pos.y - 1, z = pos.z })
    local node_def = node and minetest.registered_nodes[node.name]
    if node_def and not node_def.walkable then
        return false
    end
    return true, node_def
end

local playercache = {}
function cmo._get_pointed_thing(player)
    -- return nothing if not a player
    if not player or not player:is_player() then return nil end

    -- return cached value if already requested this cycle
    local name = player:get_player_name()
    if playercache[name] ~= nil then
        return playercache[name]
    end

    -- adjust player position
    local pos1 = player:get_pos()
    pos1 = pos1 + player:get_eye_offset()
    pos1.y = pos1.y + (player:get_properties()).eye_height

    -- determine pointing range
    local itemstack = player:get_wielded_item()
    local itemdef = itemstack:get_definition()
    local range = itemdef.range
    if not itemdef.range then
        -- use empty hand's range
        local hand = minetest.registered_items[""]
        range = hand.range or 5
    end

    -- cast ray from player's eyes
    local pos2 = pos1 + vector.multiply(player:get_look_dir(), range)
    local ray = Raycast(pos1, pos2, true, false)

    -- iterate through passed things and determine if pointable
    local result = {type="nothing"}
    for pointed_thing in ray do
        if pointed_thing.type == "object" and pointed_thing.ref ~= player then
            local properties = pointed_thing.ref:get_properties()
            if properties.pointable and properties.is_visible then
                result = pointed_thing
                break
            end
        elseif pointed_thing.type == "node" then
            local nodedef = minetest.registered_nodes[pointed_thing.under]
            if nodedef and nodedef.pointable then
                result = pointed_thing
                break
            end
        else
            result = pointed_thing
            break
        end
    end
    playercache[name] = result
    return result
end

minetest.register_globalstep(function()
    playercache = {}
end)