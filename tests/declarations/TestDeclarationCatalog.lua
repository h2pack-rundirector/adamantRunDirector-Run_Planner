-- luacheck: globals TestDeclarationCatalog

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestDeclarationCatalog = {}

function TestDeclarationCatalog.testCatalogLoadsRouteOrderAndMinimalFDeclarations()
    h.withTestImport(function()
        local catalog = h.testImport("mods/data.lua").loadCatalog()

        lu.assertEquals(catalog.routes.ordered[1].key, "Underworld")
        lu.assertEquals(catalog.routes.ordered[1].biomeKeys, { "F", "G", "H", "I" })
        lu.assertEquals(catalog.routes.ordered[2].key, "Surface")
        lu.assertEquals(catalog.routes.ordered[2].biomeKeys, { "N", "O", "P", "Q" })

        local f = catalog.biomes.lookup.F
        lu.assertNotNil(f)
        lu.assertEquals(f.label, "Erebus")
        lu.assertEquals(f.structure.kind, "linear")
        lu.assertEquals(f.structure.startRoomKey, "F_Opening01")
        lu.assertEquals(f.structure.terminal.prebossRoomKey, "F_PreBoss01")

        local opening = f.rooms.lookup.F_Opening01
        lu.assertEquals(opening.kind, "Opening")
        lu.assertEquals(#opening.exits, 1)

        local combat = f.rooms.lookup.F_Combat02
        lu.assertEquals(combat.kind, "Combat")
        lu.assertEquals(combat.roomTemplate, "StandardCombat")
        lu.assertEquals(#combat.exits, 2)
        lu.assertEquals(combat.eligibility.kind, "BiomeEncounterDepth")

        local shop = f.rooms.lookup.F_Shop01
        lu.assertEquals(shop.offerProfile, "WorldShop")
        lu.assertEquals(shop.force.kind, "All")

        local preboss = f.rooms.lookup.F_PreBoss01
        lu.assertTrue(preboss.terminal)
        lu.assertEquals(#preboss.exits, 0)
    end)
end

function TestDeclarationCatalog.testRewardBagsRemainCountedAndStoresAreDerived()
    h.withTestImport(function()
        local catalog = h.testImport("mods/data.lua").loadCatalog()
        local runProgress = catalog.rewards.bags.RunProgress

        lu.assertEquals(runProgress.entries[4].rewardType, "WeaponUpgrade")
        lu.assertEquals(runProgress.entries[4].requirements.named, "HammerLootRequirements")
        lu.assertEquals(runProgress.entries[5].rewardType, "WeaponUpgrade")
        lu.assertEquals(runProgress.entries[5].requirements.named, "LateHammerLootRequirements")

        lu.assertEquals(catalog.rewards.stores.RunProgress.options, {
            "Boon",
            "HermesUpgrade",
            "WeaponUpgrade",
            "MaxHealthDrop",
            "MaxManaDrop",
            "RoomMoneyDrop",
        })
    end)
end

function TestDeclarationCatalog.testNamedRequirementRegistryUsesExplicitPredicateShape()
    h.withTestImport(function()
        local catalog = h.testImport("mods/data.lua").loadCatalog()
        local lateHammer = catalog.requirements.LateHammerLootRequirements

        lu.assertEquals(lateHammer.kind, "All")
        lu.assertEquals(lateHammer.requirements[2].kind, "ClearedBiomes")
        lu.assertEquals(lateHammer.requirements[2].comparison, ">")
        lu.assertEquals(lateHammer.requirements[3].kind, "LootTypeHistory")
        lu.assertEquals(lateHammer.requirements[3].countOf, { "WeaponUpgrade" })
    end)
end

function TestDeclarationCatalog.testLoaderDoesNotMutateRawDeclarationTables()
    h.withTestImport(function()
        local loader = h.testImport("mods/declarations/loader.lua")
        local rawBiomes = h.testImport("mods/declarations/biomes/init.lua")
        local rawRewards = h.testImport("mods/declarations/rewards.lua")

        local catalog = loader.load({
            biomes = rawBiomes,
            rewards = rawRewards,
        })

        lu.assertNotNil(catalog.biomes.lookup.F.rooms.lookup.F_Opening01)
        lu.assertNil(rawBiomes[1].rooms.lookup)
        lu.assertNil(rawRewards.stores)
    end)
end

function TestDeclarationCatalog.testLoaderRejectsUnknownRequirementKinds()
    h.withTestImport(function()
        local loader = h.testImport("mods/declarations/loader.lua")
        local ok, err = pcall(function()
            loader.load({
                routes = {
                    {
                        key = "Underworld",
                        label = "Underworld",
                        biomeKeys = { "F" },
                    },
                },
                requirements = {
                    BadRequirement = {
                        kind = "NotARealPredicate",
                    },
                },
                rewards = {
                    primitives = {},
                    bags = {},
                    shops = {},
                },
                biomes = {},
            })
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "unknown requirement kind 'NotARealPredicate'")
    end)
end
