local biomes = {}

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

local function defaultImporter(path)
    return import(path)
end

local function resolveDefinition(imported, importer, deps)
    if type(imported) == "function" then
        return imported(importer, deps)
    end
    return imported
end

function biomes.load(importer)
    importer = importer or defaultImporter

    local rewards = importer("mods/biomes/reward_contexts.lua")(importer)
    local gods = importer("mods/data/gods.lua")
    local npcs = importer("mods/npcs/definitions.lua")
    local features = importer("mods/features/definitions.lua")
    local routes = importer("mods/data/routes.lua").load()
    local biomeParser = importer("mods/biomes/parser.lua").create({
        rewards = rewards,
        routeRules = importer("mods/biomes/declaration_rules.lua"),
    })
    local declarationDeps = biomeParser.declarationDeps()
    local ordered = {}
    local lookup = {}

    for _, importPath in ipairs(BIOME_IMPORTS) do
        local definition = biomeParser.normalize(resolveDefinition(importer(importPath), importer, declarationDeps))
        ordered[#ordered + 1] = definition
        lookup[definition.key] = definition
    end

    return {
        ordered = ordered,
        lookup = lookup,
        routes = routes,
        gods = gods.olympian(),
        npcs = npcs,
        features = features,
        rewardTypes = rewards.rewardTypeMetadata(),
    }
end

return biomes
