if cmo == nil then cmo = {} end

local PLACE_BLOOD = minetest.settings:get_bool("cmo_blood.place_blood", true)
local FIX_REMOVED_BLOOD = minetest.settings:get_bool("cmo_blood.fix_removed_blood", false)
local HIT_EFFECTS = minetest.settings:get_bool("cmo_blood.hit_effects", true)
local MAX_PARTICLES = math.floor(tonumber(minetest.settings:get("cmo_blood.hit_particles") or 20))
local BLEEDING = minetest.settings:get_bool("cmo_blood.bleeding", true)

-- skip particle generation on old API pre MT-5.6.0
if not minetest.features.particlespawner_tweenable then
    HIT_EFFECTS = false
    BLEEDING = false
end

local VARIANT_COUNT = 4
local CHECK_DISTANCE = 3
local NODE_CHANCE = 6

local HEALTH_BLEEDING_THRESHOLD = 0.3

local valid_reasons = { punch = true, fall = true, node_damage = true, set_hp = true }

function cmo.trigger_bleeding_fx(player, health)
    health = health / minetest.PLAYER_MAX_HP_DEFAULT
    return health <= HEALTH_BLEEDING_THRESHOLD
end

local function scale(val, min, max)
    if val <= min then return min end
    if val >= max then return max end
    return (val - min) * (max - min) + min
end

local function start_timer(pos)
    local timer = minetest.get_node_timer(pos)
    timer:start(20)
end

local node_box = {
	type  = "fixed",
	fixed = { -0.5, -0.5, -0.5, 0.5, -0.49, 0.5 }
}

-- register blood splatter nodes
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
                on_timer = minetest.remove_node
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
                on_timer = minetest.remove_node
            })
        end
    end
end

-- place blood splatters on ground
if PLACE_BLOOD then
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

    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if not player or hp_change >= 0 then return end
        if reason.type == nil or not valid_reasons[reason.type] then return end
        if reason.type == "set_hp" and reason.subtype ~= "delay_punch" then return end
        local damage = -hp_change / minetest.PLAYER_MAX_HP_DEFAULT
        local should_place = damage ^ (1 / NODE_CHANCE) >= math.random()
        local health = player:get_hp() + hp_change
        if health <= 0 then
            should_place = true
        end
        if should_place then
            local pos = player:get_pos()
            place_blood(pos)
        end
    end, false)
end

-- spawn particles upon getting hit
if HIT_EFFECTS then
    minetest.register_on_player_hpchange(function(player, hp_change, reason)
        if not player or hp_change >= 0 then return end
        if reason.type == nil or not valid_reasons[reason.type] then return end
        if reason.type == "set_hp" and reason.subtype ~= "delay_punch" then return end
        local pos = vector.new({ x = 0, y = 0, z = 0 })
        local spawner_pos = pos
        local gravity = -((player:get_properties()).gravity or 1) * 9.81
        local spawner_vel = {
            min = vector.new({ x = -5, y = -2 , z = -5 }),
            max = vector.new({ x = 5, y = 2, z = 5 })
        }
        local spawner_radius = { min = 0, max = 0.3, bias = 0.5 }
        local amount = math.ceil(scale(-hp_change / minetest.PLAYER_MAX_HP_DEFAULT, 0.2, 0.5) * 2 * MAX_PARTICLES)
        if reason.type == "fall" then
            -- spread out particles horizontally
            spawner_pos.y = spawner_pos.y + 0.1
            spawner_radius.max = vector.new({ x = 0.3, y = 0, z = 0.3 })
        else
            spawner_pos.y = spawner_pos.y + ((player:get_properties()).eye_height / 2)
        end
        if reason.type == "punch" and reason.object then
            -- offset closer to direction of origin
            local attack_pos = reason.object:get_pos()
            local diff = vector.normalize(vector.subtract(attack_pos, pos))
            spawner_pos = vector.add(spawner_pos, vector.multiply(diff, 0.4))
            -- spread out particles diagonally (w.r.t. hit animation)
            spawner_radius.max = vector.new({ x = 0.1, y = 0.5, z = 0.1 })
            spawner_radius.bias = 0.2
            spawner_vel.min = vector.new({ x = -0.1, y = -0.1, z = -0.1 })
            spawner_vel.max = vector.new({ x = 0.1, y = 0.1, z = 0.1 })
        end
        minetest.add_particlespawner({
            amount = amount,
            time = 0.5,
            attached = player,
            collisiondetection = true,
            collision_removal = true,
            texture = "cmo_blood_particle.png",
            size = 0.5,
            pos = spawner_pos,
            vel = spawner_vel,
            acc = { x = 0, y = gravity, z = 0 },
            drag = { x = 3, y = 0, z = 3 },
            radius = spawner_radius,
            exptime = { min = 0.2, max = 0.5 }
        })
    end, false)
end

-- spawn particles on injured players
local spawners = {}
if BLEEDING then
    local function player_bleeding(player, hp_change)
        local name = player:get_player_name()
        local health = (player:get_hp() + hp_change)
        local should_bleed = cmo.trigger_bleeding_fx(player, health)
        local gravity = -((player:get_properties()).gravity or 1) * 9.81
        local eye_height = (player:get_properties()).eye_height
        local max_radius = vector.new({ x = 0.5, y = math.min(1, eye_height / 2), z = 0.5 })
        if should_bleed and spawners[name] == nil then
            spawners[name] = minetest.add_particlespawner({
                amount = 4,
                time = 0,
                attached = player,
                collisiondetection = true,
                collision_removal = true,
                texture = "cmo_blood_particle.png",
                size = 0.5,
                pos = vector.new({x = 0, y = eye_height / 2, z = 0 }),
                vel = {
                    min = vector.new({ x = -0.5, y = -3 , z = -0.5 }),
                    max = vector.new({ x = 0.5, y = 1.5, z = 0.5 })
                },
                acc = { x = 0, y = gravity, z = 0 },
                drag = { x = 3, y = 0, z = 3 },
                radius = { min = 0, max = max_radius, bias = 0.2 },
                exptime = { min = 0.2, max = 0.5 }
            })
            if spawners[name] == -1 then spawners[name] = nil end
        elseif not should_bleed and spawners[name] ~= nil then
            minetest.delete_particlespawner(spawners[name])
            spawners[name] = nil
        end
    end

    minetest.register_on_player_hpchange(player_bleeding, false)
    minetest.register_on_joinplayer(function(player)
        player_bleeding(player, 0)
    end)
end