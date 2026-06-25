local gods = {}

local OLYMPIAN_GODS = {
    {
        key = "AphroditeUpgrade",
        label = "Aphrodite",
        colorKey = "AphroditeVoice",
        color = { 0.98, 0.43, 0.68, 1.0 },
        devotionPrerequisite = true,
    },
    {
        key = "ApolloUpgrade",
        label = "Apollo",
        colorKey = "ApolloVoice",
        color = { 0.95, 0.78, 0.28, 1.0 },
        devotionPrerequisite = true,
    },
    {
        key = "AresUpgrade",
        label = "Ares",
        colorKey = "AresVoice",
        color = { 0.86, 0.18, 0.16, 1.0 },
        devotionPrerequisite = false,
    },
    {
        key = "DemeterUpgrade",
        label = "Demeter",
        colorKey = "DemeterVoice",
        color = { 0.58, 0.82, 0.86, 1.0 },
        devotionPrerequisite = true,
    },
    {
        key = "HephaestusUpgrade",
        label = "Hephaestus",
        colorKey = "HephaestusVoice",
        color = { 0.88, 0.48, 0.24, 1.0 },
        devotionPrerequisite = true,
    },
    {
        key = "HestiaUpgrade",
        label = "Hestia",
        colorKey = "HestiaVoice",
        color = { 0.96, 0.36, 0.20, 1.0 },
        devotionPrerequisite = true,
    },
    {
        key = "HeraUpgrade",
        label = "Hera",
        colorKey = "HeraDamage",
        color = { 0.62, 0.50, 0.95, 1.0 },
        devotionPrerequisite = true,
    },
    {
        key = "PoseidonUpgrade",
        label = "Poseidon",
        colorKey = "PoseidonVoice",
        color = { 0.22, 0.70, 0.86, 1.0 },
        devotionPrerequisite = true,
    },
    {
        key = "ZeusUpgrade",
        label = "Zeus",
        colorKey = "ZeusVoice",
        color = { 0.64, 0.72, 1.0, 1.0 },
        devotionPrerequisite = true,
    },
}

local function copyColor(color)
    return {
        color[1],
        color[2],
        color[3],
        color[4],
    }
end

local function copyGod(god)
    return {
        key = god.key,
        label = god.label,
        colorKey = god.colorKey,
        color = copyColor(god.color),
        devotionPrerequisite = god.devotionPrerequisite == true,
    }
end

local function copyGodList(source)
    local copy = {}
    for index, item in ipairs(source or {}) do
        copy[index] = copyGod(item)
    end
    return copy
end

local function copyKeys(source, predicate)
    local copy = {}
    for _, god in ipairs(source or {}) do
        if predicate == nil or predicate(god) then
            copy[#copy + 1] = god.key
        end
    end
    return copy
end

function gods.olympian()
    return copyGodList(OLYMPIAN_GODS)
end

function gods.godLootNames()
    return copyKeys(OLYMPIAN_GODS)
end

function gods.devotionPrerequisiteLootNames()
    return copyKeys(OLYMPIAN_GODS, function(god)
        return god.devotionPrerequisite == true
    end)
end

return gods
