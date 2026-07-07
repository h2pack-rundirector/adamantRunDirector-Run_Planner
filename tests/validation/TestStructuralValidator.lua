-- luacheck: globals TestStructuralValidator

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestStructuralValidator = {}

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
                                                rewardType = "MaxHealthDrop",
                                                acquired = false,
                                            },
                                        },
                                    },
                                },
                                {
                                    exitIndex = 2,
                                    targetRoomKey = "F_Opening01",
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
                },
            },
        },
    }
end

local function loadCatalog()
    return h.testImport("mods/data.lua").loadCatalog()
end

local function buildHistory(plan, catalog)
    return h.testImport("mods/history/builder.lua").build(plan, {
        catalog = catalog,
    })
end

local function materializePlan(draft, catalog)
    return h.testImport("mods/forms/route.lua").materialize(draft, {
        catalog = catalog,
    })
end

local function validatePlan(plan, catalog)
    local history = buildHistory(plan, catalog)
    return h.testImport("mods/validation/structural.lua").validate(history, {
        catalog = catalog,
    })
end

local function findingCodes(result)
    local codes = {}
    for index, finding in ipairs(result.findings) do
        codes[index] = finding.code
    end
    table.sort(codes)
    return codes
end

local function findEvent(history, kind, roomIndex)
    for _, event in ipairs(history.events) do
        if event.kind == kind and event.roomIndex == roomIndex then
            return event
        end
    end
    return nil
end

local function generatedDoorOffer(store, rewardType)
    return {
        kind = "generatedDoorRewards",
        batchKey = "nextDoors",
        offers = {
            {
                store = store,
                rewardType = rewardType,
                acquired = false,
            },
        },
    }
end

local function oneDoorRoom(roomKey, targetRoomKey)
    return {
        roomKey = roomKey,
        generatedDoors = {
            batchRule = "Standard",
            selectedDoorIndex = 1,
            doors = {
                {
                    exitIndex = 1,
                    targetRoomKey = targetRoomKey,
                    offerPoint = generatedDoorOffer("RunProgress", "Boon"),
                },
            },
        },
    }
end

function TestStructuralValidator.testValidMinimalHistoryPasses()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        local result = validatePlan(plan, catalog)

        lu.assertTrue(result.valid)
        lu.assertEquals(result.findings, {})
    end)
end

function TestStructuralValidator.testDetectsGeneratedDoorCountMismatch()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        table.remove(plan.biomes[1].rooms[2].generatedDoors.doors, 1)
        plan.biomes[1].rooms[2].generatedDoors.selectedDoorIndex = 2

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertItemsEquals(findingCodes(result), {
            "generated_door_count_mismatch",
            "selected_door_missing",
        })
    end)
end

function TestStructuralValidator.testDetectsUndeclaredExitReferences()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors.doors[1].exitIndex = 99

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "generated_door_exit_unknown")
        lu.assertEquals(result.findings[1].payload.declaredExitCount, 2)
        lu.assertEquals(result.findings[1].sourceAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        })
    end)
end

function TestStructuralValidator.testDetectsUnknownDoorTargets()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey = "F_Missing01"

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "generated_door_target_unknown")
        lu.assertEquals(result.findings[1].payload.targetRoomKey, "F_Missing01")
    end)
end

function TestStructuralValidator.testDetectsSelectedDoorTargetMismatch()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[3] = {
            roomKey = "F_PreBoss01",
        }

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "selected_door_target_mismatch")
        lu.assertEquals(result.findings[1].payload.nextRoomKey, "F_PreBoss01")
    end)
end

function TestStructuralValidator.testDetectsTerminalRoomNotLast()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors = nil
        plan.biomes[1].rooms[3] = {
            roomKey = "F_PreBoss01",
        }
        plan.biomes[1].rooms[4] = {
            roomKey = "F_Combat01",
        }

        local history = buildHistory(plan, catalog)
        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "terminal_room_not_last")
        lu.assertEquals(result.findings[1].payload.nextRoomKey, "F_Combat01")
    end)
end

function TestStructuralValidator.testDetectsTerminalGeneratedDoors()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors = nil
        plan.biomes[1].rooms[3] = {
            roomKey = "F_PreBoss01",
        }
        plan.biomes[1].rooms[3].generatedDoors = {
            batchRule = "Standard",
            selectedDoorIndex = 1,
            doors = {
                {
                    exitIndex = 1,
                    targetRoomKey = "F_Combat01",
                    offerPoint = {
                        kind = "generatedDoorRewards",
                        offers = {
                            {
                                store = "RunProgress",
                                rewardType = "Boon",
                                acquired = true,
                            },
                        },
                    },
                },
            },
        }

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertItemsEquals(findingCodes(result), {
            "generated_door_exit_unknown",
            "terminal_room_generates_doors",
        })
    end)
end

function TestStructuralValidator.testDetectsRoomEligibilityAtGenerateNext()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey = "F_PreBoss01"

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "f_preboss_too_early")
        lu.assertEquals(result.findings[1].payload, {
            kind = "BiomeDepthCache",
            axis = "BiomeDepthCache",
            actual = 0,
            comparison = ">=",
            expected = 10,
            targetRoomKey = "F_PreBoss01",
            sourceRoomKey = "F_Combat02",
        })
        lu.assertEquals(result.findings[1].sourceAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        })
    end)
end

function TestStructuralValidator.testRoomEligibilityUsesBiomeEncounterDepth()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        local history = buildHistory(plan, catalog)
        findEvent(history, "room.generate_next", 2).biomeEncounterDepth = 6

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "f_combat01_late")
        lu.assertEquals(result.findings[1].payload.axis, "BiomeEncounterDepth")
        lu.assertEquals(result.findings[1].payload.actual, 6)
        lu.assertEquals(result.findings[1].payload.expected, 5)
    end)
end

function TestStructuralValidator.testRoomEnteredHistoryEligibilityIncludesCurrentRoomAtGenerateNext()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan({
            routeKey = "Underworld",
            biomes = {
                {
                    biomeKey = "F",
                    rooms = {
                        oneDoorRoom("F_Opening01", "F_MiniBoss01"),
                        oneDoorRoom("F_MiniBoss01", "F_MiniBoss02"),
                        oneDoorRoom("F_MiniBoss02", "F_Combat01"),
                    },
                },
            },
        }, catalog)

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "f_miniboss02_other_miniboss_entered")
        lu.assertEquals(result.findings[1].payload.axis, "RoomEnteredHistory")
        lu.assertEquals(result.findings[1].payload.actual, 1)
        lu.assertEquals(result.findings[1].payload.expected, 0)
        lu.assertEquals(result.findings[1].payload.roomKeys, {
            "F_MiniBoss01",
            "F_MiniBoss03",
        })
    end)
end

function TestStructuralValidator.testForceMetadataIsNotLocalTargetLegality()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey = "F_PreBoss01"
        plan.biomes[1].rooms[2].generatedDoors.doors[2].targetRoomKey = "F_MiniBoss01"
        plan.biomes[1].rooms[2].generatedDoors.doors[2].offerPoint = generatedDoorOffer("RunProgress", "Boon")
        local history = buildHistory(plan, catalog)
        findEvent(history, "room.generate_next", 2).biomeDepthCache = 11

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertTrue(result.valid)
    end)
end

function TestStructuralValidator.testForcePressureIgnoresUnstartedForceWindows()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        local history = buildHistory(plan, catalog)
        findEvent(history, "room.generate_next", 2).biomeDepthCache = 3

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertTrue(result.valid)
    end)
end

function TestStructuralValidator.testForcePressureDoesNotBlockBeforeDeadline()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        local history = buildHistory(plan, catalog)
        findEvent(history, "room.generate_next", 2).biomeDepthCache = 4

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertTrue(result.valid)
    end)
end

function TestStructuralValidator.testForcePressureRequiresForcedTargetsAtDeadline()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        local history = buildHistory(plan, catalog)
        findEvent(history, "room.generate_next", 2).biomeDepthCache = 6

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "force_pressure_missing_room")
        lu.assertEquals(result.findings[1].payload.roomKey, "F_Combat02")
        lu.assertEquals(result.findings[1].payload.deadlineForceRoomKeys, {
            "F_MiniBoss01",
            "F_MiniBoss02",
            "F_MiniBoss03",
            "F_Shop01",
        })
        lu.assertEquals(result.findings[1].payload.eligibleUnresolvedForceRoomKeys, {
            "F_MiniBoss01",
            "F_MiniBoss02",
            "F_MiniBoss03",
            "F_Shop01",
        })
        lu.assertEquals(result.findings[1].payload.generatedForceRoomKeys, {})
        lu.assertEquals(result.findings[1].payload.requiredForcedCount, 2)
        lu.assertEquals(result.findings[1].payload.generatedDoorCount, 2)
    end)
end

function TestStructuralValidator.testGeneratedForcedRoomSatisfiesPressure()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey = "F_Shop01"
        plan.biomes[1].rooms[2].generatedDoors.doors[1].offerPoint = generatedDoorOffer("WorldShop", "HermesUpgrade")
        plan.biomes[1].rooms[2].generatedDoors.doors[2].targetRoomKey = "F_MiniBoss01"
        plan.biomes[1].rooms[2].generatedDoors.doors[2].offerPoint = generatedDoorOffer("RunProgress", "Boon")
        local history = buildHistory(plan, catalog)
        findEvent(history, "room.generate_next", 2).biomeDepthCache = 6

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertTrue(result.valid)
    end)
end

function TestStructuralValidator.testGeneratedForcedRoomRemovesFuturePressure()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors.selectedDoorIndex = 2
        plan.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey = "F_Shop01"
        plan.biomes[1].rooms[2].generatedDoors.doors[1].offerPoint = generatedDoorOffer("WorldShop", "HermesUpgrade")
        plan.biomes[1].rooms[2].generatedDoors.doors[2].targetRoomKey = "F_MiniBoss01"
        plan.biomes[1].rooms[2].generatedDoors.doors[2].offerPoint = generatedDoorOffer("RunProgress", "Boon")
        plan.biomes[1].rooms[3] = {
            roomKey = "F_MiniBoss01",
            generatedDoors = {
                batchRule = "Standard",
                selectedDoorIndex = 1,
                doors = {
                    {
                        exitIndex = 1,
                        targetRoomKey = "F_Combat01",
                        offerPoint = generatedDoorOffer("RunProgress", "MaxHealthDrop"),
                    },
                },
            },
        }
        local history = buildHistory(plan, catalog)
        findEvent(history, "room.generate_next", 2).biomeDepthCache = 6
        findEvent(history, "room.generate_next", 3).biomeDepthCache = 6

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertTrue(result.valid)
    end)
end

function TestStructuralValidator.testCandidateForcePressureProjectsDoorTarget()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey = "F_Shop01"
        plan.biomes[1].rooms[2].generatedDoors.doors[1].offerPoint = generatedDoorOffer("WorldShop", "HermesUpgrade")
        plan.biomes[1].rooms[2].generatedDoors.doors[2].targetRoomKey = "F_MiniBoss01"
        plan.biomes[1].rooms[2].generatedDoors.doors[2].offerPoint = generatedDoorOffer("RunProgress", "Boon")
        local history = buildHistory(plan, catalog)
        findEvent(history, "room.generate_next", 2).biomeDepthCache = 6

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
            candidateRecords = {
                {
                    formAddress = {
                        routeKey = "Underworld",
                        biomeIndex = 1,
                        roomIndex = 2,
                        doorIndex = 1,
                    },
                    providerKey = "nextDoorTarget",
                    providerVersion = 1,
                    candidateKey = "F_Opening01",
                    candidateIndex = 1,
                    semantic = {
                        kind = "nextRoom",
                        biomeKey = "F",
                        sourceRoomKey = "F_Combat02",
                        exitIndex = 1,
                        targetRoomKey = "F_Opening01",
                    },
                },
            },
        })

        lu.assertTrue(result.valid)
        lu.assertEquals(#result.candidateResults, 1)
        lu.assertEquals(result.candidateResults[1].code, "force_pressure_conflict")
        lu.assertEquals(result.candidateResults[1].payload.deadlineForceRoomKeys, {
            "F_MiniBoss01",
            "F_MiniBoss02",
            "F_MiniBoss03",
            "F_Shop01",
        })
        lu.assertEquals(result.candidateResults[1].payload.requiredForcedCount, 2)
    end)
end

function TestStructuralValidator.testDetectsRoomCreationCaps()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[2].generatedDoors.doors[2].targetRoomKey = "F_Combat02"

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "room_creation_cap_exceeded")
        lu.assertEquals(result.findings[1].payload, {
            targetRoomKey = "F_Combat02",
            actualCount = 2,
            maxCreationsThisRun = 1,
        })
    end)
end

function TestStructuralValidator.testRoomCreationCapsIgnoreFutureGeneratedRooms()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local plan = materializePlan(completeDraft(), catalog)
        plan.biomes[1].rooms[3] = {
            roomKey = "F_Combat01",
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
                                    rewardType = "MaxHealthDrop",
                                    acquired = false,
                                },
                            },
                        },
                    },
                },
            },
        }

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "room_creation_cap_exceeded")
        lu.assertEquals(result.findings[1].sourceAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 3,
            doorIndex = 1,
        })
        lu.assertEquals(result.findings[1].payload, {
            targetRoomKey = "F_Combat01",
            actualCount = 2,
            maxCreationsThisRun = 1,
        })
    end)
end

function TestStructuralValidator.testDetectsExitTagMismatch()
    h.withTestImport(function()
        local catalog = loadCatalog()
        catalog.biomes.lookup.F.rooms.lookup.F_Combat02.exits[1].tags = { "Shop" }
        local plan = materializePlan(completeDraft(), catalog)

        local result = validatePlan(plan, catalog)

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "generated_door_exit_tags_mismatch")
        lu.assertEquals(result.findings[1].payload.exitTags, { "Shop" })
        lu.assertEquals(result.findings[1].payload.targetRoomKey, "F_Combat01")
        lu.assertEquals(result.findings[1].payload.targetTags, { "Combat" })
    end)
end

function TestStructuralValidator.testDetectsUnknownRoomsInManualHistory()
    h.withTestImport(function()
        local catalog = loadCatalog()
        local history = {
            events = {
                {
                    kind = "room.enter",
                    phase = "room.enter",
                    sourceAddress = {
                        routeKey = "Underworld",
                        biomeIndex = 1,
                        roomIndex = 1,
                    },
                    biomeKey = "F",
                    roomIndex = 1,
                    roomKey = "F_Missing01",
                },
            },
            roomHistory = {},
            generatedDoorHistory = {},
        }

        local result = h.testImport("mods/validation/structural.lua").validate(history, {
            catalog = catalog,
        })

        lu.assertFalse(result.valid)
        lu.assertEquals(result.findings[1].code, "room_unknown")
    end)
end
