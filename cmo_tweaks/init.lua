if cmo == nil then cmo = {} end
local MODPATH = minetest.get_modpath(minetest.get_current_modname())

local mod_name_monoid = minetest.get_modpath("name_monoid") ~= nil
local mod_player_api = minetest.get_modpath("player_api") ~= nil
local mod_playertags = minetest.get_modpath("playertags") ~= nil

local RESTRICT_AIR_MOVEMENT = minetest.settings:get_bool("cmo_tweaks.restrict_air", true)
local MUTE_SNEAK_FOOTSTEPS = minetest.settings:get_bool("cmo_tweaks.mute_sneak_footsteps", true)
local HIDE_NAMETAG = minetest.settings:get_bool("cmo_tweaks.hide_nametag", true)
local HIDE_ON_MINIMAP = minetest.settings:get_bool("cmo_tweaks.hide_on_minimap", true)
local ADJUST_PLAYER_ANIMATIONS = minetest.settings:get_bool("cmo_tweaks.adjust_animations", true)

local CYCLE_LENGTH = 0.2

if mod_playertags then
    HIDE_NAMETAG = false
end

if RESTRICT_AIR_MOVEMENT then
    local function is_grounded(pos)
        local node = minetest.get_node_or_nil({ x = pos.x, y = pos.y - 1, z = pos.z })
        local node_def = node and minetest.registered_nodes[node.name]
        return node_def == nil or node_def.walkable
    end

    local function is_climbable(pos)
        local node = minetest.get_node_or_nil(pos)
        local node_def = node and minetest.registered_nodes[node.name]
        return node_def == nil or (node_def.climbable or node_def.liquidtype ~= "none")
    end

    local timer = 0
    minetest.register_globalstep(function(dtime)
        -- skip if not enough time has passed
        timer = timer + dtime
        if timer < CYCLE_LENGTH then return end
        timer = 0

        local players = minetest.get_connected_players()
        for _, player in ipairs(players) do
            local speed = 1
            local pos = player:get_pos()
            local may_fly = player:get_attach() ~= nil or minetest.check_player_privs(player, "fly")
            if not may_fly and not is_grounded(pos) and not is_climbable(pos) then speed = 0.25 end
            player_monoids.speed:add_change(player, speed, "cmo_tweaks:jump_commitment")
        end
    end)
end

local detect_sneak = MUTE_SNEAK_FOOTSTEPS or HIDE_NAMETAG or HIDE_ON_MINIMAP
if detect_sneak then
    controls.register_on_press(function(player, control_name)
        if control_name ~= "sneak" then return end
        if MUTE_SNEAK_FOOTSTEPS then
            player:set_properties({ makes_footstep_sound = false })
        end
        if HIDE_NAMETAG then
            if mod_name_monoid then
                local nametag = { color = { r = 0, g = 0, b = 0, a = 0 } }
                name_monoid.monoid:add_change(player, nametag, "cmo_tweaks:sneaking")
            else
                local nametag = player:get_nametag_attributes()
                nametag.color.a = 0
                player:set_nametag_attributes(nametag)
            end
        end
        if HIDE_ON_MINIMAP then
            player:set_properties({ show_on_minimap = false })
        end
    end)

    controls.register_on_release(function(player, control_name)
        if control_name ~= "sneak" then return end
        if MUTE_SNEAK_FOOTSTEPS then
            player:set_properties({ makes_footstep_sound = true })
        end
        if HIDE_NAMETAG then
            if mod_name_monoid then
                name_monoid.monoid:del_change(player, "cmo_tweaks:sneaking")
            else
                local nametag = player:get_nametag_attributes()
                nametag.color.a = 255
                player:set_nametag_attributes(nametag)
            end
        end
        if HIDE_ON_MINIMAP then
            player:set_properties({ show_on_minimap = true })
        end
    end)
end

if mod_player_api and ADJUST_PLAYER_ANIMATIONS then
    dofile(MODPATH .. DIR_DELIM .. "animation.lua")
end