-- luacheck: globals TestHistoryBuilder

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestHistoryBuilder = {}

local function completeDraft()
    return {
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "F",
                rooms = {
                    {
                        roomKey = "F_Opening01",
                        generatedDoors = {
                            batchRule = "Standard",
                            selectedDoorIndex = 1,
                            doors = {
                                {
                                    exitIndex = 1,
                                    targetRoomKey = "F_Combat02",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "RunProgress",
                                                rewardType = "Boon",
                                                acquired = true,
                                                payload = {},
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    {
                        roomKey = "F_Combat02",
                        generatedDoors = {
                            batchRule = "Standard",
                            selectedDoorIndex = 2,
                            doors = {
                                {
                                    exitIndex = 1,
                                    targetRoomKey = "F_Combat01",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "RunProgress",
                                                rewardType = "MaxHealthDrop",
                                                acquired = false,
                                            },
                                        },
                                    },
                                },
                                {
                                    exitIndex = 2,
                                    targetRoomKey = "F_PreBoss01",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "MetaProgress",
                                                rewardType = "GiftDrop",
                                                acquired = true,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    {
                        roomKey = "F_PreBoss01",
                    },
                },
            },
        },
    }
end

local function loadPlan()
    local catalog = h.testImport("mods/data.lua").loadCatalog()
    local routeForm = h.testImport("mods/forms/route.lua")
    return routeForm.materialize(completeDraft(), { catalog = catalog }), catalog
end

local function eventKinds(history)
    local kinds = {}
    for index, event in ipairs(history.events) do
        kinds[index] = event.kind
    end
    return kinds
end

function TestHistoryBuilder.testBuildsLifecycleEventsForMinimalFPlan()
    h.withTestImport(function()
        local plan, catalog = loadPlan()
        local history = h.testImport("mods/history/builder.lua").build(plan, {
            catalog = catalog,
        })

        lu.assertEquals(eventKinds(history), {
            "room.enter",
            "room.generate_next",
            "generated_door",
            "offer_point.emit",
            "reward.offer",
            "room.commit",
            "room.enter",
            "reward.acquire",
            "encounter.start",
            "room.generate_next",
            "generated_door",
            "offer_point.emit",
            "reward.offer",
            "generated_door",
            "offer_point.emit",
            "reward.offer",
            "room.commit",
            "room.enter",
            "reward.acquire",
            "room.commit",
        })
    end)
end

function TestHistoryBuilder.testGeneratedDoorAndRewardLedgersUseOfferTiming()
    h.withTestImport(function()
        local plan, catalog = loadPlan()
        local history = h.testImport("mods/history/builder.lua").build(plan, {
            catalog = catalog,
        })

        lu.assertEquals(#history.generatedDoorHistory, 3)
        lu.assertEquals(history.generatedDoorHistory[2].targetRoomKey, "F_Combat01")
        lu.assertFalse(history.generatedDoorHistory[2].selected)
        lu.assertEquals(history.generatedDoorHistory[3].targetRoomKey, "F_PreBoss01")
        lu.assertTrue(history.generatedDoorHistory[3].selected)

        lu.assertEquals(#history.rewardOfferHistory, 3)
        lu.assertEquals(history.rewardOfferHistory[1].phase, "room.generate_next")
        lu.assertEquals(history.rewardOfferHistory[1].rewardType, "Boon")
        lu.assertEquals(history.rewardOfferHistory[2].rewardType, "MaxHealthDrop")
        lu.assertEquals(history.rewardOfferHistory[3].rewardType, "GiftDrop")
    end)
end

function TestHistoryBuilder.testSelectedDoorAcquisitionsEnterLootHistory()
    h.withTestImport(function()
        local plan, catalog = loadPlan()
        local history = h.testImport("mods/history/builder.lua").build(plan, {
            catalog = catalog,
        })

        lu.assertEquals(#history.lootHistory, 2)
        lu.assertEquals(history.lootHistory[1].rewardType, "Boon")
        lu.assertEquals(history.lootHistory[1].targetRoomIndex, 2)
        lu.assertEquals(history.lootHistory[1].phase, "room.enter")
        lu.assertEquals(history.lootHistory[2].rewardType, "GiftDrop")
        lu.assertEquals(history.lootHistory[2].targetRoomIndex, 3)
    end)
end

function TestHistoryBuilder.testHistoryCountersUseTypedAxes()
    h.withTestImport(function()
        local plan, catalog = loadPlan()
        local history = h.testImport("mods/history/builder.lua").build(plan, {
            catalog = catalog,
        })

        lu.assertEquals(#history.roomHistory, 3)
        lu.assertEquals(#history.encounterHistory, 1)
        lu.assertEquals(history.counters.runEncounterDepth, 1)
        lu.assertEquals(history.counters.biomeEncounterDepth.F, 1)
        lu.assertEquals(history.counters.biomeDepthCache.F, 1)
        lu.assertEquals(history.counters.roomHistoryOrdinal, 3)

        lu.assertEquals(history.roomHistory[1].biomeDepthCacheBefore, 0)
        lu.assertEquals(history.roomHistory[1].biomeDepthCacheAfter, 0)
        lu.assertEquals(history.roomHistory[2].biomeDepthCacheBefore, 0)
        lu.assertEquals(history.roomHistory[2].biomeDepthCacheAfter, 1)
    end)
end

function TestHistoryBuilder.testEventsCarryStructuredSourceAddresses()
    h.withTestImport(function()
        local plan, catalog = loadPlan()
        local history = h.testImport("mods/history/builder.lua").build(plan, {
            catalog = catalog,
        })

        lu.assertEquals(history.events[5].sourceAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 1,
            doorIndex = 1,
            offerIndex = 1,
        })
        lu.assertEquals(history.events[10].sourceAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
        })
    end)
end

function TestHistoryBuilder.testBuilderRejectsMalformedPlanAtBoundary()
    h.withTestImport(function()
        local _, catalog = loadPlan()
        local builder = h.testImport("mods/history/builder.lua")

        local ok, err = pcall(function()
            builder.build({
                routeKey = "Underworld",
                biomes = {
                    {
                        biomeKey = "F",
                        rooms = {},
                    },
                },
            }, {
                catalog = catalog,
            })
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "history.plan.biomes[1].rooms")
    end)
end
