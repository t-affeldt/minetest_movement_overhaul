local ENABLE_VIGNETTE = minetest.settings:get_bool("cmo_fx.vignette", true)
local ENABLE_DESATURATION = minetest.settings:get_bool("cmo_fx.desaturate", true)
local ENABLE_HEARTBEAT = minetest.settings:get_bool("cmo_fx.heartbeat", true)
local ENABLE_MANA_PARTICLES = true
local ENABLE_MANA_SOUND = true

local mod_mana = minetest.get_modpath("mana") ~= nil
if not mod_mana or not minetest.features.particlespawner_tweenable then
    ENABLE_MANA_PARTICLES = false
end

local CYCLE_LENGTH = 0.1

local players = {}

local VIGNETTE_OPACITY_MIN = 64
local VIGNETTE_OPACITY_MAX = 255
local HEARTBEAT_THRESHOLD = 0.3

local function scale(min, max, val)
    return min + val * (max - min)
end

local function apply_vignette(player, hp_offset)
    if not ENABLE_VIGNETTE then return end
    local name = player:get_player_name()
    local health = (player:get_hp() + hp_offset) / minetest.PLAYER_MAX_HP_DEFAULT
    local opacity = scale(VIGNETTE_OPACITY_MIN, VIGNETTE_OPACITY_MAX, 1 - health)
    local image = "cmo_vignette.png^[opacity:" .. opacity
    if not players[name].vignette then
        players[name].vignette = player:hud_add({
            name = "cmo_vignette",
            hud_elem_type = "image",
            position = { x = 0, y = 0 },
            alignment = { x = 1, y = 1 },
            scale = { x = -100, y = -100 },
            z_index = -400,
            text = image,
            offset = { x = 0, y = 0 }
	    })
    else
        local vignette = player:hud_get(players[name].vignette)
        if vignette.text ~= image then
            player:hud_change(players[name].vignette, "text", image)
        end
    end
end

local function apply_saturation(player, hp_offset)
    if not ENABLE_DESATURATION then return end
    local playername = player:get_player_name()
    local health = scale(0.8, 1, (player:get_hp() + hp_offset) / minetest.PLAYER_MAX_HP_DEFAULT)
    local stamina = scale(0.9, 1, unified_stamina.get(playername))
    local mana_val = 1
    if mod_mana then
        mana_val = scale(0.2, 1, mana.get(playername) / mana.getmax(playername))
    end
    local lighting = { saturation = health * stamina * mana_val }
    lighting_monoid:add_change(player, lighting, "cmo_fx:stamina_drain")
end

local function apply_heartbeat(player, hp_offset)
    if not ENABLE_HEARTBEAT then return end
    local playername = player:get_player_name()
    local heartbeat = players[playername].heartbeat
    local health = (player:get_hp() + hp_offset) / minetest.PLAYER_MAX_HP_DEFAULT
    if (health == 0 or health > HEARTBEAT_THRESHOLD) and heartbeat ~= nil then
        minetest.sound_fade(heartbeat, 0.2, 0)
        players[playername].heartbeat = nil
    elseif health <= HEARTBEAT_THRESHOLD and heartbeat == nil then
        heartbeat = minetest.sound_play({ name = "cmo_fx_heartbeat" }, {
            to_player = playername,
            fade = 0.3,
            loop = true
        })
        players[playername].heartbeat = heartbeat
    end
end

local function apply_mana_recharge(player)
    if not ENABLE_MANA_PARTICLES and not ENABLE_MANA_SOUND then return end
    local name = player:get_player_name()
    local mana_val = mana.get(name) / mana.getmax(name)
    if mana_val <= 0.5 then
        if ENABLE_MANA_PARTICLES and not players[name].mana_particles then
            local eye_height = (player:get_properties()).eye_height
            players[name].mana_particles = minetest.add_particlespawner({
                amount = 30,
                time = 0,
                attached = player,
                collisiondetection = false,
                texture = {
                    name = "cmo_mana_particle.png^[invert:rgb",
                    blend = "sub"
                },
                size = 0.2,
                pos = vector.new({x = 0, y = eye_height / 2, z = 0 }),
                radius = 1.5,
                exptime = 2,
                attract = {
                    kind = "point",
                    strength = 0.5,
                    origin = vector.new({ x = 0, y = eye_height, z = 0 }),
                    origin_attached = player
                }
            })
        end
        if ENABLE_MANA_SOUND and not players[name].mana_sound then
            players[name].mana_sound = minetest.sound_play({ name = "cmo_fx_mana_depletion", gain = 0.2 }, {
                to_player = name,
                fade = 0.3,
                loop = true
            })
        end
    else
        if players[name].mana_particles then
            minetest.delete_particlespawner(players[name].mana_particles)
            players[name].mana_particles = nil
        end
        if players[name].mana_sound then
            minetest.sound_fade(players[name].mana_sound, 0.2, 0)
            players[name].mana_sound = nil
        end
    end
end

if ENABLE_VIGNETTE or ENABLE_HEARTBEAT then
    minetest.register_on_player_hpchange(function(player, hp_change)
        if hp_change == 0 then return end
        apply_vignette(player, hp_change)
        apply_heartbeat(player, hp_change)
    end, false)
end

if ENABLE_DESATURATION or ENABLE_MANA_PARTICLES or ENABLE_MANA_SOUND then
    local timer = 0
    minetest.register_globalstep(function(dtime)
        -- skip if not enough time has passed
        timer = timer + dtime
        if timer < CYCLE_LENGTH then return end

        -- skip if no one is online
        local playerlist = minetest.get_connected_players()
        if #playerlist == 0 then return end

        for _, player in ipairs(playerlist) do
            apply_saturation(player, 0)
            apply_mana_recharge(player)
        end

        -- reset timer
        timer = 0
    end)
end

minetest.register_on_joinplayer(function(player)
    local playername = player:get_player_name()
    players[playername] = {}
    minetest.after(0, function()
        apply_vignette(player, 0)
        apply_saturation(player, 0)
        apply_heartbeat(player, 0)
    end)
end)

minetest.register_on_leaveplayer(function(player)
    local playername = player:get_player_name()
    players[playername] = nil
end)