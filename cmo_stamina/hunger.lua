local mod_hbhunger = minetest.get_modpath("hbhunger") ~= nil
local mod_mcl_hunger = minetest.get_modpath("mcl_hunger") ~= nil

if not mod_hbhunger and not mod_mcl_hunger then
    local nothing = function() return end
    return nothing
end

local players = {}

local function get_max_hunger()
    if mod_hbhunger then
        return hbhunger.SAT_MAX
    else
        return 20
    end
end

local function deduct_hunger(player, amount)
    local name = player:get_player_name()
    local max = get_max_hunger()
    amount = players[name] + (amount * max)
    local floor = math.floor(amount)
    players[name] = amount - floor
    if floor == 0 then return end
    if mod_hbhunger then
        local current = hbhunger.hunger[name]
        local override = math.max(current - floor, 0)
        hbhunger.hunger[name] = override
    elseif mod_mcl_hunger then
        local current = mcl_hunger.get_hunger(player)
        local override = math.max(current - floor, 0)
        mcl_hunger.set_hunger(player, override)
    end
end

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    players[name] = 0
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    players[name] = nil
end)

return deduct_hunger