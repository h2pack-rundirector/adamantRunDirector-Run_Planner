local lu = require("luaunit")
local h = require("tests.support.control_harness")

local historySystem = h.withTestImport(function()
    return h.testImport("mods/route/history/assembly.lua").create()
end)
local routeHistory = historySystem.history
local routeQuery = historySystem.query
local routeLoot = historySystem.loot
local historyBuilder = historySystem.builder

-- luacheck: globals TestRunPlannerRouteHistoryQuery
TestRunPlannerRouteHistoryQuery = {}

local function buildFErebusHistory(rows)
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields(rows), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()
    return historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })
end

local function scalarRows()
    return {
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }
end

local function lootRows()
    return {
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "PoseidonUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "TalentDrop",
        },
    }
end

function TestRunPlannerRouteHistoryQuery.testScalarQueriesReadHistoryEntry()
    local history = buildFErebusHistory(scalarRows())
    local entry = routeHistory.byKind(history, "room")[2]

    lu.assertEquals(entry.eventKey, "F_Combat02")
    lu.assertEquals(routeQuery.runDepthCache(entry), 3)
    lu.assertEquals(routeQuery.biomeDepthCache(entry), 1)
    lu.assertEquals(routeQuery.enteredBiomes(entry), 1)
    lu.assertEquals(routeQuery.runEncounterDepth(entry), 2)
    lu.assertEquals(routeQuery.biomeEncounterDepth(entry), 2)
end

function TestRunPlannerRouteHistoryQuery.testScalarQueriesReturnNilWithoutEntry()
    lu.assertNil(routeQuery.runDepthCache(nil))
    lu.assertNil(routeQuery.biomeDepthCache(nil))
    lu.assertNil(routeQuery.enteredBiomes(nil))
    lu.assertNil(routeQuery.runEncounterDepth(nil))
    lu.assertNil(routeQuery.biomeEncounterDepth(nil))
end

function TestRunPlannerRouteHistoryQuery.testLootTypeHistoryQueriesUsePriorLootOnly()
    local history = buildFErebusHistory(lootRows())
    local boonLoot = routeHistory.lootEntries(history, "Boon")
    local firstBoon = boonLoot[1]
    local talent = routeHistory.lootEntries(history, "TalentDrop")[1]

    lu.assertEquals(routeQuery.lootTypeHistoryCount(history, firstBoon, "Boon"), 0)
    lu.assertFalse(routeQuery.hasLootType(history, firstBoon, "Boon"))
    lu.assertEquals(routeQuery.lootTypeHistoryCount(history, talent, "Boon"), 2)
    lu.assertTrue(routeQuery.hasLootType(history, talent, "SpellDrop"))
    lu.assertEquals(routeQuery.lastLootType(history, talent, "Boon").lootName, "PoseidonUpgrade")
end

function TestRunPlannerRouteHistoryQuery.testBiomeUseRecordQueriesUseCurrentBiome()
    local history = buildFErebusHistory(lootRows())
    local talent = routeHistory.lootEntries(history, "TalentDrop")[1]

    lu.assertEquals(routeQuery.biomeUseRecordCount(history, talent, "Boon"), 2)
    lu.assertTrue(routeQuery.hasBiomeUseRecord(history, talent, "SpellDrop"))
    lu.assertFalse(routeQuery.hasBiomeUseRecord(history, talent, "HermesUpgrade"))
end

function TestRunPlannerRouteHistoryQuery.testLootSourceQueriesUsePriorSourceValues()
    local history = buildFErebusHistory(lootRows())
    local talent = routeHistory.lootEntries(history, "TalentDrop")[1]

    lu.assertTrue(routeQuery.hasLootSource(history, talent, "ZeusUpgrade"))
    lu.assertFalse(routeQuery.hasLootSource(history, talent, "DemeterUpgrade"))
    lu.assertEquals(routeQuery.distinctLootSourceCount(history, talent, {
        "ZeusUpgrade",
        "PoseidonUpgrade",
        "DemeterUpgrade",
    }), 2)
end

function TestRunPlannerRouteHistoryQuery.testRequiredNotInStoreReadsPriorPendingLoot()
    local history = routeHistory.create()
    local current = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 10,
    }, {
        kind = "room",
        eventKey = "CurrentRoom",
    })
    local pending = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 8,
    }, {
        kind = "loot",
        eventKey = "WeaponUpgrade",
        lootType = "WeaponUpgrade",
        timing = "pendingOffer",
        pendingUntilRoomHistoryOrdinal = 10,
    })

    local valid, blocker = routeQuery.requiredNotInStore(history, current, "WeaponUpgrade")
    lu.assertFalse(valid)
    lu.assertIs(blocker, pending)
    lu.assertTrue((routeQuery.requiredNotInStore(history, current, "HermesUpgrade")))
end

function TestRunPlannerRouteHistoryQuery.testRequiredNotInStoreIgnoresExpiredPendingLoot()
    local history = routeHistory.create()
    routeHistory.emitAt(history, {
        roomHistoryOrdinal = 8,
    }, {
        kind = "loot",
        eventKey = "WeaponUpgrade",
        lootType = "WeaponUpgrade",
        timing = "pendingOffer",
        pendingUntilRoomHistoryOrdinal = 9,
    })
    local current = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 10,
    }, {
        kind = "room",
        eventKey = "CurrentRoom",
    })

    lu.assertTrue((routeQuery.requiredNotInStore(history, current, "WeaponUpgrade")))
end

function TestRunPlannerRouteHistoryQuery.testRequiredNotInStoreIgnoresPendingLootWithoutExpiry()
    local history = routeHistory.create()
    routeHistory.emitAt(history, {
        roomHistoryOrdinal = 8,
    }, {
        kind = "loot",
        eventKey = "WeaponUpgrade",
        lootType = "WeaponUpgrade",
        timing = "pendingOffer",
    })
    local current = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 10,
    }, {
        kind = "room",
        eventKey = "CurrentRoom",
    })

    lu.assertTrue((routeQuery.requiredNotInStore(history, current, "WeaponUpgrade")))
end

function TestRunPlannerRouteHistoryQuery.testShopOffersEmitExpiringPendingFactsSeparateFromAcquiredLoot()
    local history = routeHistory.create()
    local shopRoom = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 8,
    }, {
        kind = "room",
        eventKey = "ShopRoom",
        reward = {
            kind = "preboss",
            branch = "Shop",
            shop = {
                shopProfile = "WorldShop",
            },
            offers = {
                {
                    rewardType = "WeaponUpgradeDrop",
                    state = "Skipped",
                },
                {
                    rewardType = "RandomLoot",
                    boonSource = "ZeusUpgrade",
                    state = "Bought",
                    bought = true,
                },
            },
        },
    })
    local nextRoom = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 9,
    }, {
        kind = "room",
        eventKey = "NextRoom",
    })

    routeLoot.emitForRoomEntry(history, shopRoom, nextRoom)

    local pendingHammer = routeHistory.pendingLootEntries(history, "WeaponUpgradeDrop")[1]
    lu.assertNotNil(pendingHammer)
    lu.assertEquals(pendingHammer.pendingUntilRoomHistoryOrdinal, 9)
    lu.assertEquals(#routeHistory.lootEntries(history, "WeaponUpgradeDrop"), 0)

    local pendingBoon = routeHistory.pendingLootEntries(history, "RandomLoot")[1]
    local acquiredBoon = routeHistory.lootEntries(history, "RandomLoot")[1]
    lu.assertNotNil(pendingBoon)
    lu.assertNotNil(acquiredBoon)
    lu.assertEquals(pendingBoon.timing, "pendingOffer")
    lu.assertNil(acquiredBoon.timing)
    lu.assertTrue(acquiredBoon.bought)
    lu.assertEquals(acquiredBoon.acquiredAfterRoomHistoryOrdinal, 9)
    lu.assertEquals(routeQuery.lootTypeHistoryCount(history, nextRoom, "RandomLoot"), 0)

    local valid, blocker = routeQuery.requiredNotInStore(history, nextRoom, "WeaponUpgradeDrop")
    lu.assertFalse(valid)
    lu.assertIs(blocker, pendingHammer)

    local laterRoom = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 10,
    }, {
        kind = "room",
        eventKey = "LaterRoom",
    })
    lu.assertTrue((routeQuery.requiredNotInStore(history, laterRoom, "WeaponUpgradeDrop")))
    lu.assertEquals(routeQuery.lootTypeHistoryCount(history, laterRoom, "RandomLoot"), 1)
end

function TestRunPlannerRouteHistoryQuery.testRequiredMinExitsReadsPreviousRoomTopologyForRoomEntry()
    local history = routeHistory.create()
    routeHistory.emitAt(history, {
        roomHistoryOrdinal = 1,
    }, {
        kind = "room",
        eventKey = "PreviousRoom",
        topology = {
            exits = {
                { roomKey = "A" },
                { roomKey = "B" },
            },
        },
    })
    local current = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 2,
    }, {
        kind = "room",
        eventKey = "CurrentRoom",
        topology = {
            exits = {
                { roomKey = "C" },
            },
        },
    })

    lu.assertEquals(routeQuery.previousGeneratedExitCount(history, current), 2)
    lu.assertTrue(routeQuery.requiredMinExits(history, current, 2))
    lu.assertFalse(routeQuery.requiredMinExits(history, current, 3))
end

function TestRunPlannerRouteHistoryQuery.testRequiredMinExitsUsesLootParentRoom()
    local history = routeHistory.create()
    local previous = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 1,
    }, {
        kind = "room",
        eventKey = "PreviousRoom",
        topology = {
            selected = { roomKey = "CurrentRoom" },
            sibling = { roomKey = "OtherRoom" },
        },
    })
    local current = routeHistory.emitAt(history, {
        roomHistoryOrdinal = 2,
    }, {
        kind = "room",
        eventKey = "CurrentRoom",
        topology = {
            exits = {
                { roomKey = "NextRoom" },
            },
        },
    })
    local loot = routeHistory.emitAt(history, current, {
        kind = "loot",
        eventKey = "Devotion",
        lootType = "Devotion",
        parentEntry = current,
    })

    lu.assertEquals(previous.eventKey, "PreviousRoom")
    lu.assertEquals(routeQuery.previousGeneratedExitCount(history, loot), 2)
    lu.assertTrue(routeQuery.requiredMinExits(history, loot, 2))
    lu.assertFalse(routeQuery.requiredMinExits(history, loot, 3))
end

function TestRunPlannerRouteHistoryQuery.testEventQueriesUsePriorEventsOnly()
    local history = buildFErebusHistory(lootRows())
    local rooms = routeHistory.byKind(history, "room")
    local current = rooms[4]

    local previous = routeQuery.lastEventBefore(history, current, {
        kind = "room",
    })
    lu.assertEquals(previous.eventKey, "F_Combat02")
    lu.assertTrue((routeQuery.requiredMinRoomsSinceEvent(history, current, {
        eventKey = "F_Combat02",
        count = 1,
    })))
end
