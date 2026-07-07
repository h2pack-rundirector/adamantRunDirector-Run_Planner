-- luacheck: globals TestRewardValidator

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestRewardValidator = {}

local DEVOTION_ROOM_INDEX = 8

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

local function devotionDraft()
    local function offerDoor(exitIndex, targetRoomKey, offer)
        return {
            exitIndex = exitIndex,
            targetRoomKey = targetRoomKey,
            offerPoint = {
                kind = "generatedDoorRewards",
                batchKey = "nextDoors",
                offers = {
                    offer,
                },
            },
        }
    end

    local function combatRoom(roomKey, targetRoomKey, rewardType, opts)
        opts = opts or {}
        local offer = {
            store = "RunProgress",
            rewardType = rewardType,
            acquired = opts.acquired or false,
            payload = opts.payload,
        }
        local doors = {
            offerDoor(1, targetRoomKey, offer),
        }

        if opts.secondDoor then
            doors[2] = offerDoor(2, opts.secondDoor.targetRoomKey, opts.secondDoor.offer)
        end

        return {
            roomKey = roomKey,
            generatedDoors = {
                batchRule = "Standard",
                selectedDoorIndex = 1,
                doors = doors,
            },
        }
    end

    return {
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "F",
                rooms = {
                    combatRoom("F_Opening01", "F_Combat02", "Boon", {
                        acquired = true,
                        payload = {
                            source = "ApolloUpgrade",
                        },
                    }),
                    combatRoom("F_Combat02", "F_Combat01", "Boon", {
                        acquired = true,
                        payload = {
                            source = "PoseidonUpgrade",
                        },
                        secondDoor = {
                            targetRoomKey = "F_Combat01",
                            offer = {
                                store = "RunProgress",
                                rewardType = "MaxHealthDrop",
                                acquired = false,
                            },
                        },
                    }),
                    combatRoom("F_Combat01", "F_Combat02", "MaxHealthDrop"),
                    combatRoom("F_Combat02", "F_Combat01", "MaxManaDrop"),
                    combatRoom("F_Combat01", "F_Combat02", "RoomMoneyDrop"),
                    combatRoom("F_Combat02", "F_Combat01", "MaxHealthDrop"),
                    combatRoom("F_Combat01", "F_Combat02", "MaxManaDrop"),
                    combatRoom("F_Combat02", "F_Combat01", "Devotion", {
                        payload = {
                            sources = {
                                "ApolloUpgrade",
                                "PoseidonUpgrade",
                            },
                        },
                        secondDoor = {
                            targetRoomKey = "F_Combat01",
                            offer = {
                                store = "RunProgress",
                                rewardType = "MaxHealthDrop",
                                acquired = false,
                            },
                        },
                    }),
                },
            },
        },
    }
end

local function shopRoomDraft(opts)
    opts = opts or {}
    local shopOffer = {
        store = "WorldShop",
        rewardType = opts.shopRewardType or "WeaponUpgradeDrop",
        acquired = opts.shopAcquired or false,
    }

    local shopDoorOffer = {
        store = "RunProgress",
        rewardType = opts.generatedRewardType or "MaxHealthDrop",
        acquired = false,
    }

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
                                    targetRoomKey = "F_Shop01",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "WorldShop",
                                                rewardType = "HermesUpgrade",
                                                acquired = false,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    {
                        roomKey = "F_Shop01",
                        offerPoints = {
                            {
                                kind = opts.offerPointKind or "shop",
                                batchKey = "worldShop",
                                offers = {
                                    shopOffer,
                                },
                            },
                        },
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
                                            shopDoorOffer,
                                        },
                                    },
                                },
                                {
                                    exitIndex = 2,
                                    targetRoomKey = "F_Combat02",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "RunProgress",
                                                rewardType = "MaxManaDrop",
                                                acquired = false,
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
                                                rewardType = opts.nextRoomRewardType or "MaxHealthDrop",
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

local function validateHistory(history, catalog)
    return h.testImport("mods/validation/rewards.lua").validate(history, {
        catalog = catalog,
    })
end

local function validatePlanWithCandidates(plan, catalog, candidateRecords)
    local history = buildHistory(plan, catalog)
    return h.testImport("mods/validation/rewards.lua").validate(history, {
        catalog = catalog,
        candidateRecords = candidateRecords,
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

local function devotionOffer(draft)
    return offerAt(draft, DEVOTION_ROOM_INDEX, 1, 1)
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

function TestRewardValidator.testRejectsNonBoonOfferForMinibossProfile()
    h.withTestImport(function()
        local draft = completeDraft()
        local door = draft.biomes[1].rooms[1].generatedDoors.doors[1]
        door.targetRoomKey = "F_MiniBoss01"
        door.offerPoint.offers[1].rewardType = "MaxHealthDrop"
        draft.biomes[1].rooms[2].roomKey = "F_MiniBoss01"

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "reward_offer_domain_mismatch")
        lu.assertEquals(result.findings[1].payload.targetRoomKey, "F_MiniBoss01")
        lu.assertEquals(result.findings[1].payload.offerProfile, "RunProgressBoonOnly")
        lu.assertEquals(result.findings[1].payload.rewardType, "MaxHealthDrop")
    end)
end

function TestRewardValidator.testRejectsOfferRemovedByIneligibleRewardFilter()
    h.withTestImport(function()
        local catalog = loadCatalog()
        catalog.offerProfiles.RunProgressMajorMinor.ineligibleRewards = { "Boon" }
        local plan = materializePlan(completeDraft(), catalog)

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "reward_offer_domain_mismatch")
        lu.assertEquals(result.findings[1].payload.targetRoomKey, "F_Combat01")
        lu.assertEquals(result.findings[1].payload.offerProfile, "RunProgressMajorMinor")
        lu.assertEquals(result.findings[1].payload.rewardType, "Boon")
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

function TestRewardValidator.testRejectsUnknownBoonSourcePayload()
    h.withTestImport(function()
        local draft = completeDraft()
        local offer = offerAt(draft, 1, 1, 1)
        offer.payload = {
            source = "MissingUpgrade",
        }

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "reward_payload_source_unknown")
        lu.assertEquals(result.findings[1].payload.source, "MissingUpgrade")
        lu.assertEquals(result.findings[1].payload.rewardType, "Boon")
    end)
end

function TestRewardValidator.testRejectsDuplicateDevotionSources()
    h.withTestImport(function()
        local draft = devotionDraft()
        local offer = devotionOffer(draft)
        offer.payload.sources = {
            "ApolloUpgrade",
            "ApolloUpgrade",
        }

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "devotion_sources_not_distinct")
        lu.assertEquals(result.findings[1].payload.duplicateSource, "ApolloUpgrade")
        lu.assertEquals(result.findings[1].payload.sources, {
            "ApolloUpgrade",
            "ApolloUpgrade",
        })
    end)
end

function TestRewardValidator.testRejectsDevotionSourcesWithoutPriorLoot()
    h.withTestImport(function()
        local draft = devotionDraft()
        local offer = devotionOffer(draft)
        offer.payload.sources = {
            "ApolloUpgrade",
            "ZeusUpgrade",
        }

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "devotion_sources_not_acquired")
        lu.assertEquals(result.findings[1].payload.missingSources, { "ZeusUpgrade" })
    end)
end

function TestRewardValidator.testRejectsDevotionBeforeRunEncounterDepth()
    h.withTestImport(function()
        local draft = devotionDraft()
        draft.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey = "F_Combat02"
        draft.biomes[1].rooms = {
            draft.biomes[1].rooms[1],
            draft.biomes[1].rooms[2],
            draft.biomes[1].rooms[DEVOTION_ROOM_INDEX],
        }

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "devotion_requires_encounter_depth")
        lu.assertEquals(result.findings[1].payload.axis, "RunEncounterDepth")
        lu.assertEquals(result.findings[1].payload.actual, 2)
        lu.assertEquals(result.findings[1].payload.expected, 7)
    end)
end

function TestRewardValidator.testRejectsDevotionBeforeTrialSpacing()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(devotionDraft(), catalog)
        local history = buildHistory(plan, catalog)

        history.lootHistory[2].rewardType = "Devotion"
        history.lootHistory[2].acquiredLootType = "Devotion"

        local result = validateHistory(history, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "devotion_requires_trial_spacing")
        lu.assertEquals(result.findings[1].payload.axis, "RoomHistoryOrdinal")
        lu.assertEquals(result.findings[1].payload.actual, 5)
        lu.assertEquals(result.findings[1].payload.expected, 15)
    end)
end

function TestRewardValidator.testRejectsDevotionWithoutTwoGeneratedExits()
    h.withTestImport(function()
        local draft = devotionDraft()
        local doors = draft.biomes[1].rooms[DEVOTION_ROOM_INDEX].generatedDoors.doors
        doors[2] = nil

        local result = validateDraft(draft)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "devotion_requires_two_exits")
        lu.assertEquals(result.findings[1].payload.axis, "GeneratedDoorCount")
        lu.assertEquals(result.findings[1].payload.actual, 1)
        lu.assertEquals(result.findings[1].payload.expected, 2)
    end)
end

function TestRewardValidator.testAllowsDevotionAfterPriorSourceLoot()
    h.withTestImport(function()
        local result = validateDraft(devotionDraft())

        lu.assertTrue(result.valid)
        lu.assertEquals(result.findings, {})
    end)
end

function TestRewardValidator.testAllowsRoomLocalShopOffer()
    h.withTestImport(function()
        local result = validateDraft(shopRoomDraft())

        lu.assertTrue(result.valid)
        lu.assertEquals(result.findings, {})
    end)
end

function TestRewardValidator.testRejectsRoomLocalOfferOutsideCurrentRoomProfile()
    h.withTestImport(function()
        local result = validateDraft(shopRoomDraft({
            shopRewardType = "GiftDrop",
        }))

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "reward_type_not_in_shop")
        lu.assertEquals(result.findings[1].sourceAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            offerPointIndex = 1,
            offerIndex = 1,
        })
    end)
end

function TestRewardValidator.testPendingShopOfferBlocksSameRoomGeneratedReward()
    h.withTestImport(function()
        local result = validateDraft(shopRoomDraft({
            generatedRewardType = "WeaponUpgrade",
        }))

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "late_hammer_pending_in_shop")
        lu.assertEquals(result.findings[1].payload.store, "RunProgress")
        lu.assertEquals(result.findings[1].payload.rewardType, "WeaponUpgrade")
        lu.assertEquals(result.findings[1].payload.name, "WeaponUpgradeDrop")
    end)
end

function TestRewardValidator.testPendingShopOfferExpiresAfterRoomGeneration()
    h.withTestImport(function()
        local result = validateDraft(shopRoomDraft({
            nextRoomRewardType = "WeaponUpgrade",
        }))

        lu.assertTrue(result.valid)
        lu.assertEquals(result.findings, {})
    end)
end

function TestRewardValidator.testRewardTypeCandidateUsesSelectedRewardRules()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        local result = validatePlanWithCandidates(plan, catalog, {
            {
                formAddress = {
                    routeKey = "Underworld",
                    biomeIndex = 1,
                    roomIndex = 1,
                    doorIndex = 1,
                    offerIndex = 1,
                },
                providerKey = "rewardType",
                providerVersion = 13,
                candidateKey = "GiftDrop",
                candidateIndex = 2,
                semantic = {
                    kind = "rewardType",
                    store = "RunProgress",
                    rewardType = "GiftDrop",
                    payload = {},
                },
            },
        })

        lu.assertTrue(result.valid)
        lu.assertEquals(#result.candidateResults, 1)
        lu.assertEquals(result.candidateResults[1].code, "reward_type_not_in_store")
        lu.assertEquals(result.candidateResults[1].presentation, "invalid")
        lu.assertEquals(result.candidateResults[1].providerKey, "rewardType")
        lu.assertEquals(result.candidateResults[1].candidateKey, "GiftDrop")
    end)
end

function TestRewardValidator.testDevotionSourceCandidateUsesPayloadRules()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(devotionDraft(), catalog)
        local result = validatePlanWithCandidates(plan, catalog, {
            {
                formAddress = {
                    routeKey = "Underworld",
                    biomeIndex = 1,
                    roomIndex = DEVOTION_ROOM_INDEX,
                    doorIndex = 1,
                    offerIndex = 1,
                },
                providerKey = "devotionSource2",
                providerVersion = 14,
                candidateKey = "ZeusUpgrade",
                candidateIndex = 9,
                semantic = {
                    kind = "devotionSource",
                    sourceIndex = 2,
                    source = "ZeusUpgrade",
                    sources = {
                        "ApolloUpgrade",
                        "ZeusUpgrade",
                    },
                },
            },
        })

        lu.assertTrue(result.valid)
        lu.assertEquals(#result.candidateResults, 1)
        lu.assertEquals(result.candidateResults[1].code, "devotion_sources_not_acquired")
        lu.assertEquals(result.candidateResults[1].payload.missingSources, { "ZeusUpgrade" })
        lu.assertEquals(result.candidateResults[1].providerKey, "devotionSource2")
    end)
end

function TestRewardValidator.testUnknownRewardCandidateKindFailsContract()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        local ok, err = pcall(function()
            validatePlanWithCandidates(plan, catalog, {
                {
                    formAddress = {
                        routeKey = "Underworld",
                        biomeIndex = 1,
                        roomIndex = 1,
                        doorIndex = 1,
                        offerIndex = 1,
                    },
                    providerKey = "rewardType",
                    providerVersion = 15,
                    candidateKey = "Boon",
                    candidateIndex = 1,
                    semantic = {
                        kind = "missingKind",
                    },
                },
            })
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "unknown candidate kind 'missingKind'")
    end)
end
