local routeFactory = {}

local function createRewardPlanning(routeTimeline, invalidLocations)
    local rewardItems = import("mods/route/reward_planning/items.lua")
    local rewardSemantics = import("mods/route/reward_planning/semantics.lua")
    local rewardLegality = import("mods/route/reward_planning/legality.lua", nil, {
        conditions = import("mods/rewards/declarations/conditions.lua"),
        timeline = routeTimeline,
        rewardItems = rewardItems,
        semantics = rewardSemantics,
        invalidLocations = invalidLocations,
    })

    return {
        rewardItems = rewardItems,
        rewardSemantics = rewardSemantics,
        rewardLegality = rewardLegality,
        rewardOfferRules = import("mods/route/reward_planning/offer_rules.lua", nil, {
            semantics = rewardSemantics,
        }),
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
    local planning = createRewardPlanning(routeTimeline, invalidLocations)
    local rows = import("mods/route/rows.lua", nil, {
        rewards = rewards,
        timeline = routeTimeline,
    })

    local route = {
        common = rows.common,
        availability = rows.availability,
        readCache = rows.readCache,
        requirements = rows.requirements,
        biomeRules = rows.biomeRules,
        rowEngine = rows.engine,
        timeline = routeTimeline,
        invalidLocations = invalidLocations,
        rewards = rewards,
        rewardItems = planning.rewardItems,
        rewardSemantics = planning.rewardSemantics,
        rewardOfferGroups = import("mods/rewards/declarations/offer_groups.lua"),
        rewardOfferRules = planning.rewardOfferRules,
        rewardLegality = planning.rewardLegality,
    }
    route.runContext = import("mods/route/run_context.lua", nil, {
        controls = import("mods/route/run_context/controls.lua"),
        targets = createRouteTargets(routeTimeline, planning),
        rewards = import("mods/route/run_context/rewards.lua", nil, {
            rewardLegality = planning.rewardLegality,
            rewardItems = planning.rewardItems,
            semantics = planning.rewardSemantics,
        }),
    })
    return route
end

return routeFactory
