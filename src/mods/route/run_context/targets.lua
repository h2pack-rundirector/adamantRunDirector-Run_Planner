local deps = ... or {}
local npcTargets = deps.npcs
local featureTargets = deps.features

if npcTargets == nil then
    error("run_context.targets requires npc targets")
end
if featureTargets == nil then
    error("run_context.targets requires feature targets")
end

local targets = {}

function targets.emptyNpcTargets()
    return npcTargets.emptyTargets()
end

function targets.emptyFeatureTargets()
    return featureTargets.emptyTargets()
end

function targets.buildNpcTargets(context, routeKey)
    return npcTargets.buildTargets(context, routeKey)
end

function targets.buildFeatureTargets(context, routeKey)
    return featureTargets.buildTargets(context, routeKey)
end

return targets
