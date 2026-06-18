local definitions = {}

definitions.ordered = {
    "ChaosGate",
}

definitions.byKey = {
    ChaosGate = {
        key = "ChaosGate",
        label = "Chaos",
        featureKey = "chaos",
        plannedSpacingRooms = 10,
        vanillaNamedRequirement = "NoRecentChaosEncounter",
        suppressesNaturalSpawn = true,
        biomes = {
            F = true,
            G = true,
            N = true,
            P = true,
        },
    },
}

return definitions
