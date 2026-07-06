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
}
