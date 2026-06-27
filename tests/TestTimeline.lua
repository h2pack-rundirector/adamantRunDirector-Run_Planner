local lu = require("luaunit")

-- luacheck: globals TestRunPlannerTimeline
TestRunPlannerTimeline = {}

local function testImport(path, _, deps)
    local chunk = assert(loadfile("src/" .. path))
    return chunk(deps)
end

function TestRunPlannerTimeline.testWalkRouteCountsRowsAndAfterBiomeTimeline()
    local timeline = testImport("mods/route/timeline.lua")
    local route = {
        key = "TestRoute",
        biomes = { "A", "B" },
    }
    local snapshots = {
        A = {
            rows = {
                {
                    rowIndex = 1,
                    roomHistoryCost = 1,
                    biomeDepthCache = 0,
                    biomeEncounterDepth = 1,
                    biomeEncounterDepthCost = 1,
                },
                {
                    rowIndex = 2,
                    roomHistoryCost = 2,
                    biomeDepthCache = 1,
                    biomeEncounterDepth = 2,
                    biomeEncounterDepthCost = 2,
                },
            },
        },
        B = {
            rows = {
                {
                    rowIndex = 1,
                    roomHistoryCost = 1,
                    biomeDepthCache = 0,
                    biomeEncounterDepth = 1,
                    biomeEncounterDepthCost = 1,
                },
            },
        },
    }
    local biomeLookup = {
        A = {
            timeline = {
                afterBiome = {
                    { key = "Boss", roomHistoryCost = 1 },
                    { key = "PostBoss", roomHistoryCost = 1 },
                },
            },
        },
        B = {},
    }
    local rows = {}
    local entries = {}

    timeline.walkRoute(route, {
        biomeLookup = biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return snapshots[biomeKey]
        end,
        onRow = function(ctx)
            rows[#rows + 1] = ctx
        end,
        onAfterBiomeEntry = function(ctx)
            entries[#entries + 1] = ctx
        end,
    })

    lu.assertEquals(rows[1].roomHistoryOrdinal, 1)
    lu.assertEquals(rows[1].runDepthCache, 2)
    lu.assertEquals(rows[1].runEncounterDepth, 1)
    lu.assertEquals(rows[1].roomHistoryDepth, 0)
    lu.assertEquals(rows[1].biomeDepthCache, 0)
    lu.assertEquals(rows[2].roomHistoryOrdinal, 3)
    lu.assertEquals(rows[2].runDepthCache, 4)
    lu.assertEquals(rows[2].runEncounterDepth, 2)
    lu.assertEquals(rows[2].roomHistoryDepth, 2)
    lu.assertEquals(entries[1].entryKey, "Boss")
    lu.assertEquals(entries[1].roomHistoryOrdinal, 4)
    lu.assertEquals(entries[1].runDepthCache, 5)
    lu.assertEquals(entries[1].runEncounterDepth, 4)
    lu.assertEquals(entries[2].entryKey, "PostBoss")
    lu.assertEquals(entries[2].roomHistoryOrdinal, 5)
    lu.assertEquals(entries[2].runDepthCache, 6)
    lu.assertEquals(entries[2].runEncounterDepth, 4)
    lu.assertEquals(rows[3].biomeKey, "B")
    lu.assertEquals(rows[3].roomHistoryOrdinal, 6)
    lu.assertEquals(rows[3].runDepthCache, 7)
    lu.assertEquals(rows[3].runEncounterDepth, 4)
    lu.assertEquals(rows[3].roomHistoryDepth, 0)
end

function TestRunPlannerTimeline.testWalkRouteTreatsMissingEncounterDepthCostAsUnknown()
    local timeline = testImport("mods/route/timeline.lua")
    local route = {
        key = "TestRoute",
        biomes = { "A" },
    }
    local rows = {}

    timeline.walkRoute(route, {
        snapshotForBiome = function()
            return {
                rows = {
                    {
                        rowIndex = 1,
                        roomHistoryCost = 1,
                        biomeEncounterDepthCost = 1,
                    },
                    {
                        rowIndex = 2,
                        roomHistoryCost = 1,
                    },
                    {
                        rowIndex = 3,
                        roomHistoryCost = 1,
                        biomeEncounterDepthCost = 1,
                    },
                },
            }
        end,
        onRow = function(ctx)
            rows[#rows + 1] = ctx
        end,
    })

    lu.assertEquals(rows[1].runEncounterDepth, 1)
    lu.assertEquals(rows[2].runEncounterDepth, 2)
    lu.assertNil(rows[3].runEncounterDepth)
end

function TestRunPlannerTimeline.testSideRoomContextUsesParentTimelinePosition()
    local timeline = testImport("mods/route/timeline.lua")
    local side = timeline.sideRoomContext({
        routeKey = "Surface",
        biomeKey = "N",
        rowIndex = 4,
        routeOrdinal = 3,
        roomHistoryOrdinal = 5,
        roomHistoryDepth = 3,
        runEncounterDepth = 2,
    }, { sideIndex = 1 })

    lu.assertEquals(side.routeKey, "Surface")
    lu.assertEquals(side.biomeKey, "N")
    lu.assertEquals(side.rowIndex, 4)
    lu.assertEquals(side.routeOrdinal, 3)
    lu.assertEquals(side.roomHistoryOrdinal, 6)
    lu.assertEquals(side.runDepthCache, 7)
    lu.assertEquals(side.runEncounterDepth, 2)
    lu.assertEquals(side.roomHistoryDepth, 4)
end

function TestRunPlannerTimeline.testNextBiomeRowCountersUseStartAndPreviousCosts()
    local timeline = testImport("mods/route/timeline.lua")
    local instance = {
        biome = {
            slotLayout = {
                biomeDepthCacheStart = 3,
            },
        },
    }

    local first = timeline.nextBiomeRowCounters(instance)
    lu.assertEquals(first.biomeDepthCache, 3)
    lu.assertEquals(first.biomeEncounterDepth, 1)

    local second = timeline.nextBiomeRowCounters(instance, {
        biomeDepthCache = first.biomeDepthCache,
        biomeDepthCacheCost = 2,
        biomeEncounterDepth = first.biomeEncounterDepth,
        biomeEncounterDepthCost = 1,
    })
    lu.assertEquals(second.biomeDepthCache, 5)
    lu.assertEquals(second.biomeEncounterDepth, 2)
end

function TestRunPlannerTimeline.testNextBiomeRowCountersTreatsMissingEncounterDepthCostAsUnknown()
    local timeline = testImport("mods/route/timeline.lua")
    local counters = timeline.nextBiomeRowCounters({}, {
        biomeDepthCache = 1,
        biomeDepthCacheCost = 1,
        biomeEncounterDepth = 2,
    })

    lu.assertEquals(counters.biomeDepthCache, 2)
    lu.assertNil(counters.biomeEncounterDepth)
end

function TestRunPlannerTimeline.testNextBiomeRowCountersTreatsMissingEncounterDepthAsUnknown()
    local timeline = testImport("mods/route/timeline.lua")

    local missingDepth = timeline.nextBiomeRowCounters({}, {
        biomeDepthCache = 1,
        biomeDepthCacheCost = 1,
        biomeEncounterDepthCost = 1,
    })
    lu.assertEquals(missingDepth.biomeDepthCache, 2)
    lu.assertNil(missingDepth.biomeEncounterDepth)
end

function TestRunPlannerTimeline.testRowBiomeEncounterDepthCostTreatsMissingCostAsUnknown()
    local timeline = testImport("mods/route/timeline.lua")

    lu.assertNil(timeline.rowBiomeEncounterDepthCost({
        rowIndex = 9,
    }))

    lu.assertEquals(timeline.rowBiomeEncounterDepthCost({
        biomeEncounterDepthCost = 2,
    }), 2)
end
