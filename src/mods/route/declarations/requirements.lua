local modeledKinds = {
    All = { phases = { "room.generate_next", "reward.offer" }, capacity = "composite" },
    Any = { phases = { "room.generate_next", "reward.offer" }, capacity = "composite" },
    Not = { phases = { "room.generate_next", "reward.offer" }, capacity = "composite" },
    CounterRange = {
        phases = { "room.prepare_encounters", "room.generate_next", "reward.offer" },
        capacity = "static",
    },
    RoomEnteredCount = { phases = { "room.generate_next" }, capacity = "dynamic" },
    RoomCreatedCount = { phases = { "room.generate_next" }, capacity = "dynamic" },
    RequiredMinExits = { phases = { "room.generate_next", "reward.offer" }, capacity = "dynamic" },
    RequiredOfferedPeer = { phases = { "room.generate_next" }, capacity = "dynamic" },
    RequiredNotInStore = { phases = { "reward.offer" }, capacity = "dynamic" },
    LootTypeHistory = { phases = { "reward.offer" }, capacity = "dynamic" },
    ClearedBiomes = { phases = { "reward.offer" }, capacity = "dynamic" },
    EncounterDepth = { phases = { "reward.offer" }, capacity = "dynamic" },
    PriorDistinctLootSources = {
        phases = { "room.generate_next", "reward.offer" },
        capacity = "dynamic",
    },
    RequiredMinRoomsSinceEvent = { phases = { "reward.offer" }, capacity = "dynamic" },
    EnteredKindCount = { phases = { "room.generate_next" }, capacity = "dynamic" },
    ClockworkCapacity = { phases = { "room.generate_next" }, capacity = "dynamic" },
    ClockworkGoalsRemaining = { phases = { "room.generate_next" }, capacity = "dynamic" },
    HubVisitsCompleted = { phases = { "room.generate_next" }, capacity = "dynamic" },
    ClockworkNonGoalLimitReached = { phases = { "room.generate_next" }, capacity = "dynamic" },
    CurrentRoomCreationExclusion = { phases = { "room.generate_next" }, capacity = "dynamic" },
    RecentEncounterPhaseCount = { phases = { "room.generate_next" }, capacity = "dynamic" },
    BiomeRoomCreatedAny = { phases = { "room.generate_next" }, capacity = "dynamic" },
}

local function modeled(kind, phase, values)
    values.kind = kind
    values.phase = phase
    return values
end

return {
    modeledKinds = modeledKinds,
    named = {
        HammerLootRequirements = modeled("All", "reward.offer", {
            requirements = {
                modeled("RequiredNotInStore", "reward.offer", {
                    rewardType = "WeaponUpgradeDrop",
                    code = "hammer_pending_in_shop",
                }),
                modeled("LootTypeHistory", "reward.offer", {
                    rewardTypes = { "WeaponUpgrade" },
                    comparison = "==",
                    value = 0,
                    code = "early_hammer_requires_no_prior_hammer",
                }),
            },
        }),
        LateHammerLootRequirements = modeled("All", "reward.offer", {
            requirements = {
                modeled("RequiredNotInStore", "reward.offer", {
                    rewardType = "WeaponUpgradeDrop",
                    code = "late_hammer_pending_in_shop",
                }),
                modeled("ClearedBiomes", "reward.offer", {
                    comparison = ">",
                    value = 2,
                    code = "late_hammer_requires_cleared_biomes",
                }),
                modeled("LootTypeHistory", "reward.offer", {
                    rewardTypes = { "WeaponUpgrade" },
                    comparison = "==",
                    value = 1,
                    code = "late_hammer_requires_one_prior_hammer",
                }),
            },
        }),
        DevotionLootRequirements = modeled("All", "reward.offer", {
            requirements = {
                modeled("EncounterDepth", "reward.offer", {
                    comparison = ">=",
                    value = 7,
                    code = "devotion_requires_encounter_depth",
                }),
                modeled("CounterRange", "reward.offer", {
                    axis = "biomeEncounterDepth",
                    range = { min = 2 },
                    code = "devotion_requires_biome_encounter_depth",
                }),
                modeled("PriorDistinctLootSources", "reward.offer", {
                    sourceDomain = "OlympianGods",
                    comparison = ">=",
                    value = 2,
                    code = "devotion_requires_prior_gods",
                }),
                modeled("RequiredMinRoomsSinceEvent", "reward.offer", {
                    event = { kind = "reward.acquire", rewardType = "Devotion" },
                    axis = "roomHistoryOrdinal",
                    count = 15,
                    code = "devotion_requires_spacing",
                }),
                modeled("RequiredMinExits", "reward.offer", {
                    count = 2,
                    exceptBiomeKeys = { "O" },
                    code = "devotion_requires_two_exits",
                }),
            },
        }),
    },
}
