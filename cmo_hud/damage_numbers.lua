local y_scale = 72
local x_scale = 50

local DEFAULT_COLOR = "#c40b0b"
local ENTITY_COLOR = "#ba4a28"
local CRIT_COLOR = "#eac715"

local function generate_texture(num, color)
    num = math.round(num)

    -- split number into characters
    local tab = {}
    if num == 0 then
        table.insert(tab, 0)
    else
        while num > 0 do
            table.insert(tab, 1, num % 10)
            num = math.floor(num / 10)
        end
    end

    -- build texture
    local width = x_scale * #tab
    local base = "blank.png^[resize:" .. width .. "x" .. y_scale
    local t = base .. "^[combine:" .. width .. "x" .. y_scale
    for i, c in ipairs(tab) do
        local letter = "cmo_" .. c .. ".png"
        t = t .. ":" .. ((i - 1) * x_scale) .. ",0=" .. letter
    end
    t = t .. "^[invert:rgb^[colorize:" .. color .. ":255"
    return t
end

local function pick_color(reason)
    if reason.type == "punch_entity" then return ENTITY_COLOR end
    if reason.type ~= "punch" and reason.type ~= "set_hp" then return DEFAULT_COLOR end
    if reason.type == "set_hp" and reason.subtype ~= "punch_delay" then return DEFAULT_COLOR end
    if reason.object == nil or not reason.object:is_player() then return DEFAULT_COLOR end
    local itemstack = reason.object:get_wielded_item()
    local meta = itemstack:get_meta()
    local override = tonumber(meta:get_string("cmo_attacks:modifier")) or 1
    if override <= 1 then return DEFAULT_COLOR end
    return CRIT_COLOR
end

local function spawn_particle(object, hp_change, reason)
    if object == nil then return end
    if hp_change == nil or hp_change >= 0 then return end
    local pos = object:get_pos()
    if pos == nil then return end

    -- offest particle towards attacker
    if reason.object ~= nil then
        local attackdir = vector.normalize(reason.object:get_pos() - pos)
        pos = pos + 0.2 * attackdir
    end

    -- spawn at head
    local properties = object:get_properties()
    local height = properties.collisionbox[5] + 0.5
    pos.y = pos.y + height

    local color = pick_color(reason)
    local texture = generate_texture(-hp_change, color)

    minetest.add_particle({
		pos = pos,
		velocity = { x = 0, y = 2, z = 0 },
        acceleration = { x = 0, y = -2, z = 0 },
		expirationtime = 2,
		size = 2,
		collisiondetection = false,
		vertical = false,
		texture = texture,
		glow = 30,
	})
end

minetest.register_on_player_hpchange(spawn_particle, false)

local function patch_entity(entitydef)
    local on_punch = entitydef.on_punch
    entitydef.on_punch = function(self, hitter, ...)
        if self.health ~= nil then
            local health = self.health
            -- wait until hit has been processed
            minetest.after(0, function()
                -- stop if entity has been removed
                if not self or not self.health then return end
                -- compare health after processing hit
                local hp_change = self.health - health
                local reason = {
                    type = "punch_entity",
                    object = hitter
                }
                spawn_particle(self.object, hp_change, reason)
            end)
        end
        return on_punch(self, hitter, ...)
    end
end

minetest.after(0, function()
    for _, entity in pairs(minetest.registered_entities) do
        if entity.on_punch ~= nil then
            patch_entity(entity)
        end
    end
end)