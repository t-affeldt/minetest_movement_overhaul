local HOTBAR_SIZE = 64

local huds = {}
local left_click_users = {}

local global_timer

local function remove_hud(player)
    local playername = player:get_player_name()
    if huds[playername] ~= nil then
        player:hud_remove(huds[playername])
        huds[playername] = nil
    end
end

local function set_cooldown_hud(player, dtime)
    if global_timer == nil then global_timer = minetest.get_gametime() end
    if dtime == nil then dtime = 0 end

    local itemstack = player:get_wielded_item()
    local itemdef = itemstack:get_definition()

    if minetest.registered_tools[itemdef.name] == nil then
        remove_hud(player)
        return
    end

    local playername = player:get_player_name()
    local meta = itemstack:get_meta()

    local player_controls = player:get_player_control()
    if player_controls.dig and not left_click_users[playername] then
        left_click_users[playername] = true
        meta:set_float("mco_hud:last_use", global_timer + dtime)
        player:set_wielded_item(itemstack)
    elseif not player_controls.dig and left_click_users[playername] then
        left_click_users[playername] = nil
    end

    local last_use = meta:get_float("mco_hud:last_use")
    local interval = itemstack:get_tool_capabilities().full_punch_interval
    if interval == nil or interval == 0 then interval = 0.1 end
    local timer = math.min((global_timer + dtime - last_use) / interval, 1)

    local image = "mco_cooldown_active.png^[lowpart:" .. math.ceil(timer * 100) .. ":mco_cooldown_inactive.png"

    local hotbar_count = player:hud_get_hotbar_itemcount()
    local offset = {
        x = HOTBAR_SIZE * (hotbar_count + 1) / 2,
        y = -32
    }

    if not huds[playername] then
        huds[playername] = player:hud_add({
            hud_elem_type = "image",
            position = {
                x = 0.5,
                y = 1
            },
            offset = offset,
            scale = {
                x = 1.5,
                y = 1.5
            },
            text = image,
            z_index = 1
        })
    else
        player:hud_change(huds[playername], "offset", offset)
        player:hud_change(huds[playername], "text", image)
    end
    global_timer = global_timer + dtime
end

minetest.register_globalstep(function(dtime)
    local players = minetest.get_connected_players()
    for _, player in ipairs(players) do
        set_cooldown_hud(player, dtime)
    end
end)