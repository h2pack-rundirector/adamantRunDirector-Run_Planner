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
                                    targetRoomKey = "F_Combat02",
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
