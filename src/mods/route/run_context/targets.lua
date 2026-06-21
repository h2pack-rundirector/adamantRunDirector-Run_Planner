local deps = ... or {}
local npcTargets = deps.npcs
local featureTargets = deps.features

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
