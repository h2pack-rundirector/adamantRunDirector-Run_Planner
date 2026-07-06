-- luacheck: globals TestRoutePipeline

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestRoutePipeline = {}

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

local function context()
    return {
        catalog = h.testImport("mods/data.lua").loadCatalog(),
    }
end

function TestRoutePipeline.testIncompleteDraftStopsBeforeMaterialization()
    h.withTestImport(function()
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = {
            routeKey = "Underworld",
            biomes = {
                {
                    biomeKey = "F",
                    rooms = {
                        { roomKey = "F_Opening01" },
                    },
                },
            },
        }

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "incomplete")
        lu.assertFalse(result.complete)
        lu.assertFalse(result.valid)
        lu.assertNil(result.plan)
        lu.assertNil(result.history)
        lu.assertEquals(result.status.firstIssue.code, "generated_doors_required")
        lu.assertEquals(result.feedback[1].address, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 1,
        })
    end)
end

function TestRoutePipeline.testValidDraftBuildsPlanHistoryAndValidation()
    h.withTestImport(function()
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local result = pipeline.evaluate(completeDraft(), context())

        lu.assertEquals(result.state, "valid")
        lu.assertTrue(result.complete)
        lu.assertTrue(result.valid)
        lu.assertEquals(result.feedback, {})
        lu.assertEquals(result.status.feedbackCount, 0)
        lu.assertEquals(result.plan.routeKey, "Underworld")
        lu.assertEquals(#result.history.events, 20)
        lu.assertTrue(result.validation.valid)
    end)
end

function TestRoutePipeline.testStructurallyInvalidDraftReturnsValidatorFeedback()
    h.withTestImport(function()
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[2].generatedDoors = {
            batchRule = "Standard",
            selectedDoorIndex = 1,
            doors = {
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
        }

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "invalid")
        lu.assertTrue(result.complete)
        lu.assertFalse(result.valid)
        lu.assertNotNil(result.plan)
        lu.assertNotNil(result.history)
        lu.assertFalse(result.validation.valid)
        lu.assertEquals(result.feedback[1].code, "generated_door_count_mismatch")
        lu.assertEquals(result.feedback[1].address, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
        })
        lu.assertEquals(result.feedback[1].phase, "room.generate_next")
        lu.assertEquals(result.feedback[1].payload.expectedCount, 2)
        lu.assertEquals(result.status.firstIssue.code, "generated_door_count_mismatch")
    end)
end

function TestRoutePipeline.testUnresolvedRewardUsesCompletionFeedback()
    h.withTestImport(function()
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.offers[1].rewardType = "Auto"

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "incomplete")
        lu.assertEquals(result.feedback[1].severity, "incomplete")
        lu.assertEquals(result.feedback[1].code, "reward_type_required")
        lu.assertEquals(result.feedback[1].field, "rewardType")
    end)
end

function TestRoutePipeline.testCandidateResultsDoNotInvalidateSelectedRoute()
    h.withTestImport(function()
        local candidateProvider = h.testImport("mods/forms/candidate_provider.lua")
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        local provider = candidateProvider.create({
            key = "nextDoorTarget",
            version = 9,
            values = { "F_Combat01", "F_Missing01" },
            labels = { "Combat", "Missing" },
            semanticForValue = function(value, _index, _formAddress, candidateContext)
                return {
                    kind = "nextRoom",
                    biomeKey = candidateContext.candidate.biomeKey,
                    sourceRoomKey = candidateContext.candidate.sourceRoomKey,
                    exitIndex = candidateContext.candidate.exitIndex,
                    targetRoomKey = value,
                }
            end,
        })
        draft.biomes[1].rooms[2].generatedDoors.doors[1].candidateProviders = {
            nextDoorTarget = provider,
        }

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "valid")
        lu.assertTrue(result.valid)
        lu.assertEquals(result.feedback, {})
        lu.assertEquals(#result.candidateRecords, 2)
        lu.assertEquals(result.history.candidateRecords, result.candidateRecords)
        lu.assertEquals(#result.candidateResults, 1)
        lu.assertEquals(result.candidateResults[1].code, "generated_door_target_unknown")
        lu.assertEquals(result.candidateResults[1].presentation, "invalid")
        lu.assertEquals(result.candidateResults[1].providerKey, "nextDoorTarget")
        lu.assertEquals(result.candidateResults[1].providerVersion, 9)
        lu.assertEquals(result.candidateResults[1].candidateKey, "F_Missing01")
        lu.assertEquals(result.candidateResults[1].candidateIndex, 2)
        lu.assertEquals(result.candidateResults[1].formAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        })

        local applied = provider.applyCandidateFeedback(result.candidateResults[1])
        lu.assertTrue(applied)
        lu.assertEquals(provider.messages[2], "Generated door target room is not declared.")
        lu.assertFalse(provider.hidden[2])
    end)
end
