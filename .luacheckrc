
std = "luajit+minetest"
ignore = { "212" }

files[".luacheckrc"].std = "min+luacheck"
files["cmo_dodge"].std = std .. "+dodge_deps"

stds.luacheck = {}
stds.luacheck.globals = {
    "files",
    "ignore",
    "std",
    "stds"
}

stds.minetest = {}
stds.minetest.read_globals = {
    "DIR_DELIM",
    "minetest",
    "dump",
    "vector",
    "VoxelManip",
    "VoxelArea",
    "PseudoRandom",
    "PcgRandom",
    "ItemStack",
    "Settings",
    "unpack",
    "assert",
    "S",
    table = { fields = { "copy", "indexof" } },
    math = { fields = { "sign" } }
}

stds.dodge_deps = {}
stds.dodge_deps.read_globals = {
    "controls",
    "hud_timers",
    "unified_stamina"
}
