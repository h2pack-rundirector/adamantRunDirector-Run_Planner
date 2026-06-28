local lu = require("luaunit")
local h = require("tests.support.control_harness")
local routeEvents = h.testImport("mods/route/events.lua")
local routeQuery = h.testImport("mods/route/query.lua", nil, {
    events = routeEvents,
})

-- luacheck: globals TestRunPlannerRouteQuery
TestRunPlannerRouteQuery = {}

function TestRunPlannerRouteQuery.testDepthQueriesReadRouteContext()
    local context = {
        runDepthCache = 12,
        biomeDepthCache = 5,
        routeBiomeIndex = 3,
        runEncounterDepth = 7,
        biomeEncounterDepth = 3,
    }

    lu.assertEquals(routeQuery.runDepthCache(context), 12)
    lu.assertEquals(routeQuery.biomeDepthCache(context), 5)
    lu.assertEquals(routeQuery.enteredBiomes(context), 3)
    lu.assertEquals(routeQuery.runEncounterDepth(context), 7)
    lu.assertEquals(routeQuery.biomeEncounterDepth(context), 3)
end

function TestRunPlannerRouteQuery.testDepthQueriesSupportExactEncounterDepth()
    local context = {
        runEncounterDepth = 8,
        biomeEncounterDepth = 4,
    }

    lu.assertEquals(routeQuery.runEncounterDepth(context), 8)
    lu.assertEquals(routeQuery.biomeEncounterDepth(context), 4)
end

function TestRunPlannerRouteQuery.testRequiredMinRoomsSinceRunDepth()
    local context = {
        runDepthCache = 16,
    }

    lu.assertTrue(routeQuery.requiredMinRoomsSinceRunDepth(context, 7, 9))
    lu.assertFalse(routeQuery.requiredMinRoomsSinceRunDepth(context, 7, 10))
    lu.assertFalse(routeQuery.requiredMinRoomsSinceRunDepth(context, nil, 1))
end

function TestRunPlannerRouteQuery.testRequiredMinRoomsSinceEventCanUseNamedAxis()
    local history = routeEvents.createHistory()
    routeEvents.emit(history, {
        kind = "npc",
        eventKey = "ArtemisCombatF",
        runDepthCache = 7,
        roomHistoryOrdinal = 8,
    })
    local context = {
        runDepthCache = 16,
        roomHistoryOrdinal = 12,
    }

    lu.assertTrue((routeQuery.requiredMinRoomsSinceEvent(history, context, {
        eventKey = "ArtemisCombatF",
        axis = "runDepthCache",
        count = 9,
    })))
    lu.assertTrue((routeQuery.requiredMinRoomsSinceEvent(history, context, {
        eventKey = "ArtemisCombatF",
        axis = "roomHistory",
        count = 4,
    })))
    lu.assertFalse((routeQuery.requiredMinRoomsSinceEvent(history, context, {
        eventKey = "ArtemisCombatF",
        axis = "roomHistory",
        count = 5,
    })))
end

function TestRunPlannerRouteQuery.testSumPrevRoomsUsesCurrentAndPreviousWindow()
    local history = routeEvents.createHistory()
    routeEvents.emit(history, {
        kind = "npc",
        eventKey = "CurrentNpc",
        groupKey = "FieldNpc",
        roomHistoryOrdinal = 12,
    })
    routeEvents.emit(history, {
        kind = "npc",
        eventKey = "RecentNpc",
        groupKey = "FieldNpc",
        roomHistoryOrdinal = 7,
    })
    routeEvents.emit(history, {
        kind = "npc",
        eventKey = "OldNpc",
        groupKey = "ArachneCombat",
        roomHistoryOrdinal = 6,
    })
    local context = {
        roomHistoryOrdinal = 12,
    }

    lu.assertTrue((routeQuery.sumPrevRooms(history, context, {
        groupKey = "FieldNpc",
        count = 6,
    })))
    lu.assertFalse((routeQuery.sumPrevRooms(history, context, {
        groupKey = "ArachneCombat",
        count = 6,
    })))
end

function TestRunPlannerRouteQuery.testRequiredMinExitsPrefersTopologyThenRowThenOption()
    lu.assertTrue(routeQuery.requiredMinExits({
        valid = true,
        roomTopology = {
            exitCount = 3,
        },
        exitCount = 2,
        option = {
            exitCount = 1,
        },
    }, 3))
    lu.assertTrue(routeQuery.requiredMinExits({
        valid = true,
        exitCount = 2,
        option = {
            exitCount = 1,
        },
    }, 2))
    lu.assertTrue(routeQuery.requiredMinExits({
        valid = true,
        option = {
            exitCount = 1,
        },
    }, 1))
end

function TestRunPlannerRouteQuery.testRequiredMinExitsRejectsUnusableRows()
    lu.assertTrue(routeQuery.requiredMinExits({
        valid = true,
        exitCount = 2,
    }, 2))
    lu.assertFalse(routeQuery.requiredMinExits({
        valid = true,
        exitCount = 1,
    }, 2))
    lu.assertFalse(routeQuery.requiredMinExits({
        valid = false,
        exitCount = 3,
    }, 2))
    lu.assertFalse(routeQuery.requiredMinExits({
        valid = true,
        roleKey = "Vanilla",
        exitCount = 3,
    }, 2))
end
