local lu = require("luaunit")
local h = require("tests.support.control_harness")
local routeQuery = h.testImport("mods/route/query.lua")

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

function TestRunPlannerRouteQuery.testRunDepthDistanceQueries()
    local context = {
        runDepthCache = 16,
    }

    lu.assertEquals(routeQuery.roomsSinceDepth(context, 7), 9)
    lu.assertTrue(routeQuery.minRoomsSinceDepth(context, 7, 9))
    lu.assertFalse(routeQuery.minRoomsSinceDepth(context, 7, 10))
    lu.assertNil(routeQuery.roomsSinceDepth(context, nil))
    lu.assertFalse(routeQuery.minRoomsSinceDepth(context, nil, 1))
end

function TestRunPlannerRouteQuery.testExitCountPrefersTopologyThenRowThenOption()
    lu.assertEquals(routeQuery.exitCount({
        valid = true,
        roomTopology = {
            exitCount = 3,
        },
        exitCount = 2,
        option = {
            exitCount = 1,
        },
    }), 3)
    lu.assertEquals(routeQuery.exitCount({
        valid = true,
        exitCount = 2,
        option = {
            exitCount = 1,
        },
    }), 2)
    lu.assertEquals(routeQuery.exitCount({
        valid = true,
        option = {
            exitCount = 1,
        },
    }), 1)
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
