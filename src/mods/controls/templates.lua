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
    FixedLinearRoute = import("mods/controls/FixedLinearRoute/FixedLinearRoute.lua", nil, {
        route = route,
        rewards = rewards,
    }),
}
