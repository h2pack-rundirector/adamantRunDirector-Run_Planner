local gods = {}

local OLYMPIAN_GODS = {
    {
        key = "AphroditeUpgrade",
        label = "Aphrodite",
        colorKey = "AphroditeVoice",
        color = { 0.98, 0.43, 0.68, 1.0 },
    },
    {
        key = "ApolloUpgrade",
        label = "Apollo",
        colorKey = "ApolloVoice",
        color = { 0.95, 0.78, 0.28, 1.0 },
    },
    {
        key = "AresUpgrade",
        label = "Ares",
        colorKey = "AresVoice",
        color = { 0.86, 0.18, 0.16, 1.0 },
    },
    {
        key = "DemeterUpgrade",
        label = "Demeter",
        colorKey = "DemeterVoice",
        color = { 0.58, 0.82, 0.86, 1.0 },
    },
    {
        key = "HephaestusUpgrade",
        label = "Hephaestus",
        colorKey = "HephaestusVoice",
        color = { 0.88, 0.48, 0.24, 1.0 },
    },
    {
        key = "HestiaUpgrade",
        label = "Hestia",
        colorKey = "HestiaVoice",
        color = { 0.96, 0.36, 0.20, 1.0 },
    },
    {
        key = "HeraUpgrade",
        label = "Hera",
        colorKey = "HeraDamage",
        color = { 0.62, 0.50, 0.95, 1.0 },
    },
    {
        key = "PoseidonUpgrade",
        label = "Poseidon",
        colorKey = "PoseidonVoice",
        color = { 0.22, 0.70, 0.86, 1.0 },
    },
    {
        key = "ZeusUpgrade",
        label = "Zeus",
        colorKey = "ZeusVoice",
        color = { 0.64, 0.72, 1.0, 1.0 },
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
    }
end

local function copyList(source)
    local copy = {}
    for index, item in ipairs(source or {}) do
        copy[index] = copyGod(item)
    end
    return copy
end

function gods.olympian()
    return copyList(OLYMPIAN_GODS)
end

return gods
