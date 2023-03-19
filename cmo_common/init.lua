if cmo == nil then cmo = {} end

-- transform absolute velocity into relation to look direction (in radians)
-- leaves y-axis untouched
cmo.get_relative_vector = function(direction, reference)
    local axis = vector.new({ x = 0, y = 1, z = 0 })
    local direction_horizontal = vector.new({ x = direction.x, y = 0, z = direction.z })
    local relative_horizontal = vector.rotate_around_axis(direction_horizontal, axis, -reference)
    local relative = vector.new({ x = relative_horizontal.x, y = direction.y, z = relative_horizontal.z })
    return relative
end

cmo.get_absolute_vector = function(direction, reference)
    return cmo.get_relative_vector(direction, -reference)
end