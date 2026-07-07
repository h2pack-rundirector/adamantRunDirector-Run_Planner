-- luacheck: globals TestDeclarationCatalog

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestDeclarationCatalog = {}

local function assertEligibility(requirement, comparison, value, code)
    lu.assertEquals(requirement, {
        kind = "BiomeEncounterDepth",
        comparison = comparison,
        value = value,
        code = code,
        presentation = "hide",
    })
end

function TestDeclarationCatalog.testCatalogLoadsRouteOrderAndMinimalFDeclarations()
    h.withTestImport(function()
        local catalog = h.testImport("mods/data.lua").loadCatalog()

        lu.assertEquals(catalog.routes.ordered[1].key, "Underworld")
        lu.assertEquals(catalog.routes.ordered[1].biomeKeys, { "F", "G", "H", "I" })
        lu.assertEquals(catalog.routes.ordered[1].implementedBiomeKeys, { "F" })
        lu.assertEquals(catalog.routes.ordered[1].missingBiomeKeys, { "G", "H", "I" })
        lu.assertEquals(catalog.routes.ordered[2].key, "Surface")
        lu.assertEquals(catalog.routes.ordered[2].biomeKeys, { "N", "O", "P", "Q" })
        lu.assertEquals(catalog.routes.ordered[2].implementedBiomeKeys, {})
        lu.assertEquals(catalog.routes.ordered[2].missingBiomeKeys, { "N", "O", "P", "Q" })

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
        lu.assertEquals(combat.offerProfile, "RunProgressMajorMinor")

        assertEligibility(f.rooms.lookup.F_Combat03.eligibility, "<=", 5, "f_combat03_late")
        assertEligibility(f.rooms.lookup.F_Combat05.eligibility, ">=", 5, "f_combat05_early")
        lu.assertEquals(f.rooms.lookup.F_Combat08.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat08.exits, 2)
        assertEligibility(f.rooms.lookup.F_Combat08.eligibility, "<=", 5, "f_combat08_late")
        lu.assertEquals(f.rooms.lookup.F_Combat09.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat09.exits, 1)
        assertEligibility(f.rooms.lookup.F_Combat09.eligibility, "<=", 4, "f_combat09_late")
        lu.assertEquals(f.rooms.lookup.F_Combat10.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat10.exits, 1)
        assertEligibility(f.rooms.lookup.F_Combat10.eligibility, "<=", 5, "f_combat10_late")
        lu.assertEquals(f.rooms.lookup.F_Combat11.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat11.exits, 2)
        assertEligibility(f.rooms.lookup.F_Combat11.eligibility, ">=", 5, "f_combat11_early")
        lu.assertEquals(f.rooms.lookup.F_Combat18.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat18.exits, 2)
        assertEligibility(f.rooms.lookup.F_Combat18.eligibility, ">=", 5, "f_combat18_early")
        lu.assertEquals(f.rooms.lookup.F_Combat19.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat19.exits, 2)
        assertEligibility(f.rooms.lookup.F_Combat19.eligibility, "<=", 5, "f_combat19_late")
        lu.assertEquals(f.rooms.lookup.F_Combat20.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat20.exits, 2)
        assertEligibility(f.rooms.lookup.F_Combat20.eligibility, ">=", 5, "f_combat20_early")
        lu.assertEquals(f.rooms.lookup.F_Combat21.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat21.exits, 2)
        assertEligibility(f.rooms.lookup.F_Combat21.eligibility, "<=", 5, "f_combat21_late")
        lu.assertEquals(f.rooms.lookup.F_Combat22.kind, "Combat")
        lu.assertEquals(#f.rooms.lookup.F_Combat22.exits, 2)
        assertEligibility(f.rooms.lookup.F_Combat22.eligibility, "<=", 5, "f_combat22_late")

        local reprieve = f.rooms.lookup.F_Reprieve01
        lu.assertEquals(reprieve.kind, "Reprieve")
        lu.assertEquals(reprieve.roomTemplate, "Fountain")
        lu.assertEquals(#reprieve.exits, 2)
        lu.assertEquals(reprieve.counters.biomeEncounterDepthCost, 0)

        local story = f.rooms.lookup.F_Story01
        lu.assertEquals(story.kind, "Story")
        lu.assertEquals(story.roomTemplate, "Story")
        lu.assertEquals(#story.exits, 2)
        lu.assertEquals(story.eligibility.kind, "All")
        lu.assertEquals(story.eligibility.requirements[1], {
            kind = "BiomeDepthCache",
            comparison = ">=",
            value = 4,
            code = "f_story_arachne_too_early",
            presentation = "invalid",
        })
        lu.assertEquals(story.eligibility.requirements[2], {
            kind = "BiomeDepthCache",
            comparison = "<=",
            value = 8,
            code = "f_story_arachne_too_late",
            presentation = "invalid",
        })
        lu.assertEquals(story.caps.maxCreationsThisRun, 1)
        lu.assertNil(story.force)

        local shop = f.rooms.lookup.F_Shop01
        lu.assertEquals(shop.offerProfile, "WorldShop")
        lu.assertEquals(shop.eligibility.kind, "All")
        lu.assertEquals(shop.force, {
            kind = "BiomeDepthWindow",
            axis = "BiomeDepthCache",
            start = 4,
            deadline = 6,
        })

        local preboss = f.rooms.lookup.F_PreBoss01
        lu.assertTrue(preboss.terminal)
        lu.assertEquals(#preboss.exits, 0)
        lu.assertEquals(preboss.force, {
            kind = "BiomeDepthWindow",
            axis = "BiomeDepthCache",
            start = 10,
            deadline = 10,
        })
    end)
end

function TestDeclarationCatalog.testRoomTemplatesAndOfferProfilesAreExplicitDeclarations()
    h.withTestImport(function()
        local catalog = h.testImport("mods/data.lua").loadCatalog()

        lu.assertEquals(catalog.roomTemplates.StandardCombat.roomKinds, { "Combat" })
        lu.assertTrue(catalog.roomTemplates.StandardCombat.roomKindSet.Combat)
        lu.assertEquals(catalog.roomTemplates.Fountain.roomKinds, { "Reprieve" })
        lu.assertTrue(catalog.roomTemplates.Fountain.roomKindSet.Reprieve)
        lu.assertEquals(catalog.roomTemplates.Story.roomKinds, { "Story" })
        lu.assertTrue(catalog.roomTemplates.Story.roomKindSet.Story)

        local roomRewardProfile = catalog.offerProfiles.RunProgressMajorMinor
        lu.assertEquals(roomRewardProfile.kind, "storeChoice")
        lu.assertEquals(roomRewardProfile.stores, { "RunProgress", "MetaProgress" })

        local prebossProfile = catalog.offerProfiles.PrebossShopOrFreeReward
        lu.assertEquals(prebossProfile.kind, "branch")
        lu.assertEquals(prebossProfile.branches[1].offerProfile, "WorldShop")
        lu.assertEquals(prebossProfile.branches[2].stores, { "RunProgress", "MetaProgress" })
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
            "Devotion",
            "MaxHealthDrop",
            "MaxManaDrop",
            "RoomMoneyDrop",
        })
        lu.assertEquals(catalog.rewards.sources.boon.ordered[1].key, "AphroditeUpgrade")
        lu.assertEquals(catalog.rewards.sources.boon.lookup.ZeusUpgrade.label, "Zeus")
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

        local devotion = catalog.requirements.DevotionLootRequirements
        lu.assertEquals(devotion.kind, "All")
        lu.assertEquals(devotion.requirements[1].kind, "EncounterDepth")
        lu.assertEquals(devotion.requirements[1].comparison, ">=")
        lu.assertEquals(devotion.requirements[1].value, 7)
        lu.assertEquals(devotion.requirements[2].kind, "BiomeEncounterDepth")
        lu.assertEquals(devotion.requirements[3].kind, "PriorDistinctLootSources")
        lu.assertEquals(devotion.requirements[3].sourceValues[1], "AphroditeUpgrade")
        lu.assertEquals(devotion.requirements[4].kind, "RequiredMinRoomsSinceEvent")
        lu.assertEquals(devotion.requirements[4].axis, "RoomHistoryOrdinal")
        lu.assertEquals(devotion.requirements[4].count, 15)
        lu.assertEquals(devotion.requirements[5].kind, "RequiredMinExits")
        lu.assertEquals(devotion.requirements[5].count, 2)
    end)
end

function TestDeclarationCatalog.testLoaderDoesNotMutateRawDeclarationTables()
    h.withTestImport(function()
        local loader = h.testImport("mods/declarations/loader.lua")
        local rawBiomes = h.testImport("mods/declarations/biomes/init.lua")
        local rawRewards = h.testImport("mods/declarations/rewards.lua")
        local rawRoomTemplates = h.testImport("mods/declarations/room_templates.lua")

        local catalog = loader.load({
            biomes = rawBiomes,
            rewards = rawRewards,
            roomTemplates = rawRoomTemplates,
        })

        lu.assertNotNil(catalog.biomes.lookup.F.rooms.lookup.F_Opening01)
        lu.assertNil(rawBiomes[1].rooms.lookup)
        lu.assertNil(rawRewards.stores)
        lu.assertNil(rawRoomTemplates.StandardCombat.roomKindSet)
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

function TestDeclarationCatalog.testLoaderRejectsUnknownRoomTemplate()
    h.withTestImport(function()
        local loader = h.testImport("mods/declarations/loader.lua")
        local biomes = h.testImport("mods/declarations/biomes/init.lua")

        biomes[1].rooms[1].roomTemplate = "MissingTemplate"

        local ok, err = pcall(function()
            loader.load({
                biomes = biomes,
            })
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "unknown room template 'MissingTemplate'")
    end)
end

function TestDeclarationCatalog.testLoaderRejectsUnknownOfferProfile()
    h.withTestImport(function()
        local loader = h.testImport("mods/declarations/loader.lua")
        local biomes = h.testImport("mods/declarations/biomes/init.lua")

        biomes[1].rooms[2].offerProfile = "MissingOfferProfile"

        local ok, err = pcall(function()
            loader.load({
                biomes = biomes,
            })
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "unknown offer profile 'MissingOfferProfile'")
    end)
end

function TestDeclarationCatalog.testLoaderRejectsImplementedBiomeForUnknownRoute()
    h.withTestImport(function()
        local loader = h.testImport("mods/declarations/loader.lua")
        local biomes = h.testImport("mods/declarations/biomes/init.lua")

        biomes[1].routeKey = "MissingRoute"

        local ok, err = pcall(function()
            loader.load({
                biomes = biomes,
            })
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "unknown route 'MissingRoute'")
    end)
end

function TestDeclarationCatalog.testLoaderRejectsImplementedBiomeOutsideRouteOrder()
    h.withTestImport(function()
        local loader = h.testImport("mods/declarations/loader.lua")
        local biomes = h.testImport("mods/declarations/biomes/init.lua")

        biomes[1].key = "X"

        local ok, err = pcall(function()
            loader.load({
                biomes = biomes,
            })
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "biome 'X' is not in route 'Underworld'")
    end)
end
