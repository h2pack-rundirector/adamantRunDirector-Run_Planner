return {
    named = {
        HammerLootRequirements = {
            kind = "All",
            requirements = {
                {
                    kind = "RequiredNotInStore",
                    rewardType = "WeaponUpgradeDrop",
                    code = "reward_pending_in_store",
                },
                {
                    kind = "LootTypeHistory",
                    rewardTypes = { "WeaponUpgrade" },
                    comparison = "==",
                    value = 0,
                    code = "prior_reward_count_mismatch",
                },
            },
        },
        LateHammerLootRequirements = {
            kind = "All",
            requirements = {
                {
                    kind = "RequiredNotInStore",
                    rewardType = "WeaponUpgradeDrop",
                    code = "reward_pending_in_store",
                },
                {
                    kind = "ClearedBiomes",
                    comparison = ">",
                    value = 2,
                    code = "cleared_biome_count_mismatch",
                },
                {
                    kind = "LootTypeHistory",
                    rewardTypes = { "WeaponUpgrade" },
                    comparison = "==",
                    value = 1,
                    code = "prior_reward_count_mismatch",
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
                    code = "encounter_depth_count_mismatch",
                },
                {
                    kind = "CounterRange",
                    axis = "biomeEncounterDepth",
                    range = { min = 2 },
                    code = "biome_encounter_depth_out_of_range",
                },
                {
                    kind = "PriorDistinctLootSources",
                    sourceDomain = "OlympianGods",
                    comparison = ">=",
                    value = 2,
                    code = "distinct_loot_source_count_mismatch",
                },
                {
                    kind = "RequiredMinRoomsSinceEvent",
                    event = { kind = "reward.acquire", rewardType = "Devotion" },
                    axis = "roomHistoryOrdinal",
                    count = 15,
                    code = "reward_spacing_too_short",
                },
                {
                    kind = "RequiredMinExits",
                    count = 2,
                    code = "insufficient_exits",
                },
            },
        },
    },
}
