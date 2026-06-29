local lu = require("luaunit")
local h = require("tests.support.control_harness")
local routeEvents = h.testImport("mods/route/events.lua")
local routeHistory = h.testImport("mods/route/history.lua", nil, {
    events = routeEvents,
})
local routeQuery = h.testImport("mods/route/query.lua", nil, {
    events = routeEvents,
    history = routeHistory,
})

-- luacheck: globals TestRunPlannerRouteEvents
TestRunPlannerRouteEvents = {}

local function rowContext()
    return {
        biomeKey = "F",
        rowIndex = 7,
        routeOrdinal = 8,
        roomHistoryOrdinal = 10,
        runDepthCache = 11,
        runEncounterDepth = 8,
        biomeDepthCache = 6,
        biomeEncounterDepth = 5,
    }
end

function TestRunPlannerRouteEvents.testLootEventNormalizesPositionAndLootPayload()
    local lootEvent = {
        lootType = "Devotion",
        address = "row",
        devotionSourceA = "ZeusUpgrade",
        devotionSourceB = "PoseidonUpgrade",
    }
    local event = routeEvents.createAt(rowContext(), {
        kind = "loot",
        eventKey = lootEvent.lootType,
        source = lootEvent,
        address = lootEvent.address,
        lootType = lootEvent.lootType,
        devotionSourceA = lootEvent.devotionSourceA,
        devotionSourceB = lootEvent.devotionSourceB,
    })

    lu.assertEquals(event.kind, "loot")
    lu.assertEquals(event.eventKey, "Devotion")
    lu.assertEquals(event.lootType, "Devotion")
    lu.assertEquals(event.biomeKey, "F")
    lu.assertEquals(event.rowIndex, 7)
    lu.assertEquals(event.runDepthCache, 11)
    lu.assertEquals(event.roomHistoryOrdinal, 10)
    lu.assertEquals(event.devotionSourceA, "ZeusUpgrade")
    lu.assertEquals(event.devotionSourceB, "PoseidonUpgrade")
end

function TestRunPlannerRouteEvents.testNpcTargetNormalizesEncounterAndGroup()
    local target = {
        npcKey = "Arachne",
        encounterName = "ArachneCombatF",
        variantKey = "ArachneCombatF",
        biomeKey = "F",
        rowIndex = 6,
        roomHistoryOrdinal = 9,
        runDepthCache = 10,
    }
    local event = routeEvents.create({
        kind = "npc",
        eventKey = target.encounterName,
        groupKey = "ArachneCombat",
        source = target,
        npcKey = target.npcKey,
        encounterName = target.encounterName,
        variantKey = target.variantKey,
        position = target,
    })

    lu.assertEquals(event.kind, "npc")
    lu.assertEquals(event.eventKey, "ArachneCombatF")
    lu.assertEquals(event.groupKey, "ArachneCombat")
    lu.assertEquals(event.npcKey, "Arachne")
    lu.assertEquals(event.runDepthCache, 10)
end

function TestRunPlannerRouteEvents.testFeatureTargetNormalizesFeatureKey()
    local target = {
        featureKey = "wellShop",
        slotKey = "StygianWell",
        biomeKey = "G",
        rowIndex = 3,
        roomHistoryOrdinal = 14,
        runDepthCache = 15,
    }
    local event = routeEvents.create({
        kind = "feature",
        eventKey = target.featureKey,
        groupKey = "RouteFeature",
        source = target,
        featureKey = target.featureKey,
        slotKey = target.slotKey,
        position = target,
    })

    lu.assertEquals(event.kind, "feature")
    lu.assertEquals(event.eventKey, "wellShop")
    lu.assertEquals(event.groupKey, "RouteFeature")
    lu.assertEquals(event.featureKey, "wellShop")
    lu.assertEquals(event.slotKey, "StygianWell")
end

function TestRunPlannerRouteEvents.testHistoryIndexesEventsByEventAndGroup()
    local history = routeHistory.create()
    local loot = routeHistory.emitAt(history, rowContext(), {
        kind = "loot",
        eventKey = "Devotion",
        lootType = "Devotion",
        address = "row",
    })
    local npc = routeHistory.emit(history, {
        kind = "npc",
        eventKey = "ArtemisCombatG",
        routeGroup = "FieldNpc",
        groupKey = "FieldNpc",
        position = {
            npcKey = "Artemis",
            encounterName = "ArtemisCombatG",
            roomHistoryOrdinal = 12,
            runDepthCache = 13,
        },
    })

    lu.assertIs(routeHistory.lastEvent(history, "Devotion"), loot)
    lu.assertIs(routeHistory.lastEvent(history, "ArtemisCombatG"), npc)
    lu.assertIs(routeHistory.lastInGroup(history, "FieldNpc"), npc)
    lu.assertEquals(routeHistory.count(history, { kind = "loot" }), 1)
    lu.assertEquals(routeHistory.count(history, { kind = "npc" }), 1)
end

function TestRunPlannerRouteEvents.testHistoryIndexesLootFacts()
    local history = routeHistory.create()
    local selected = routeHistory.emitAt(history, rowContext(), {
        kind = "loot",
        eventKey = "Loot",
        lootType = "Boon",
        biomeKey = "F",
        sourceValues = { "DemeterUpgrade", "ZeusUpgrade" },
    })
    local pending = routeHistory.emitAt(history, {
        biomeKey = "G",
        rowIndex = 3,
    }, {
        kind = "loot",
        eventKey = "Loot",
        lootType = "WeaponUpgradeDrop",
        timing = "pendingOffer",
        sourceValues = { "Hammer" },
    })

    lu.assertIs(routeHistory.lootEntries(history, "Boon")[1], selected)
    lu.assertIs(routeHistory.biomeLootEntries(history, "F", "Boon")[1], selected)
    lu.assertEquals(routeHistory.count(history, {
        kind = "loot",
        lootType = "Boon",
        biomeKey = "F",
    }), 1)
    lu.assertIs(routeHistory.pendingLootEntries(history, "WeaponUpgradeDrop")[1], pending)
    lu.assertTrue(routeHistory.hasPendingLoot(history, "WeaponUpgradeDrop"))
    lu.assertIs(routeHistory.sourceEntries(history, "DemeterUpgrade")[1], selected)
end

function TestRunPlannerRouteEvents.testMinRoomsSinceEventUsesRunDepthCache()
    local history = routeHistory.create()
    routeHistory.emitAt(history, {
        runDepthCache = 10,
    }, {
        kind = "loot",
        eventKey = "Devotion",
        lootType = "Devotion",
    })
    lu.assertTrue((routeQuery.requiredMinRoomsSinceEvent(history, {
        runDepthCache = 25,
    }, {
        eventKey = "Devotion",
        count = 15,
    })))
    lu.assertFalse((routeQuery.requiredMinRoomsSinceEvent(history, {
        runDepthCache = 24,
    }, {
        eventKey = "Devotion",
        count = 15,
    })))
    lu.assertTrue((routeQuery.requiredMinRoomsSinceEvent(history, {
        runDepthCache = 24,
    }, {
        eventKey = "HermesUpgrade",
        count = 15,
    })))
end

function TestRunPlannerRouteEvents.testSumPrevRoomsScansInternalWindow()
    local history = routeHistory.create()
    local fieldNpc = routeHistory.emit(history, {
        kind = "npc",
        eventKey = "ArtemisCombatF",
        routeGroup = "FieldNpc",
        groupKey = "FieldNpc",
        position = {
            npcKey = "Artemis",
            encounterName = "ArtemisCombatF",
            roomHistoryOrdinal = 8,
        },
    })
    routeHistory.emit(history, {
        kind = "npc",
        eventKey = "ArachneCombatF",
        routeGroup = "ArachneCombat",
        groupKey = "ArachneCombat",
        position = {
            npcKey = "Arachne",
            encounterName = "ArachneCombatF",
            roomHistoryOrdinal = 5,
        },
    })

    local found, event = routeQuery.sumPrevRooms(history, {
        roomHistoryOrdinal = 12,
    }, {
        groupKey = "FieldNpc",
        count = 6,
    })
    lu.assertTrue(found)
    lu.assertIs(event, fieldNpc)

    lu.assertFalse((routeQuery.sumPrevRooms(history, {
        roomHistoryOrdinal = 12,
    }, {
        groupKey = "ArachneCombat",
        count = 6,
    })))
end
