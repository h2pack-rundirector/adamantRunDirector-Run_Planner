-- luacheck: globals TestRouteForm

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestRouteForm = {}

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

local function loadContext()
    local catalog = h.testImport("mods/data.lua").loadCatalog()
    return {
        catalog = catalog,
    }
end

function TestRouteForm.testIncompleteDraftReturnsCompletionFindings()
    h.withTestImport(function()
        local routeForm = h.testImport("mods/forms/route.lua")
        local draft = {
            routeKey = "Underworld",
            biomes = {
                {
                    biomeKey = "F",
                    rooms = {
                        {
                            roomKey = "F_Opening01",
                        },
                    },
                },
            },
        }

        local result = routeForm.isComplete(draft, loadContext())

        lu.assertFalse(result.complete)
        lu.assertEquals(result.findings[1].code, "generated_doors_required")
        lu.assertEquals(result.findings[1].address, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 1,
        })
    end)
end

function TestRouteForm.testCompleteDraftMaterializesCanonicalPlan()
    h.withTestImport(function()
        local routeForm = h.testImport("mods/forms/route.lua")
        local draft = completeDraft()

        local result = routeForm.isComplete(draft, loadContext())
        lu.assertTrue(result.complete)

        local plan = routeForm.materialize(draft, loadContext())
        lu.assertEquals(plan.routeKey, "Underworld")
        lu.assertEquals(plan.biomes[1].biomeKey, "F")
        lu.assertEquals(plan.biomes[1].rooms[1].roomKey, "F_Opening01")
        lu.assertEquals(plan.biomes[1].rooms[1].generatedDoors.selectedDoorIndex, 1)
        lu.assertEquals(plan.biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey, "F_Combat01")
        lu.assertEquals(plan.biomes[1].rooms[2].generatedDoors.doors[2].targetRoomKey, "F_PreBoss01")
        lu.assertNil(plan.biomes[1].rooms[1].generatedDoors.doors[1].picked)
        lu.assertNil(plan.biomes[1].rooms[1].generatedDoors.doors[1].other)
    end)
end

function TestRouteForm.testMaterializeRejectsIncompleteDraft()
    h.withTestImport(function()
        local routeForm = h.testImport("mods/forms/route.lua")
        local draft = routeForm.defaultDraft({ routeKey = "Underworld" })

        local ok, err = pcall(function()
            routeForm.materialize(draft, loadContext())
        end)

        lu.assertFalse(ok)
        lu.assertStrContains(err, "cannot materialize incomplete route draft")
    end)
end

function TestRouteForm.testUnresolvedRewardValuesStayIncomplete()
    h.withTestImport(function()
        local routeForm = h.testImport("mods/forms/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.offers[1].rewardType = "Major"

        local result = routeForm.isComplete(draft, loadContext())

        lu.assertFalse(result.complete)
        lu.assertEquals(result.findings[1].code, "reward_type_required")
        lu.assertEquals(result.findings[1].field, "rewardType")
    end)
end

function TestRouteForm.testConfiguredBiomesMustFollowRoutePrefix()
    h.withTestImport(function()
        local routeForm = h.testImport("mods/forms/route.lua")
        local draft = completeDraft()
        draft.biomes[1].biomeKey = "G"

        local result = routeForm.isComplete(draft, loadContext())

        lu.assertFalse(result.complete)
        lu.assertEquals(result.findings[1].code, "biome_prefix_mismatch")
    end)
end

function TestRouteForm.testSelectedDoorMustTargetNextRoomNode()
    h.withTestImport(function()
        local routeForm = h.testImport("mods/forms/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[2].generatedDoors.selectedDoorIndex = 1

        local result = routeForm.isComplete(draft, loadContext())

        lu.assertFalse(result.complete)
        lu.assertEquals(result.findings[1].code, "selected_door_target_mismatch")
    end)
end

function TestRouteForm.testCandidateProviderOwnsStableDrawArrays()
    h.withTestImport(function()
        local provider = h.testImport("mods/forms/candidate_provider.lua").create({
            key = "nextDoorTarget",
            version = 3,
            values = { "F_Combat01", "F_Combat02" },
            labels = { "C01", "C02" },
        })

        lu.assertEquals(provider.hidden, { false, false })
        local applied = provider.applyCandidateFeedback({
            providerVersion = 3,
            candidateIndex = 2,
            presentation = "hide",
            color = { 1, 0, 0, 1 },
            message = "Unavailable",
        })

        lu.assertTrue(applied)
        lu.assertTrue(provider.hidden[2])
        lu.assertEquals(provider.messages[2], "Unavailable")

        provider.clearCandidateFeedback()
        lu.assertEquals(provider.hidden, { false, false })
        lu.assertNil(provider.messages[2])
    end)
end

function TestRouteForm.testRouteFormExportsDoorCandidateRecords()
    h.withTestImport(function()
        local candidateProvider = h.testImport("mods/forms/candidate_provider.lua")
        local routeForm = h.testImport("mods/forms/route.lua")
        local draft = completeDraft()
        draft.biomes[1].rooms[2].generatedDoors.doors[1].candidateProviders = {
            nextDoorTarget = candidateProvider.create({
                key = "nextDoorTarget",
                version = 4,
                values = { "F_Combat01", "F_PreBoss01" },
                labels = { "Combat", "PreBoss" },
                semanticForValue = function(value, _index, _formAddress, context)
                    return {
                        kind = "nextRoom",
                        biomeKey = context.candidate.biomeKey,
                        sourceRoomKey = context.candidate.sourceRoomKey,
                        exitIndex = context.candidate.exitIndex,
                        targetRoomKey = value,
                        selected = context.candidate.selected,
                    }
                end,
            }),
        }

        local records = routeForm.exportCandidates(draft, loadContext())

        lu.assertEquals(#records, 2)
        lu.assertEquals(records[1].formAddress, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        })
        lu.assertEquals(records[1].providerKey, "nextDoorTarget")
        lu.assertEquals(records[1].providerVersion, 4)
        lu.assertEquals(records[1].candidateKey, "F_Combat01")
        lu.assertEquals(records[1].candidateIndex, 1)
        lu.assertEquals(records[1].semantic, {
            kind = "nextRoom",
            biomeKey = "F",
            sourceRoomKey = "F_Combat02",
            exitIndex = 1,
            targetRoomKey = "F_Combat01",
            selected = false,
        })
    end)
end
