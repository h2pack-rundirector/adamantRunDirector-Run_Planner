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
                                    targetRoomKey = "F_Combat01",
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
                        roomKey = "F_Combat01",
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
                                                rewardType = "MaxHealthDrop",
                                                acquired = false,
                                            },
                                        },
                                    },
                                },
                            },
                        },
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

local BASIC_REWARD_TYPES = {
    "MaxHealthDrop",
    "MaxManaDrop",
    "RoomMoneyDrop",
}

local function offerForTarget(exitIndex, targetRoomKey)
    if targetRoomKey == "F_Shop01" then
        return {
            store = "WorldShop",
            rewardType = "HermesUpgrade",
            acquired = false,
        }
    end

    return {
        store = "RunProgress",
        rewardType = BASIC_REWARD_TYPES[((exitIndex - 1) % #BASIC_REWARD_TYPES) + 1],
        acquired = false,
    }
end

local function generatedDoor(exitIndex, targetRoomKey)
    return {
        exitIndex = exitIndex,
        targetRoomKey = targetRoomKey,
        offerPoint = {
            kind = "generatedDoorRewards",
            batchKey = "nextDoors",
            offers = {
                offerForTarget(exitIndex, targetRoomKey),
            },
        },
    }
end

local function roomWithDoors(roomKey, selectedDoorIndex, targetRoomKeys)
    local doors = {}
    for index, targetRoomKey in ipairs(targetRoomKeys) do
        doors[index] = generatedDoor(index, targetRoomKey)
    end
    return {
        roomKey = roomKey,
        generatedDoors = {
            batchRule = "Standard",
            selectedDoorIndex = selectedDoorIndex or 1,
            doors = doors,
        },
    }
end

local function longFRouteDraft()
    return {
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "F",
                rooms = {
                    roomWithDoors("F_Opening01", 1, { "F_Combat01" }),
                    roomWithDoors("F_Combat01", 1, { "F_Combat02" }),
                    roomWithDoors("F_Combat02", 1, { "F_Combat03", "F_Combat19" }),
                    roomWithDoors("F_Combat03", 1, { "F_Combat04", "F_Combat21" }),
                    roomWithDoors("F_Combat04", 1, { "F_Combat08", "F_Combat22" }),
                    roomWithDoors("F_Combat08", 1, { "F_Combat05", "F_Combat11" }),
                    roomWithDoors("F_Combat05", 1, { "F_Shop01", "F_Combat12" }),
                    roomWithDoors("F_Shop01", 1, { "F_Combat06", "F_Combat13" }),
                    roomWithDoors("F_Combat06", 1, { "F_Combat07", "F_Combat14" }),
                    roomWithDoors("F_Combat07", 1, { "F_Combat15", "F_Combat16" }),
                    roomWithDoors("F_Combat15", 1, { "F_Combat17", "F_Combat18" }),
                    roomWithDoors("F_Combat17", 1, { "F_PreBoss01", "F_Combat20" }),
                    {
                        roomKey = "F_PreBoss01",
                    },
                },
            },
        },
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
        lu.assertEquals(#result.history.events, 14)
        lu.assertTrue(result.validation.valid)
    end)
end

function TestRoutePipeline.testExpandedFDeclarationSupportsLongRouteToPreboss()
    h.withTestImport(function()
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local result = pipeline.evaluate(longFRouteDraft(), context())

        lu.assertEquals(result.state, "valid")
        lu.assertTrue(result.complete)
        lu.assertTrue(result.valid)
        lu.assertEquals(result.feedback, {})
        lu.assertEquals(result.history.roomHistory[#result.history.roomHistory].roomKey, "F_PreBoss01")
    end)
end

function TestRoutePipeline.testStructurallyInvalidDraftReturnsValidatorFeedback()
    h.withTestImport(function()
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[2].generatedDoors.doors[2] = {
            exitIndex = 1,
            targetRoomKey = "F_Opening01",
            offerPoint = {
                kind = "generatedDoorRewards",
                batchKey = "nextDoors",
                offers = {
                    {
                        store = "MetaProgress",
                        rewardType = "GiftDrop",
                        acquired = false,
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
        lu.assertEquals(result.feedback[1].payload.expectedCount, 1)
        lu.assertEquals(result.status.firstIssue.code, "generated_door_count_mismatch")
    end)
end

function TestRoutePipeline.testTimingInvalidDraftReturnsRequirementFeedback()
    h.withTestImport(function()
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey = "F_PreBoss01"

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "invalid")
        lu.assertEquals(result.feedback[1].code, "f_preboss_too_early")
        lu.assertEquals(result.feedback[1].payload.axis, "BiomeDepthCache")
        lu.assertEquals(result.feedback[1].payload.actual, 0)
        lu.assertEquals(result.feedback[1].payload.expected, 10)
        lu.assertEquals(result.feedback[1].address, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        })
    end)
end

function TestRoutePipeline.testCandidateResultsUseCreationCaps()
    h.withTestImport(function()
        local candidateProvider = h.testImport("mods/forms/candidate_provider.lua")
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[2].generatedDoors.doors[1].candidateProviders = {
            nextDoorTarget = candidateProvider.create({
                key = "nextDoorTarget",
                version = 11,
                values = { "F_Combat01", "F_Combat02" },
                labels = { "Combat 1", "Combat 2" },
                semanticForValue = function(value, _index, _formAddress, candidateContext)
                    return {
                        kind = "nextRoom",
                        biomeKey = candidateContext.candidate.biomeKey,
                        sourceRoomKey = candidateContext.candidate.sourceRoomKey,
                        exitIndex = candidateContext.candidate.exitIndex,
                        targetRoomKey = value,
                    }
                end,
            }),
        }

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "valid")
        lu.assertEquals(#result.candidateResults, 1)
        lu.assertEquals(result.candidateResults[1].code, "room_creation_cap_exceeded")
        lu.assertEquals(result.candidateResults[1].payload.targetRoomKey, "F_Combat01")
        lu.assertEquals(result.candidateResults[1].payload.actualCount, 2)
        lu.assertEquals(result.candidateResults[1].payload.maxCreationsThisRun, 1)
    end)
end

function TestRoutePipeline.testCandidateCreationCapsIgnoreFutureGeneratedRooms()
    h.withTestImport(function()
        local candidateProvider = h.testImport("mods/forms/candidate_provider.lua")
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[1].generatedDoors.doors[1].candidateProviders = {
            nextDoorTarget = candidateProvider.create({
                key = "nextDoorTarget",
                version = 12,
                values = { "F_Combat01", "F_Combat02" },
                labels = { "Combat 1", "Combat 2" },
                semanticForValue = function(value, _index, _formAddress, candidateContext)
                    return {
                        kind = "nextRoom",
                        biomeKey = candidateContext.candidate.biomeKey,
                        sourceRoomKey = candidateContext.candidate.sourceRoomKey,
                        exitIndex = candidateContext.candidate.exitIndex,
                        targetRoomKey = value,
                    }
                end,
            }),
        }

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "valid")
        lu.assertEquals(#result.candidateResults, 0)
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
            values = { "F_Combat02", "F_Missing01" },
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

        local summary = pipeline.applyCandidateFeedback(draft, result)
        lu.assertEquals(summary, {
            cleared = 1,
            applied = 1,
            stale = 0,
            missing = 0,
        })
        lu.assertEquals(provider.messages[2], "Generated door target room is not declared.")
        lu.assertFalse(provider.hidden[2])
    end)
end

function TestRoutePipeline.testRewardCandidateResultsDoNotInvalidateSelectedRoute()
    h.withTestImport(function()
        local candidateProvider = h.testImport("mods/forms/candidate_provider.lua")
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        local provider = candidateProvider.create({
            key = "rewardType",
            version = 16,
            values = { "Boon", "GiftDrop" },
            labels = { "Boon", "Gift" },
            semanticForValue = function(value, _index, _formAddress, candidateContext)
                return {
                    kind = "rewardType",
                    store = candidateContext.candidate.store,
                    rewardType = value,
                    payload = {},
                }
            end,
        })
        draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.offers[1].candidateProviders = {
            rewardType = provider,
        }

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "valid")
        lu.assertTrue(result.valid)
        lu.assertEquals(result.feedback, {})
        lu.assertEquals(#result.candidateRecords, 2)
        lu.assertEquals(#result.candidateResults, 1)
        lu.assertEquals(result.candidateResults[1].code, "reward_type_not_in_store")
        lu.assertEquals(result.candidateResults[1].providerKey, "rewardType")
        lu.assertEquals(result.candidateResults[1].candidateKey, "GiftDrop")
        lu.assertEquals(result.candidateResults[1].formAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 1,
            doorIndex = 1,
            offerIndex = 1,
        })

        local summary = pipeline.applyCandidateFeedback(draft, result)
        lu.assertEquals(summary, {
            cleared = 1,
            applied = 1,
            stale = 0,
            missing = 0,
        })
        lu.assertEquals(provider.messages[2], "Reward type is not part of the selected reward store.")
        lu.assertFalse(provider.hidden[2])
    end)
end

function TestRoutePipeline.testCandidateResultsUseTimingEligibility()
    h.withTestImport(function()
        local candidateProvider = h.testImport("mods/forms/candidate_provider.lua")
        local pipeline = h.testImport("mods/pipeline/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[2].generatedDoors.doors[1].candidateProviders = {
            nextDoorTarget = candidateProvider.create({
                key = "nextDoorTarget",
                version = 10,
                values = { "F_Combat02", "F_PreBoss01" },
                labels = { "Combat", "Preboss" },
                semanticForValue = function(value, _index, _formAddress, candidateContext)
                    return {
                        kind = "nextRoom",
                        biomeKey = candidateContext.candidate.biomeKey,
                        sourceRoomKey = candidateContext.candidate.sourceRoomKey,
                        exitIndex = candidateContext.candidate.exitIndex,
                        targetRoomKey = value,
                    }
                end,
            }),
        }

        local result = pipeline.evaluate(draft, context())

        lu.assertEquals(result.state, "valid")
        lu.assertEquals(#result.candidateResults, 1)
        lu.assertEquals(result.candidateResults[1].code, "f_preboss_too_early")
        lu.assertEquals(result.candidateResults[1].presentation, "hide")
        lu.assertEquals(result.candidateResults[1].payload.axis, "BiomeDepthCache")
        lu.assertEquals(result.candidateResults[1].payload.actual, 0)
        lu.assertEquals(result.candidateResults[1].payload.expected, 10)
        lu.assertEquals(result.candidateResults[1].candidateKey, "F_PreBoss01")
    end)
end
