return function(deps)
deps = deps or {}
local godData = deps.godData

local GOD_LOOT = godData.devotionPrerequisiteLootNames()
local HERMES_LOOT = { "HermesUpgrade", "ShopHermesUpgrade" }
local HAMMER_LOOT = { "WeaponUpgrade", "WeaponUpgradeDrop" }

return {
    {
        targets = { "Devotion" },
        requirements = {
            {
                kind = "BiomeUseRecord",
                countOf = { "Devotion" },
                comparison = "==",
                value = 0,
                code = "devotion_biome_limit",
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
            {
                kind = "PriorDistinctLootSources",
                sourceValues = GOD_LOOT,
                comparison = ">=",
                value = 2,
                code = "prior_distinct_god_loot",
            },
            {
                kind = "RequiredMinExits",
                value = 2,
                exceptBiomes = { "O" },
                code = "previous_room_exit_count",
            },
            {
                kind = "RunEncounterDepth",
                comparison = ">=",
                value = 7,
                code = "devotion_run_encounter_depth",
            },
            {
                kind = "RequiredMinRoomsSinceEvent",
                event = {
                    kind = "loot",
                    lootType = "Devotion",
                },
                axis = "runDepthCache",
                count = 15,
                code = "devotion_spacing",
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
            {
                kind = "CurrentLootSourcesSeen",
                code = "devotion_sources_not_seen",
            },
        },
    },
    {
        targets = { "SpellDrop" },
        requirements = {
            {
                kind = "RequiredNotInStore",
                name = "SpellDrop",
                code = "spell_shop_conflict",
                related = {
                    { kind = "pendingOffer", name = "SpellDrop" },
                },
            },
            {
                kind = "LootTypeHistory",
                countOf = { "SpellDrop" },
                comparison = "==",
                value = 0,
                code = "spell_drop_limit",
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
        },
    },
    {
        targets = { "TalentDrop", "MinorTalentDrop", "TalentBigDrop" },
        requirements = {
            {
                kind = "RequiredNotInStore",
                name = "TalentDrop",
                code = "talent_shop_conflict",
                related = {
                    { kind = "pendingOffer", name = "TalentDrop" },
                },
            },
            {
                kind = "LootTypeHistory",
                countOf = { "SpellDrop" },
                comparison = ">=",
                value = 1,
                code = "talent_requires_spell",
            },
        },
    },
    {
        targets = { "HermesUpgrade", "ShopHermesUpgrade" },
        requirements = {
            {
                kind = "RequiredNotInStore",
                name = "ShopHermesUpgrade",
                code = "hermes_shop_conflict",
                related = {
                    { kind = "pendingOffer", name = "ShopHermesUpgrade" },
                },
            },
            {
                kind = "BiomeUseRecord",
                countOf = HERMES_LOOT,
                comparison = "==",
                value = 0,
                code = "hermes_biome_limit",
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
            {
                kind = "LootTypeHistory",
                countOf = HERMES_LOOT,
                comparison = "<=",
                value = 1,
                code = "hermes_run_limit",
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
        },
    },
    {
        targets = { "WeaponUpgrade", "WeaponUpgradeDrop" },
        requirements = {
            {
                kind = "RequiredNotInStore",
                name = "WeaponUpgradeDrop",
                code = "weapon_upgrade_shop_conflict",
                related = {
                    { kind = "pendingOffer", name = "WeaponUpgradeDrop" },
                },
            },
            {
                kind = "LootTypeHistory",
                countOf = HAMMER_LOOT,
                comparison = "<=",
                value = 1,
                code = "weapon_upgrade_run_limit",
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
            {
                kind = "Any",
                code = "weapon_upgrade_late_requirement",
                requirements = {
                    {
                        kind = "LootTypeHistory",
                        countOf = HAMMER_LOOT,
                        comparison = "==",
                        value = 0,
                    },
                    {
                        kind = "All",
                        requirements = {
                            {
                                kind = "LootTypeHistory",
                                countOf = HAMMER_LOOT,
                                comparison = "==",
                                value = 1,
                            },
                            {
                                kind = "EnteredBiomes",
                                comparison = ">",
                                value = 2,
                            },
                        },
                    },
                },
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
        },
    },
}
end
