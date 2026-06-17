local routeCommon = import("mods/route/common.lua")
local routeRequirements = import("mods/route/requirements.lua", nil, {
    common = routeCommon,
})
local route = {
    common = routeCommon,
    availability = import("mods/route/availability.lua"),
    readCache = import("mods/route/read_cache.lua"),
    requirements = routeRequirements,
}
route.rowEngine = import("mods/route/row_engine.lua", nil, route)

local rewardCatalogFactory = import("mods/rewards/catalog.lua")
local rewardCatalog = rewardCatalogFactory.create(import("mods/rewards/surfaces.lua"))
local rewardRuntime = import("mods/rewards/runtime.lua", nil, {
    catalog = rewardCatalog,
})
local rewards = {
    runtime = rewardRuntime,
    ui = import("mods/rewards/ui.lua", nil, {
        runtime = rewardRuntime,
    }),
}

return {
    FieldsCageRoute = import("mods/controls/FieldsCageRoute/FieldsCageRoute.lua", nil, {
        route = route,
        rewards = rewards,
    }),
    FixedLinearRoute = import("mods/controls/FixedLinearRoute/FixedLinearRoute.lua", nil, {
        route = route,
        rewards = rewards,
    }),
    HubPylonRoute = import("mods/controls/HubPylonRoute/HubPylonRoute.lua", nil, {
        route = route,
        rewards = rewards,
    }),
    MultiEncounterFixedRoute = import("mods/controls/MultiEncounterFixedRoute/MultiEncounterFixedRoute.lua", nil, {
        route = route,
        rewards = rewards,
    }),
}
