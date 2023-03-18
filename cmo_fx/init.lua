if not minetest.settings:get_bool("cmo_fx.enabled", true) then return end

local mod_mana = minetest.get_modpath("mana") ~= nil

local CYCLE_LENGTH = 0.1

local players = {}

local VIGNETTE_OPACITY_MIN = 64
local VIGNETTE_OPACITY_MAX = 255

local function get_light(player)
    local pos = vector.add(player:get_pos(), { x = 0, y = 1, z = 0 })
    local node_light = minetest.env:get_node_light(pos)
    if not node_light then node_light = 0 end
    return node_light / 15
end

local function scale(min, max, val)
    return min + val * (max - min)
end

local function apply_vignette(player)
    local name = player:get_player_name()
    local health = player:get_hp() / minetest.PLAYER_MAX_HP_DEFAULT
    local opacity = scale(VIGNETTE_OPACITY_MIN, VIGNETTE_OPACITY_MAX, 1 - health)
    local image = "cmo_vignette.png^[opacity:" .. opacity
    if not players[name] then
        players[name] = {}
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
local function apply_saturation(player)
    local playername = player:get_player_name()
    local health = scale(0.8, 1, player:get_hp() / minetest.PLAYER_MAX_HP_DEFAULT)
    local stamina = scale(0.9, 1, unified_stamina.get(playername))
    local mana_val = 1
    if mod_mana then
        mana_val = scale(0.2, 1, mana.get(playername) / mana.getmax(playername))
    end
    local saturation = health * stamina * mana_val
    lighting_monoids.saturation:add_change(player, saturation, "cmo_fx:stamina_drain")
end

local function apply_shake(player) end

local function apply_fx(player)
    apply_vignette(player)
    apply_saturation(player)
end

minetest.register_on_leaveplayer(function(player)
    local playername = player:get_player_name()
    players[playername] = nil
end)

local timer = 0
minetest.register_globalstep(function(dtime)
    -- skip if not enough time has passed
    timer = timer + dtime
    if timer < CYCLE_LENGTH then return end

    -- skip if no one is online
    local playerlist = minetest.get_connected_players()
    if #playerlist == 0 then return end

    for _, player in ipairs(playerlist) do
        apply_fx(player, timer)
    end

    -- reset timer
    timer = 0
end)
