-- luacheck: globals TestRewardValidator

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestRewardValidator = {}

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

local function loadCatalog()
    return h.testImport("mods/data.lua").loadCatalog()
end

local function materializePlan(draft, catalog)
    return h.testImport("mods/forms/route.lua").materialize(draft, {
        catalog = catalog,
    })
end

local function buildHistory(plan, catalog, opts)
    opts = opts or {}
    return h.testImport("mods/history/builder.lua").build(plan, {
        catalog = catalog,
        initialClearedBiomes = opts.initialClearedBiomes,
    })
end

local function validatePlan(plan, catalog, opts)
    local history = buildHistory(plan, catalog, opts)
    return h.testImport("mods/validation/rewards.lua").validate(history, {
        catalog = catalog,
    })
end

local function validateDraft(draft, opts)
    local catalog = loadCatalog()
    local plan = materializePlan(draft, catalog)
    return validatePlan(plan, catalog, opts)
end

local function offerAt(draft, roomIndex, doorIndex, offerIndex)
    return draft.biomes[1].rooms[roomIndex].generatedDoors.doors[doorIndex].offerPoint.offers[offerIndex]
end

function TestRewardValidator.testValidGeneratedDoorOfferDomainsPass()
    h.withTestImport(function()
        local result = validateDraft(completeDraft())

        lu.assertTrue(result.valid)
        lu.assertEquals(result.findings, {})
    end)
end

function TestRewardValidator.testRejectsUnknownRewardStore()
    h.withTestImport(function()
        local draft = completeDraft()
        draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.offers[1].store = "MissingStore"

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "reward_store_unknown")
        lu.assertEquals(result.findings[1].payload.store, "MissingStore")
        lu.assertEquals(result.findings[1].sourceAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 1,
            doorIndex = 1,
            offerIndex = 1,
        })
    end)
end

function TestRewardValidator.testRejectsRewardOutsideStore()
    h.withTestImport(function()
        local draft = completeDraft()
        draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.offers[1].rewardType = "GiftDrop"

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "reward_type_not_in_store")
        lu.assertEquals(result.findings[1].payload, {
            store = "RunProgress",
            rewardType = "GiftDrop",
        })
    end)
end

function TestRewardValidator.testRejectsOfferOutsideTargetProfile()
    h.withTestImport(function()
        local draft = completeDraft()
        local offer = draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.offers[1]
        offer.store = "WorldShop"
        offer.rewardType = "HermesUpgrade"

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "reward_offer_domain_mismatch")
        lu.assertEquals(result.findings[1].payload.targetRoomKey, "F_Combat01")
        lu.assertEquals(result.findings[1].payload.offerProfile, "RunProgressMajorMinor")
        lu.assertEquals(result.findings[1].payload.store, "WorldShop")
    end)
end

function TestRewardValidator.testRejectsTargetWithoutOfferProfile()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[1].generatedDoors.doors[1].targetRoomKey = "F_Opening01"

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "reward_offer_profile_missing")
        lu.assertEquals(result.findings[1].payload.targetRoomKey, "F_Opening01")
    end)
end

function TestRewardValidator.testRejectsGeneratedDoorOfferPointKindMismatch()
    h.withTestImport(function()
        local draft = completeDraft()
        draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.kind = "shipWheel"

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "offer_point_kind_invalid")
        lu.assertEquals(result.findings[1].payload.offerPointKind, "shipWheel")
        lu.assertEquals(result.findings[1].payload.expectedOfferPointKind, "generatedDoorRewards")
    end)
end

function TestRewardValidator.testAllowsFirstHammerWithoutPriorHammer()
    h.withTestImport(function()
        local draft = completeDraft()
        local offer = offerAt(draft, 1, 1, 1)
        offer.rewardType = "WeaponUpgrade"
        offer.acquired = true

        local result = validateDraft(draft)

        lu.assertTrue(result.valid)
        lu.assertEquals(result.findings, {})
    end)
end

function TestRewardValidator.testRejectsSecondHammerBeforeClearedBiomes()
    h.withTestImport(function()
        local draft = completeDraft()
        local firstHammer = offerAt(draft, 1, 1, 1)
        firstHammer.rewardType = "WeaponUpgrade"
        firstHammer.acquired = true
        local secondHammer = offerAt(draft, 2, 1, 1)
        secondHammer.rewardType = "WeaponUpgrade"
        secondHammer.acquired = false

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "late_hammer_requires_cleared_biomes")
        lu.assertEquals(result.findings[1].payload.store, "RunProgress")
        lu.assertEquals(result.findings[1].payload.rewardType, "WeaponUpgrade")
        lu.assertEquals(result.findings[1].payload.axis, "ClearedBiomes")
        lu.assertEquals(result.findings[1].payload.actual, 0)
        lu.assertEquals(result.findings[1].payload.expected, 2)
    end)
end

function TestRewardValidator.testAllowsLateHammerAfterFirstHammerAndClearedBiomes()
    h.withTestImport(function()
        local draft = completeDraft()
        local firstHammer = offerAt(draft, 1, 1, 1)
        firstHammer.rewardType = "WeaponUpgrade"
        firstHammer.acquired = true
        local secondHammer = offerAt(draft, 2, 1, 1)
        secondHammer.rewardType = "WeaponUpgrade"
        secondHammer.acquired = false

        local result = validateDraft(draft, {
            initialClearedBiomes = 3,
        })

        lu.assertTrue(result.valid)
        lu.assertEquals(result.findings, {})
    end)
end
