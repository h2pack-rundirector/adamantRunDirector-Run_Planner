local OLYMPIAN_BOON_SOURCES = {
    {
        key = "AphroditeUpgrade",
        label = "Aphrodite",
    },
    {
        key = "ApolloUpgrade",
        label = "Apollo",
    },
    {
        key = "AresUpgrade",
        label = "Ares",
    },
    {
        key = "DemeterUpgrade",
        label = "Demeter",
    },
    {
        key = "HephaestusUpgrade",
        label = "Hephaestus",
    },
    {
        key = "HestiaUpgrade",
        label = "Hestia",
    },
    {
        key = "HeraUpgrade",
        label = "Hera",
    },
    {
        key = "PoseidonUpgrade",
        label = "Poseidon",
    },
    {
        key = "ZeusUpgrade",
        label = "Zeus",
    },
}

local function keysOf(sources)
    local keys = {}
    for index, source in ipairs(sources) do
        keys[index] = source.key
    end
    return keys
end

return {
    boon = OLYMPIAN_BOON_SOURCES,
    boonKeys = keysOf(OLYMPIAN_BOON_SOURCES),
}
