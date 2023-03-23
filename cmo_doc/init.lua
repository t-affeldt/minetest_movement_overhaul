local mod_doc = minetest.get_modpath("doc") ~= nil

if not mod_doc then return end

local modname = minetest.get_current_modname()
local document_folder = minetest.get_modpath(modname) .. DIR_DELIM .. "docs"

doc.add_category("cmo_doc", {
    name = "Combat & Movement",
    description = "All of the changes made by the Combat & Movement Overhaul mod",
    build_formspec = doc.entry_builders.text
})

local documents = minetest.get_dir_list(document_folder, false)
for _, document in ipairs(documents) do
    local id = document:gsub("%.txt$", "")
    local file = io.open(document_folder .. DIR_DELIM .. document, "r")
    local name = file:read("*l"):gsub("^%# ", "")
    local data = file:read("*all")
    doc.add_entry("cmo_doc", id, { name = name, data = data })
end