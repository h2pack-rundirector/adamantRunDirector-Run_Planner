local materialization = import("mods/ui/planner/materialization.lua")
local providerPreparation = import("mods/ui/planner/provider_preparation.lua")

local evaluation = {}

local function contextFor(state)
    return {
        catalog = state.catalog,
        participants = state.participants,
    }
end

function evaluation.evaluate(state)
    materialization.draftForRebuild(state.catalog, state.currentBiome())
    providerPreparation.prepare(state)

    local context = contextFor(state)
    state.evaluation = state.pipeline.evaluate(state.draft, context)
    state.pipeline.applyCandidateFeedback(state.draft, state.evaluation, context)
    state.dirty = false
    return state.evaluation
end

function evaluation.ensure(state)
    if state.dirty or state.evaluation == nil then
        return evaluation.evaluate(state)
    end
    return state.evaluation
end

return evaluation
