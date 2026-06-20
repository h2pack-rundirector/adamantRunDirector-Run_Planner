return {
    {
        targets = {
            "SpellDrop",
        },
        countsAs = {
            {
                key = "spell",
                scope = "route",
            },
        },
        requirements = {
            {
                kind = "maxCount",
                counter = "spell",
                scope = "route",
                max = 1,
                code = "spell_drop_limit",
                message = "Selene's Gift is already planned earlier in this route",
            },
        },
    },
    {
        targets = {
            "TalentDrop",
            "MinorTalentDrop",
            "TalentBigDrop",
        },
        countsAs = {
            {
                key = "talent",
                scope = "route",
            },
        },
        requirements = {
            {
                kind = "minPriorCount",
                counter = "spell",
                scope = "route",
                min = 1,
                code = "talent_requires_spell",
                message = "Path of Stars rewards require an earlier Selene's Gift",
            },
        },
    },
    {
        targets = {
            "TalentDrop",
            "MinorTalentDrop",
            "TalentBigDrop",
        },
        requirements = {
            {
                kind = "previousShopExclusion",
                rewards = {
                    "TalentDrop",
                },
                code = "talent_shop_conflict",
                message = "Path of Stars cannot be planned after a shop Path of Stars offer",
            },
        },
    },
    {
        targets = {
            "HermesUpgrade",
            "ShopHermesUpgrade",
        },
        countsAs = {
            {
                key = "hermes",
                scope = "route",
            },
            {
                key = "hermes",
                scope = "biome",
            },
        },
        requirements = {
            {
                kind = "maxCount",
                counter = "hermes",
                scope = "biome",
                max = 1,
                code = "hermes_biome_limit",
                message = "Hermes can only be planned once per biome",
            },
            {
                kind = "maxCount",
                counter = "hermes",
                scope = "route",
                max = 2,
                code = "hermes_run_limit",
                message = "Hermes can only be planned twice per route",
            },
        },
    },
    {
        targets = {
            "WeaponUpgrade",
        },
        requirements = {
            {
                kind = "previousShopExclusion",
                rewards = {
                    "WeaponUpgradeDrop",
                },
                code = "weapon_upgrade_shop_conflict",
                message = "Hammer cannot be planned after a shop Hammer offer",
            },
        },
    },
    {
        targets = {
            "WeaponUpgrade",
            "WeaponUpgradeDrop",
        },
        countsAs = {
            {
                key = "hammer",
                scope = "route",
            },
        },
        requirements = {
            {
                kind = "maxCount",
                counter = "hammer",
                scope = "route",
                max = 2,
                code = "weapon_upgrade_run_limit",
                message = "Only two Hammers can be planned in one route",
            },
            {
                kind = "phase",
                counter = "hammer",
                scope = "route",
                phases = {
                    {
                        priorCount = 0,
                    },
                    {
                        priorCount = 1,
                        routeBiomeIndex = {
                            min = 3,
                        },
                    },
                },
                code = "weapon_upgrade_late_requirement",
                message = "The second Hammer cannot be planned before the third biome",
            },
        },
    },
}
