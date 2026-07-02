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
                message = "Trial can only be planned once per biome",
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
                message = "Trial requires at least two prior planned god rewards",
            },
            {
                kind = "RequiredMinExits",
                value = 2,
                exceptBiomes = { "O" },
                code = "previous_room_exit_count",
                message = "Trial requires a two-exit previous room",
            },
            {
                kind = "RunEncounterDepth",
                comparison = ">=",
                value = 7,
                code = "devotion_run_encounter_depth",
                message = "Trial requires at least 7 prior encounters in this route",
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
                message = "Trial requires 15 rooms since the previous Trial",
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
            {
                kind = "CurrentLootSourcesSeen",
                code = "devotion_sources_not_seen",
                message = "Trial gods must be planned earlier in the route",
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
                message = "Selene's Gift cannot be planned after a shop Selene's Gift offer",
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
                message = "Selene's Gift is already planned earlier in this route",
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
                message = "Path of Stars cannot be planned after a shop Path of Stars offer",
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
                message = "Path of Stars rewards require an earlier Selene's Gift",
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
                message = "Hermes cannot be planned after a shop Hermes offer",
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
                message = "Hermes can only be planned once per biome",
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
                message = "Hermes can only be planned twice per route",
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
                message = "Hammer cannot be planned after a shop Hammer offer",
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
                message = "Only two Hammers can be planned in one route",
                related = {
                    { kind = "lastMatchingLoot" },
                },
            },
            {
                kind = "Any",
                code = "weapon_upgrade_late_requirement",
                message = "The second Hammer cannot be planned before the third biome",
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
