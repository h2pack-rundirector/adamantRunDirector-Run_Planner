local biomes = {}

local BIOME_IMPORTS = {
    "mods/data/biomes/f_erebus.lua",
    "mods/data/biomes/g_oceanus.lua",
    "mods/data/biomes/h_fields.lua",
    "mods/data/biomes/i_tartarus.lua",
    "mods/data/biomes/n_ephyra.lua",
    "mods/data/biomes/o_thessaly.lua",
    "mods/data/biomes/p_olympus.lua",
    "mods/data/biomes/q_summit.lua",
}

local function defaultImporter(path)
    return import(path)
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        lookup[item.key] = item
    end
    return lookup
end

local function normalize(definition)
    definition.rolesByKey = indexByKey(definition.roles)
    definition.slotLayout.special = definition.slotLayout.special or {}
    return definition
end

local function resolveDefinition(imported, importer)
    if type(imported) == "function" then
        return imported(importer)
    end
    return imported
end

function biomes.load(importer)
    importer = importer or defaultImporter

    local rewards = importer("mods/data/rewards.lua")(importer)
    local ordered = {}
    local lookup = {}

    for _, importPath in ipairs(BIOME_IMPORTS) do
        local definition = normalize(resolveDefinition(importer(importPath), importer))
        ordered[#ordered + 1] = definition
        lookup[definition.key] = definition
    end

    return {
        ordered = ordered,
        lookup = lookup,
        rewardTypes = rewards.rewardTypeMetadata(),
    }
end

return biomes
