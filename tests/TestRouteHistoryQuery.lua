local lu = require("luaunit")
local h = require("tests.support.control_harness")

local historySystem = h.withTestImport(function()
    return h.testImport("mods/route/history/assembly.lua").create()
end)
local routeHistory = historySystem.history
local routeQuery = historySystem.query
local historyBuilder = historySystem.builder

-- luacheck: globals TestRunPlannerRouteHistoryQuery
TestRunPlannerRouteHistoryQuery = {}

function TestRunPlannerRouteHistoryQuery.testScalarQueriesReadHistoryEntry()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields({
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
    }), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()
    local history = historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })
    local entry = routeHistory.byKind(history, "room")[2]

    lu.assertEquals(entry.eventKey, "F_Combat02")
    lu.assertEquals(routeQuery.runDepthCache(entry), 3)
    lu.assertEquals(routeQuery.biomeDepthCache(entry), 0)
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
