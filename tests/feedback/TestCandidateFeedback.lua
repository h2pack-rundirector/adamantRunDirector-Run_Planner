-- luacheck: globals TestCandidateFeedback

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestCandidateFeedback = {}

local function draftWithProvider(provider)
    return {
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "F",
                rooms = {
                    {
                        roomKey = "F_Combat02",
                        generatedDoors = {
                            doors = {
                                {
                                    candidateProviders = {
                                        nextDoorTarget = provider,
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

local function draftWithOfferProvider(provider)
    return {
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "F",
                rooms = {
                    {
                        roomKey = "F_Combat02",
                        generatedDoors = {
                            doors = {
                                {
                                    offerPoint = {
                                        offers = {
                                            {
                                                candidateProviders = {
                                                    rewardType = provider,
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
        },
    }
end

local function draftWithRoomOfferProvider(provider)
    return {
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "F",
                rooms = {
                    {
                        roomKey = "F_Shop01",
                        offerPoints = {
                            {
                                offers = {
                                    {
                                        candidateProviders = {
                                            rewardType = provider,
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

local function candidateResult(version, candidateIndex)
    return {
        formAddress = {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 1,
            doorIndex = 1,
        },
        providerKey = "nextDoorTarget",
        providerVersion = version,
        candidateKey = "F_Missing01",
        candidateIndex = candidateIndex,
        presentation = "hide",
        color = { 1, 0, 0, 1 },
        message = "Unavailable",
    }
end

local function offerCandidateResult(version, candidateIndex)
    local result = candidateResult(version, candidateIndex)
    result.formAddress.offerIndex = 1
    result.providerKey = "rewardType"
    result.candidateKey = "GiftDrop"
    return result
end

local function roomOfferCandidateResult(version, candidateIndex)
    local result = candidateResult(version, candidateIndex)
    result.formAddress.doorIndex = nil
    result.formAddress.offerPointIndex = 1
    result.formAddress.offerIndex = 1
    result.providerKey = "rewardType"
    result.candidateKey = "WeaponUpgradeDrop"
    return result
end

function TestCandidateFeedback.testAppliesMatchingVersionAndClearsOldState()
    h.withTestImport(function()
        local candidateFeedback = h.testImport("mods/feedback/candidates.lua")
        local provider = h.testImport("mods/forms/candidate_provider.lua").create({
            key = "nextDoorTarget",
            version = 5,
            values = { "F_Combat01", "F_Missing01" },
            labels = { "Combat", "Missing" },
        })
        provider.applyCandidateFeedback({
            providerVersion = 5,
            candidateIndex = 1,
            presentation = "hide",
            message = "Old",
        })

        local summary = candidateFeedback.apply(draftWithProvider(provider), {
            candidateResult(5, 2),
        })

        lu.assertEquals(summary, {
            cleared = 1,
            applied = 1,
            stale = 0,
            missing = 0,
        })
        lu.assertFalse(provider.hidden[1])
        lu.assertNil(provider.messages[1])
        lu.assertTrue(provider.hidden[2])
        lu.assertEquals(provider.messages[2], "Unavailable")
        lu.assertEquals(provider.colors[2], { 1, 0, 0, 1 })
    end)
end

function TestCandidateFeedback.testAppliesParticipantProvidersWithoutDraftBridge()
    h.withTestImport(function()
        local candidateFeedback = h.testImport("mods/feedback/candidates.lua")
        local participants = h.testImport("mods/ui/forms/participants.lua")
        local provider = h.testImport("mods/forms/candidate_provider.lua").create({
            key = "nextDoorTarget",
            version = 7,
            values = { "F_Combat01", "F_Missing01" },
            labels = { "Combat", "Missing" },
        })
        local registry = participants.create()
        registry:generatedDoor({
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 1,
            doorIndex = 1,
        }).providers.nextDoorTarget = provider

        local summary = candidateFeedback.apply(draftWithProvider(nil), {
            candidateResult(7, 2),
        }, {
            participants = registry,
        })

        lu.assertEquals(summary, {
            cleared = 1,
            applied = 1,
            stale = 0,
            missing = 0,
        })
        lu.assertTrue(provider.hidden[2])
        lu.assertEquals(provider.messages[2], "Unavailable")
    end)
end

function TestCandidateFeedback.testSkipsStaleVersionsAndMissingProviders()
    h.withTestImport(function()
        local candidateFeedback = h.testImport("mods/feedback/candidates.lua")
        local provider = h.testImport("mods/forms/candidate_provider.lua").create({
            key = "nextDoorTarget",
            version = 6,
            values = { "F_Combat01", "F_Missing01" },
            labels = { "Combat", "Missing" },
        })

        local missing = candidateResult(6, 2)
        missing.providerKey = "rewardType"

        local summary = candidateFeedback.apply(draftWithProvider(provider), {
            candidateResult(5, 2),
            missing,
        })

        lu.assertEquals(summary, {
            cleared = 1,
            applied = 0,
            stale = 1,
            missing = 1,
        })
        lu.assertFalse(provider.hidden[2])
        lu.assertNil(provider.messages[2])
    end)
end

function TestCandidateFeedback.testMalformedResultsDoNotClearProviders()
    h.withTestImport(function()
        local candidateFeedback = h.testImport("mods/feedback/candidates.lua")
        local provider = h.testImport("mods/forms/candidate_provider.lua").create({
            key = "nextDoorTarget",
            version = 6,
            values = { "F_Combat01", "F_Missing01" },
            labels = { "Combat", "Missing" },
        })
        provider.applyCandidateFeedback({
            providerVersion = 6,
            candidateIndex = 2,
            presentation = "hide",
            message = "Keep",
        })

        local ok, err = pcall(function()
            candidateFeedback.apply(draftWithProvider(provider), {
                {
                    providerKey = "nextDoorTarget",
                },
            })
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "candidateFeedback.candidateResults[1].formAddress")
        lu.assertTrue(provider.hidden[2])
        lu.assertEquals(provider.messages[2], "Keep")
    end)
end

function TestCandidateFeedback.testAppliesOfferCandidateFeedback()
    h.withTestImport(function()
        local candidateFeedback = h.testImport("mods/feedback/candidates.lua")
        local provider = h.testImport("mods/forms/candidate_provider.lua").create({
            key = "rewardType",
            version = 8,
            values = { "Boon", "GiftDrop" },
            labels = { "Boon", "Gift" },
        })

        local summary = candidateFeedback.apply(draftWithOfferProvider(provider), {
            offerCandidateResult(8, 2),
        })

        lu.assertEquals(summary, {
            cleared = 1,
            applied = 1,
            stale = 0,
            missing = 0,
        })
        lu.assertTrue(provider.hidden[2])
        lu.assertEquals(provider.messages[2], "Unavailable")
    end)
end

function TestCandidateFeedback.testAppliesRoomOfferCandidateFeedback()
    h.withTestImport(function()
        local candidateFeedback = h.testImport("mods/feedback/candidates.lua")
        local provider = h.testImport("mods/forms/candidate_provider.lua").create({
            key = "rewardType",
            version = 9,
            values = { "HermesUpgrade", "WeaponUpgradeDrop" },
            labels = { "Hermes", "Hammer" },
        })

        local summary = candidateFeedback.apply(draftWithRoomOfferProvider(provider), {
            roomOfferCandidateResult(9, 2),
        })

        lu.assertEquals(summary, {
            cleared = 1,
            applied = 1,
            stale = 0,
            missing = 0,
        })
        lu.assertTrue(provider.hidden[2])
        lu.assertEquals(provider.messages[2], "Unavailable")
    end)
end
