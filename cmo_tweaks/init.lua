local mod_name_monoid = minetest.get_modpath("name_monoid") ~= nil

local RESTRICT_AIR_MOVEMENT = minetest.settings:get_bool("cmo_tweaks.restrict_air", true)
local MUTE_SNEAK_FOOTSTEPS = minetest.settings:get_bool("cmo_tweaks.mute_sneak_footsteps", true)
local HIDE_NAMETAG = minetest.settings:get_bool("cmo_tweaks.hide_nametag", true)
local HIDE_ON_MINIMAP = minetest.settings:get_bool("cmo_tweaks.hide_on_minimap", true)

local CYCLE_LENGTH = 0.2

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

        -- skip if no one is online
        local playerlist = minetest.get_connected_players()
        if #playerlist == 0 then return end

        for _, player in ipairs(playerlist) do
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
                name_monoid.monoid:add_change(player, nametag, "cmo_tweaks:hide_nametag")
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
                name_monoid.monoid:del_change(player, "cmo_tweaks:hide_nametag")
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