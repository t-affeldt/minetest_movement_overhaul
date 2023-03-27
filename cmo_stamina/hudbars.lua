local S = minetest.get_translator("cmo_stamina")

local AUTO_HIDE = minetest.settings:get_bool("cmo_stamina.autohide_hudbar", true)

local bar = "cmo_stamina_bar.png"
local icon = "cmo_stamina_icon.png"
local color_default = "#168e3c"
local color_highlight = "#0aaf3e"

hb.register_hudbar(
    "stamina",
    0xFFFFFF,
    S("Stamina"),
    {
        bar = bar .. "^[colorize:" .. color_default .. ":255",
        icon = icon .. "^[colorize:" .. color_default .. ":255",
        bgicon = icon .. "^[colorize:#505050:255"
    },
    100,
    100,
    AUTO_HIDE,
    "@1: @2%",
    {
        order = { "label", "value" },
        textdomain = "cmo_stamina"
    }
)

function cmo.stamina._update_bar(player, value)
    value = math.floor(value * 100)
    hb.change_hudbar(player, "stamina", value)
    if AUTO_HIDE then
        if value == 100 then
            hb.hide_hudbar(player, "stamina")
        else
            hb.unhide_hudbar(player, "stamina")
        end
    end
end

function cmo.stamina.highlight_bar(player, highlight)
    local color = color_default
    if highlight then color = color_highlight end
    local new_bar = bar .. "^[colorize:" .. color .. ":255"
    local new_icon = icon .. "^[colorize:" .. color .. ":255"
    hb.change_hudbar(player, "stamina", nil, nil, new_icon, nil, new_bar)
end

minetest.register_on_joinplayer(function(player)
    local playername = player:get_player_name()
    local stamina = math.floor(cmo.stamina.get(playername) * 100)
    hb.init_hudbar(player, "stamina", stamina, nil, stamina == 100)
end)