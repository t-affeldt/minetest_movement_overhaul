local PLACE_BLOOD = minetest.settings:get_bool("cmo_blood.place_blood", true)
local FIX_REMOVED_BLOOD = minetest.settings:get_bool("cmo_blood.fix_removed_blood", false)

local VARIANT_COUNT = 4
local CHECK_DISTANCE = 3
local NODE_CHANCE = 8

local node_box = {
	type  = "fixed",
	fixed = { -0.5, -0.5, -0.5, 0.5, -0.49, 0.5 }
}

local function start_timer(pos)
    local timer = minetest.get_node_timer(pos)
    timer:start(20)
end

local function remove_node(pos)
    minetest.remove_node(pos)
end

for i = 1, VARIANT_COUNT do
    for flip = 0, 1 do
        local index = i
        if i < 10 then index = "0" .. i end
        local name = "cmo_blood:blood_splatters_" .. index
        local texture = "cmo_blood_" .. index .. ".png"
        if flip == 1 then
            name = name .. "_flipped"
            texture = texture .. "^[transformFX"
        end
        if PLACE_BLOOD then
            minetest.register_node(name, {
                description = "Blood",
                tiles = { texture },
                drawtype = "nodebox",
                pointable = false,
                buildable_to = true,
                floodable = true,
                walkable = false,
                sunlight_propagates = true,
                paramtype = "light",
                paramtype2 = "facedir",
                use_texture_alpha = "blend",
                node_box = node_box,
                groups = {
                    not_in_creative_inventory = 1,
                    attached_node = 1,
                    slippery = 1,
                    blood = 1
                },
                drop = "",
                on_construct = start_timer,
                on_timer = remove_node
            })
        elseif FIX_REMOVED_BLOOD then
            minetest.register_node(name, {
                description = "Blood",
                drawtype = "airlike",
                pointable = false,
                buildable_to = true,
                flooadable = true,
                walkable = false,
                sunlight_propagates = true,
                paramtype = "light",
                groups = {
                    not_in_creative_inventory = 1,
                    attached_node = 1,
                    removed_blood = 1
                },
                drop = "",
                on_timer = remove_node
            })
        end
    end
end

local function get_random_blood()
    local index = math.random(1, VARIANT_COUNT)
    local flipped = math.random(0, 1)
    local rotation = math.random(0, 3) * 90
    if index < 10 then index = "0" .. index end
    local name = "cmo_blood:blood_splatters_" .. index
    if flipped == 1 then name = name .. "_flipped" end
    local param2 = minetest.dir_to_facedir(minetest.yaw_to_dir(rotation))
    return { name = name, param2 = param2 }
end

local function place_blood(pos)
    local pos_below = vector.add(pos, vector.new({ x = 0, y = -1, z = 0 }))
    if minetest.get_node(pos).name ~= "air" then return end
    if minetest.find_node_near(pos, CHECK_DISTANCE, "ignore") then return end
    local below = minetest.registered_nodes[minetest.get_node(pos_below).name]
    if not below or not below.walkable or below.drawtype ~= "normal" or below.liquidtype ~= "none" then return end
    minetest.set_node(pos, get_random_blood())
end

if PLACE_BLOOD then
    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if not player or hp_change >= 0 then return end
        local damage = -hp_change / minetest.PLAYER_MAX_HP_DEFAULT
        local should_place = damage ^ (1 / NODE_CHANCE) >= math.random()
        if should_place then
            local pos = player:get_pos()
            place_blood(pos)
        end
        --[[local r = math.random(1, 4)
        local x = 0.15 + math.random() * 0.70
        local y = 0.15 + math.random() * 0.70
        local image = "cmo_blood0" .. r .. ".png"
        player:hud_add({
            name = "cmo_blood",
            hud_elem_type = "image",
            position = { x = x, y = y },
            alignment = { x = 0.5, y = 0.5 },
            scale = { x = -30, y = -30 },
            z_index = -401,
            text = image,
            offset = { x = 0, y = 0 }
        })]]

    end, false)
end
