local definitions = {}

definitions.ordered = {
    "StygianWell",
    "HermesShrine",
}

definitions.byKey = {
    StygianWell = {
        key = "StygianWell",
        label = "Stygian Well",
        configLabel = "Configure Stygian Wells",
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
        configLabel = "Configure Hermes Shrines",
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
