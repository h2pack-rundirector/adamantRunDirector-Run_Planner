local assembly = {}

local BIOME_IMPORTS = {
    "mods/biomes/declarations/f_erebus.lua",
    "mods/biomes/declarations/g_oceanus.lua",
    "mods/biomes/declarations/h_fields.lua",
    "mods/biomes/declarations/i_tartarus.lua",
    "mods/biomes/declarations/n_ephyra.lua",
    "mods/biomes/declarations/o_thessaly.lua",
    "mods/biomes/declarations/p_olympus.lua",
    "mods/biomes/declarations/q_summit.lua",
}

function assembly.load(opts)
    opts = opts or {}

    local biomeParser = import("mods/biomes/parser.lua").create({
        rewards = opts.rewardSurfaces,
        routeRules = opts.routeRules,
    })
    local declarationDeps = biomeParser.declarationDeps()
    local ordered = {}
    local lookup = {}

    for _, importPath in ipairs(BIOME_IMPORTS) do
        local definition = biomeParser.normalize(import(importPath, nil, declarationDeps))
        ordered[#ordered + 1] = definition
        lookup[definition.key] = definition
    end

    return {
        ordered = ordered,
        lookup = lookup,
    }
end

return assembly
