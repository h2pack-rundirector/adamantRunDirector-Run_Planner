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
    if rewards == nil then
        error("route.create requires rewards")
    end

    local routeCommon = import("mods/route/rows/common.lua")
    local routeTimeline = import("mods/route/timeline.lua")
    local invalidLocations = import("mods/route/invalid_locations.lua")
    local planning = createRewardPlanning(routeTimeline, invalidLocations)
    local routeRequirements = import("mods/route/rows/requirements.lua", nil, {
        common = routeCommon,
        rewards = rewards,
    })
    local routeBiomeRules = import("mods/route/rows/biome_rules.lua", nil, {
        common = routeCommon,
    })

    local route = {
        common = routeCommon,
        availability = import("mods/route/rows/availability.lua"),
        readCache = import("mods/route/rows/read_cache.lua"),
        requirements = routeRequirements,
        biomeRules = routeBiomeRules,
        timeline = routeTimeline,
        invalidLocations = invalidLocations,
        rewards = rewards,
        rewardItems = planning.rewardItems,
        rewardSemantics = planning.rewardSemantics,
        rewardOfferGroups = import("mods/rewards/declarations/offer_groups.lua"),
        rewardOfferRules = planning.rewardOfferRules,
        rewardLegality = planning.rewardLegality,
    }
    route.rowEngine = import("mods/route/rows/engine.lua", nil, route)
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
