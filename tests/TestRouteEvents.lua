local lu = require("luaunit")
local h = require("tests.support.control_harness")
local routeEvents = h.testImport("mods/route/events.lua")
local routeQuery = h.testImport("mods/route/query.lua", nil, {
    events = routeEvents,
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

function TestRunPlannerRouteEvents.testRewardEventNormalizesPositionAndRewardPayload()
    local rewardEvent = {
        rewardType = "Devotion",
        address = "row",
        devotionSourceA = "ZeusUpgrade",
        devotionSourceB = "PoseidonUpgrade",
    }
    local event = routeEvents.createAt(rowContext(), {
        kind = "reward",
        eventKey = rewardEvent.rewardType,
        source = rewardEvent,
        address = rewardEvent.address,
        rewardType = rewardEvent.rewardType,
        devotionSourceA = rewardEvent.devotionSourceA,
        devotionSourceB = rewardEvent.devotionSourceB,
    })

    lu.assertEquals(event.kind, "reward")
    lu.assertEquals(event.eventKey, "Devotion")
    lu.assertEquals(event.rewardType, "Devotion")
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
    local history = routeEvents.createHistory()
    local reward = routeEvents.emitAt(history, rowContext(), {
        kind = "reward",
        eventKey = "Devotion",
        rewardType = "Devotion",
        address = "row",
    })
    local npc = routeEvents.emit(history, {
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

    lu.assertIs(routeEvents.lastEvent(history, "Devotion"), reward)
    lu.assertIs(routeEvents.lastEvent(history, "ArtemisCombatG"), npc)
    lu.assertIs(routeEvents.lastInGroup(history, "FieldNpc"), npc)
end

function TestRunPlannerRouteEvents.testMinRoomsSinceEventUsesRunDepthCache()
    local history = routeEvents.createHistory()
    routeEvents.emitAt(history, {
        runDepthCache = 10,
    }, {
        kind = "reward",
        eventKey = "Devotion",
        rewardType = "Devotion",
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
    local history = routeEvents.createHistory()
    local fieldNpc = routeEvents.emit(history, {
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
    routeEvents.emit(history, {
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
