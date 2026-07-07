-- luacheck: globals TestPlannerState

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestPlannerState = {}

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
