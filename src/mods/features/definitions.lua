local definitions = {}

definitions.ordered = {
    "ChaosGate",
    "StygianWell",
    "HermesShrine",
}

definitions.byKey = {
    ChaosGate = {
        key = "ChaosGate",
        label = "Chaos Gate",
        featureKey = "chaos",
        plannedSpacingRooms = 10,
        defaultManagedCount = 1,
        maxManagedCount = 10,
        vanillaNamedRequirement = "NoRecentChaosEncounter",
        suppressesNaturalSpawn = true,
        biomes = {
            F = true,
            G = true,
            N = true,
            P = true,
        },
    },
    StygianWell = {
        key = "StygianWell",
        label = "Stygian Well",
        featureKey = "wellShop",
        plannedSpacingRooms = 4,
        defaultManagedCount = 1,
        maxManagedCount = 10,
        vanillaNamedRequirement = "WellShopRequirements",
        suppressesNaturalSpawn = true,
        biomes = {
            F = true,
            G = true,
            H = true,
            I = true,
        },
    },
    HermesShrine = {
        key = "HermesShrine",
        label = "Hermes Shrine",
        featureKey = "surfaceShop",
        plannedSpacingRooms = 3,
        defaultManagedCount = 1,
        maxManagedCount = 10,
        vanillaNamedRequirement = "SurfaceShopRequirements",
        suppressesNaturalSpawn = true,
        biomes = {
            N = true,
            O = true,
            P = true,
            Q = true,
        },
    },
}

return definitions
