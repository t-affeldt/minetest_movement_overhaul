local S = minetest.get_translator("cmo_stamina")

local AUTO_HIDE = minetest.settings:get_bool("cmo_stamina.autohide_hudbar", true)

-- the hudbars included in Mineclone2 uses a different call signature :(
local IS_MINECLONE = minetest.get_modpath("mcl_util") ~= nil
local unpack = table.unpack or unpack

local bar = "cmo_stamina_bar.png"
local icon = "cmo_stamina_icon.png"
local color_default = "#168e3c"
local color_highlight = "#0aaf3e"

local params = {
    "cmo_stamina",
    0xFFFFFF,
    S("Stamina"),
    {
        bar = bar .. "^[multiply:" .. color_default .. ":255",
        icon = icon .. "^[multiply:" .. color_default .. ":255",
        bgicon = icon .. "^[multiply:#505050:255"
    },
    100,
    100,
    AUTO_HIDE,
    "@1: @2%",
    {
        order = { "label", "value" },
        textdomain = "cmo_stamina"
    }
}

if IS_MINECLONE then
    -- add extra "direction" parameter
    table.insert(params, 5, 0)
end

hb.register_hudbar(
    unpack(params)
)

function cmo.stamina._update_bar(player, value)
    value = math.floor(value * 100)
    hb.change_hudbar(player, "cmo_stamina", value)
    if AUTO_HIDE then
        if value == 100 then
            hb.hide_hudbar(player, "cmo_stamina")
        else
            hb.unhide_hudbar(player, "cmo_stamina")
        end
    end
end

function cmo.stamina.highlight_bar(player, highlight)
    local color = color_default
    if highlight then color = color_highlight end
    local new_bar = bar .. "^[multiply:" .. color .. ":255"
    local new_icon = icon .. "^[multiply:" .. color .. ":255"
    hb.change_hudbar(player, "cmo_stamina", nil, nil, new_icon, nil, new_bar)
end

minetest.register_on_joinplayer(function(player)
    local playername = player:get_player_name()
    local stamina = math.floor(cmo.stamina.get(playername) * 100)
    hb.init_hudbar(player, "cmo_stamina", stamina, nil, stamina == 100)
end)