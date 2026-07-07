-- luacheck: globals TestPlannerState

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestPlannerState = {}

local function copyTable(source)
    if source == nil then
        return nil
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = copyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function sampleDraft()
    return h.testImport("mods/forms/defaults.lua").fSampleDraft()
end

local function fakeDraftControl(initialDraft)
    local stored = copyTable(initialDraft)
    local control = {
        reads = 0,
        writes = {},
    }

    function control:readDraft()
        self.reads = self.reads + 1
        return copyTable(stored)
    end

    function control:writeDraft(draft)
        stored = copyTable(draft)
        self.writes[#self.writes + 1] = copyTable(draft)
        return true
    end

    function control.storedDraft()
        return copyTable(stored)
    end

    return control
end

local function fakePipeline()
    local calls = {
        evaluate = 0,
        applyCandidateFeedback = 0,
    }
    return calls, {
        evaluate = function()
            calls.evaluate = calls.evaluate + 1
            return {
                state = "valid",
                complete = true,
                valid = true,
                status = {
                    feedbackCount = 0,
                },
                candidateResults = {},
                feedback = {},
            }
        end,
        applyCandidateFeedback = function()
            calls.applyCandidateFeedback = calls.applyCandidateFeedback + 1
            return {
                cleared = 0,
                applied = 0,
                stale = 0,
                missing = 0,
            }
        end,
    }
end

function TestPlannerState.testBindingDraftControlLoadsStoredDraftOnce()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local storedDraft = sampleDraft()
        storedDraft.biomes[1].rooms[1].generatedDoors.doors[1].targetRoomKey = "F_Combat02"
        local control = fakeDraftControl(storedDraft)
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })

        lu.assertTrue(state.bindDraftControl(control))
        lu.assertFalse(state.bindDraftControl(control))

        lu.assertEquals(control.reads, 1)
        lu.assertEquals(state.draft.biomes[1].rooms[1].generatedDoors.doors[1].targetRoomKey, "F_Combat02")
        lu.assertEquals(#control.writes, 0)
    end)
end

function TestPlannerState.testBoundDraftControlPersistsMutations()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local control = fakeDraftControl(sampleDraft())
        local state = plannerState.create({
            catalog = data.loadCatalog(),
            draftControl = control,
        })

        lu.assertTrue(state.setDoorTarget(2, 1, "F_PreBoss01"))
        lu.assertEquals(#control.writes, 1)
        lu.assertEquals(control.storedDraft().biomes[1].rooms[2].generatedDoors.doors[1].targetRoomKey, "F_PreBoss01")

        state.resetDraft()
        lu.assertEquals(#control.writes, 2)
        lu.assertEquals(control.storedDraft(), sampleDraft())
    end)
end

function TestPlannerState.testEvaluationCacheInvalidatesAfterMutation()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local calls, pipeline = fakePipeline()
        local state = plannerState.create({
            catalog = data.loadCatalog(),
            pipeline = pipeline,
        })

        state.ensureEvaluation()
        state.ensureEvaluation()

        lu.assertEquals(calls.evaluate, 1)
        lu.assertEquals(calls.applyCandidateFeedback, 1)

        lu.assertTrue(state.setDoorTarget(2, 1, "F_PreBoss01"))
        state.ensureEvaluation()

        lu.assertEquals(calls.evaluate, 2)
        lu.assertEquals(calls.applyCandidateFeedback, 2)
    end)
end

function TestPlannerState.testSelectedDoorOptionsAreCachedByDoorBatch()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        local generatedDoors = state.currentBiome().rooms[1].generatedDoors

        local first = state.selectedDoorOptions(generatedDoors)
        local second = state.selectedDoorOptions(generatedDoors)

        lu.assertTrue(first == second)
        lu.assertEquals(first.values, { 1 })
        lu.assertEquals(first.labels, { "Door 1" })

        generatedDoors.doors[#generatedDoors.doors + 1] = {
            exitIndex = 2,
            targetRoomKey = "F_Combat02",
        }
        local rebuilt = state.selectedDoorOptions(generatedDoors)

        lu.assertFalse(rebuilt == first)
        lu.assertEquals(rebuilt.values, { 1, 2 })
        lu.assertEquals(rebuilt.labels, { "Door 1", "Door 2" })
    end)
end

function TestPlannerState.testFeedbackLocationLabelsUseCurrentDraft()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })

        lu.assertEquals(state.feedbackLocationLabel({
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        }), "Room 2 (F_Combat01) door 1")
        lu.assertEquals(state.feedbackLocationLabel({
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 1,
            doorIndex = 1,
            offerIndex = 1,
        }), "Room 1 (F_Opening01) door 1 reward 1")
        lu.assertEquals(state.feedbackLocationLabel({
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            offerPointIndex = 1,
            offerIndex = 1,
        }), "Room 2 (F_Combat01) offer point 1 offer 1")
    end)
end
