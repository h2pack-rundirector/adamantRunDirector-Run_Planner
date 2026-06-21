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
                    biomeEncounterDepth = 0,
                    biomeEncounterDepthCost = 1,
                },
                {
                    rowIndex = 2,
                    roomHistoryCost = 2,
                    biomeDepthCache = 1,
                    biomeEncounterDepth = 1,
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
                    biomeEncounterDepth = 0,
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
    lu.assertEquals(rows[1].runEncounterDepthMin, 1)
    lu.assertEquals(rows[1].runEncounterDepthMax, 1)
    lu.assertEquals(rows[1].roomHistoryDepth, 0)
    lu.assertEquals(rows[1].biomeDepthCache, 0)
    lu.assertEquals(rows[2].roomHistoryOrdinal, 3)
    lu.assertEquals(rows[2].runDepthCache, 4)
    lu.assertEquals(rows[2].runEncounterDepth, 2)
    lu.assertEquals(rows[2].runEncounterDepthMin, 2)
    lu.assertEquals(rows[2].runEncounterDepthMax, 2)
    lu.assertEquals(rows[2].roomHistoryDepth, 2)
    lu.assertEquals(entries[1].entryKey, "Boss")
    lu.assertEquals(entries[1].roomHistoryOrdinal, 4)
    lu.assertEquals(entries[1].runDepthCache, 5)
    lu.assertEquals(entries[1].runEncounterDepth, 4)
    lu.assertEquals(entries[1].runEncounterDepthMin, 4)
    lu.assertEquals(entries[1].runEncounterDepthMax, 4)
    lu.assertEquals(entries[2].entryKey, "PostBoss")
    lu.assertEquals(entries[2].roomHistoryOrdinal, 5)
    lu.assertEquals(entries[2].runDepthCache, 6)
    lu.assertEquals(entries[2].runEncounterDepth, 4)
    lu.assertEquals(entries[2].runEncounterDepthMin, 4)
    lu.assertEquals(entries[2].runEncounterDepthMax, 4)
    lu.assertEquals(rows[3].biomeKey, "B")
    lu.assertEquals(rows[3].roomHistoryOrdinal, 6)
    lu.assertEquals(rows[3].runDepthCache, 7)
    lu.assertEquals(rows[3].runEncounterDepth, 4)
    lu.assertEquals(rows[3].runEncounterDepthMin, 4)
    lu.assertEquals(rows[3].runEncounterDepthMax, 4)
    lu.assertEquals(rows[3].roomHistoryDepth, 0)
end

function TestRunPlannerTimeline.testWalkRouteBoundsRunEncounterDepthAfterAmbiguousRowCost()
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
                        biomeEncounterDepthCost = { min = 0, max = 1 },
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
    lu.assertEquals(rows[1].runEncounterDepthMin, 1)
    lu.assertEquals(rows[1].runEncounterDepthMax, 1)
    lu.assertEquals(rows[2].runEncounterDepth, 2)
    lu.assertEquals(rows[2].runEncounterDepthMin, 2)
    lu.assertEquals(rows[2].runEncounterDepthMax, 2)
    lu.assertNil(rows[3].runEncounterDepth)
    lu.assertEquals(rows[3].runEncounterDepthMin, 2)
    lu.assertEquals(rows[3].runEncounterDepthMax, 3)
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
        runEncounterDepthMin = 2,
        runEncounterDepthMax = 2,
    }, { sideIndex = 1 })

    lu.assertEquals(side.routeKey, "Surface")
    lu.assertEquals(side.biomeKey, "N")
    lu.assertEquals(side.rowIndex, 4)
    lu.assertEquals(side.routeOrdinal, 3)
    lu.assertEquals(side.roomHistoryOrdinal, 6)
    lu.assertEquals(side.runDepthCache, 7)
    lu.assertEquals(side.runEncounterDepth, 2)
    lu.assertEquals(side.runEncounterDepthMin, 2)
    lu.assertEquals(side.runEncounterDepthMax, 2)
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
    lu.assertEquals(first.biomeEncounterDepth, 0)
    lu.assertEquals(first.biomeEncounterDepthMin, 0)
    lu.assertEquals(first.biomeEncounterDepthMax, 0)

    local second = timeline.nextBiomeRowCounters(instance, {
        biomeDepthCache = first.biomeDepthCache,
        biomeDepthCacheCost = 2,
        biomeEncounterDepth = first.biomeEncounterDepth,
        biomeEncounterDepthMin = first.biomeEncounterDepthMin,
        biomeEncounterDepthMax = first.biomeEncounterDepthMax,
        biomeEncounterDepthCost = 1,
    })
    lu.assertEquals(second.biomeDepthCache, 5)
    lu.assertEquals(second.biomeEncounterDepth, 1)
    lu.assertEquals(second.biomeEncounterDepthMin, 1)
    lu.assertEquals(second.biomeEncounterDepthMax, 1)
end

function TestRunPlannerTimeline.testNextBiomeRowCountersPropagateEncounterDepthBounds()
    local timeline = testImport("mods/route/timeline.lua")
    local counters = timeline.nextBiomeRowCounters({}, {
        biomeDepthCache = 1,
        biomeDepthCacheCost = nil,
        biomeEncounterDepth = nil,
        biomeEncounterDepthMin = 2,
        biomeEncounterDepthMax = 3,
        biomeEncounterDepthCostMin = 0,
        biomeEncounterDepthCostMax = 1,
    })

    lu.assertNil(counters.biomeDepthCache)
    lu.assertNil(counters.biomeEncounterDepth)
    lu.assertEquals(counters.biomeEncounterDepthMin, 2)
    lu.assertEquals(counters.biomeEncounterDepthMax, 4)
end

function TestRunPlannerTimeline.testNextBiomeRowCountersTreatsMissingEncounterDepthBoundsAsUnknown()
    local timeline = testImport("mods/route/timeline.lua")

    local missingDepthBounds = timeline.nextBiomeRowCounters({}, {
        biomeDepthCache = 1,
        biomeDepthCacheCost = 1,
        biomeEncounterDepthCost = 1,
    })
    lu.assertEquals(missingDepthBounds.biomeDepthCache, 2)
    lu.assertNil(missingDepthBounds.biomeEncounterDepth)
    lu.assertNil(missingDepthBounds.biomeEncounterDepthMin)
    lu.assertNil(missingDepthBounds.biomeEncounterDepthMax)

    local missingCostBounds = timeline.nextBiomeRowCounters({}, {
        biomeDepthCache = 1,
        biomeDepthCacheCost = 1,
        biomeEncounterDepthMin = 0,
        biomeEncounterDepthMax = 1,
    })
    lu.assertEquals(missingCostBounds.biomeDepthCache, 2)
    lu.assertNil(missingCostBounds.biomeEncounterDepth)
    lu.assertNil(missingCostBounds.biomeEncounterDepthMin)
    lu.assertNil(missingCostBounds.biomeEncounterDepthMax)
end

function TestRunPlannerTimeline.testRowBiomeEncounterDepthCostBoundsTreatsMissingCostAsUnknown()
    local timeline = testImport("mods/route/timeline.lua")

    local bounds = timeline.rowBiomeEncounterDepthCostBounds({
        rowIndex = 9,
    })

    lu.assertNil(bounds.min)
    lu.assertNil(bounds.max)
end
