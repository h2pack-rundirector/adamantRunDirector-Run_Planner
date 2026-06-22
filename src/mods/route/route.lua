local routeFactory = {}

local function createRewardPlanning(invalidLocations, routeMarkers)
    local rewardItems = import("mods/route/reward_planning/items.lua")
    local rewardSemantics = import("mods/route/reward_planning/semantics.lua")
    local rewardMarkers = import("mods/route/reward_planning/marker_targets.lua", nil, {
        markers = routeMarkers,
        semantics = rewardSemantics,
        invalidLocations = invalidLocations,
    })
    local rewardLegality = import("mods/route/reward_planning/legality.lua", nil, {
        conditions = import("mods/rewards/declarations/conditions.lua"),
        rewardItems = rewardItems,
        semantics = rewardSemantics,
        invalidLocations = invalidLocations,
        context = import("mods/route/reward_planning/context.lua"),
        markers = rewardMarkers,
    })

    return {
        rewardItems = rewardItems,
        rewardSemantics = rewardSemantics,
        rewardLegality = rewardLegality,
    }
end

local function createRouteTargets(routeTimeline, planning)
    local targetCommon = import("mods/route/run_context/targets/common.lua")
    return import("mods/route/run_context/targets.lua", nil, {
        npcs = import("mods/route/run_context/targets/npcs.lua", nil, {
            timeline = routeTimeline,
            rewardItems = planning.rewardItems,
            semantics = planning.rewardSemantics,
            common = targetCommon,
        }),
        features = import("mods/route/run_context/targets/features.lua", nil, {
            timeline = routeTimeline,
            common = targetCommon,
        }),
    })
end

function routeFactory.create(opts)
    opts = opts or {}

    local rewards = opts.rewards

    local routeTimeline = import("mods/route/timeline.lua")
    local invalidLocations = import("mods/route/invalid_locations.lua")
    local routeMarkers = import("mods/route/markers.lua")
    local planning = createRewardPlanning(invalidLocations, routeMarkers)
    local rows = import("mods/route/rows.lua", nil, {
        rewards = rewards,
        timeline = routeTimeline,
    })
    local targetMarkers = import("mods/route/target_markers.lua", nil, {
        markers = routeMarkers,
        valueStates = rows.valueStates,
    })

    local route = {
        common = rows.common,
        availability = rows.availability,
        readCache = rows.readCache,
        requirements = rows.requirements,
        biomeRules = rows.biomeRules,
        valueStates = rows.valueStates,
        rowEngine = rows.engine,
        timeline = routeTimeline,
        markers = routeMarkers,
        targetMarkers = targetMarkers,
        invalidLocations = invalidLocations,
        rewards = rewards,
        rewardItems = planning.rewardItems,
        rewardSemantics = planning.rewardSemantics,
        rewardLegality = planning.rewardLegality,
    }
    route.runContext = import("mods/route/run_context.lua", nil, {
        controls = import("mods/route/run_context/controls.lua"),
        targets = createRouteTargets(routeTimeline, planning),
        rewards = import("mods/route/run_context/rewards.lua", nil, {
            rewardLegality = planning.rewardLegality,
            semantics = planning.rewardSemantics,
            timeline = routeTimeline,
            valueStates = rows.valueStates,
        }),
    })
    return route
end

return routeFactory
