local godSources = import("mods/declarations/god_sources.lua")

return {
    HammerLootRequirements = {
        kind = "All",
        requirements = {
            {
                kind = "RequiredNotInStore",
                name = "WeaponUpgradeDrop",
                code = "hammer_pending_in_shop",
                presentation = "invalid",
            },
            {
                kind = "LootTypeHistory",
                countOf = { "WeaponUpgrade" },
                comparison = "==",
                value = 0,
                code = "early_hammer_requires_no_prior_hammer",
                presentation = "invalid",
            },
        },
    },

    LateHammerLootRequirements = {
        kind = "All",
        requirements = {
            {
                kind = "RequiredNotInStore",
                name = "WeaponUpgradeDrop",
                code = "late_hammer_pending_in_shop",
                presentation = "invalid",
            },
            {
                kind = "ClearedBiomes",
                comparison = ">",
                value = 2,
                code = "late_hammer_requires_cleared_biomes",
                presentation = "invalid",
            },
            {
                kind = "LootTypeHistory",
                countOf = { "WeaponUpgrade" },
                comparison = "==",
                value = 1,
                code = "late_hammer_requires_one_prior_hammer",
                presentation = "invalid",
            },
        },
    },

    DevotionLootRequirements = {
        kind = "All",
        requirements = {
            {
                kind = "EncounterDepth",
                comparison = ">=",
                value = 7,
                code = "devotion_requires_encounter_depth",
                presentation = "invalid",
            },
            {
                kind = "BiomeEncounterDepth",
                comparison = ">=",
                value = 2,
                code = "devotion_requires_biome_encounter_depth",
                presentation = "invalid",
            },
            {
                kind = "PriorDistinctLootSources",
                sourceValues = godSources.boonKeys,
                comparison = ">=",
                value = 2,
                code = "devotion_requires_prior_gods",
                presentation = "invalid",
            },
            {
                kind = "RequiredMinRoomsSinceEvent",
                event = {
                    kind = "reward.acquire",
                    rewardType = "Devotion",
                },
                axis = "RoomHistoryOrdinal",
                count = 15,
                code = "devotion_requires_trial_spacing",
                presentation = "invalid",
            },
            {
                kind = "RequiredMinExits",
                count = 2,
                code = "devotion_requires_two_exits",
                presentation = "invalid",
            },
        },
    },
}
