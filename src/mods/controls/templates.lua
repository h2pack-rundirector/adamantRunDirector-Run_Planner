local routeCommon = import("mods/route/common.lua")
local routeRequirements = import("mods/route/requirements.lua", nil, {
    common = routeCommon,
})
local routeBiomeRules = import("mods/route/biome_rules.lua", nil, {
    common = routeCommon,
})
local rewardSemantics = import("mods/rewards/semantics.lua")
local route = {
    common = routeCommon,
    availability = import("mods/route/availability.lua"),
    readCache = import("mods/route/read_cache.lua"),
    requirements = routeRequirements,
    biomeRules = routeBiomeRules,
    timeline = import("mods/route/timeline.lua"),
    invalidLocations = import("mods/route/invalid_locations.lua"),
    rewardItems = import("mods/route/reward_items.lua"),
    rewardSemantics = rewardSemantics,
    rewardOfferPolicies = import("mods/data/reward_offer_policies.lua"),
    rewardOfferRules = import("mods/route/reward_offer_rules.lua", nil, {
        semantics = rewardSemantics,
    }),
}
route.rowEngine = import("mods/route/row_engine.lua", nil, route)

local rewardCatalogFactory = import("mods/rewards/catalog.lua")
local rewardCatalog = rewardCatalogFactory.create(import("mods/rewards/definitions.lua"))
local rewardRuntime = import("mods/rewards/runtime.lua", nil, {
    catalog = rewardCatalog,
})
local routeStatusUi = import("mods/controls/route_status_ui.lua")
local godData = import("mods/data/gods.lua")
local rewards = {
    runtime = rewardRuntime,
    ui = import("mods/rewards/ui.lua", nil, {
        runtime = rewardRuntime,
        routeStatusUi = routeStatusUi,
    }),
}

return {
    ClockworkGoalRoute = import("mods/controls/ClockworkGoalRoute/ClockworkGoalRoute.lua", nil, {
        route = route,
        rewards = rewards,
        routeStatusUi = routeStatusUi,
    }),
    FieldsCageRoute = import("mods/controls/FieldsCageRoute/FieldsCageRoute.lua", nil, {
        route = route,
        rewards = rewards,
        routeStatusUi = routeStatusUi,
    }),
    FixedLinearRoute = import("mods/controls/FixedLinearRoute/FixedLinearRoute.lua", nil, {
        route = route,
        rewards = rewards,
        routeStatusUi = routeStatusUi,
    }),
    HubPylonRoute = import("mods/controls/HubPylonRoute/HubPylonRoute.lua", nil, {
        route = route,
        rewards = rewards,
        routeStatusUi = routeStatusUi,
    }),
    MultiEncounterFixedRoute = import("mods/controls/MultiEncounterFixedRoute/MultiEncounterFixedRoute.lua", nil, {
        route = route,
        rewards = rewards,
        routeStatusUi = routeStatusUi,
    }),
    RouteNpcs = import("mods/controls/RouteNpcs/RouteNpcs.lua", nil, {
        route = route,
        routeStatusUi = routeStatusUi,
    }),
    RouteFeatures = import("mods/controls/RouteFeatures/RouteFeatures.lua", nil, {
        route = route,
        routeStatusUi = routeStatusUi,
    }),
    RouteGlobal = import("mods/controls/RouteGlobal/RouteGlobal.lua", nil, {
        gods = godData,
    }),
}
