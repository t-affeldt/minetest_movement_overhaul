if XEnchanting == nil then return end

local set_enchanted_tool = XEnchanting.set_enchanted_tool
XEnchanting.set_enchanted_tool = function(self, pos, itemstack, ...)
    -- reset damage groups before enchanting
    itemstack = cmo.clean_itemstack(itemstack)
    return set_enchanted_tool(self, pos, itemstack, ...)
end