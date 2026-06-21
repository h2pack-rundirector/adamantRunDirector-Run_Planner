local deps = ...
local logic = {}

local data = deps and deps.data or nil
local catalog = deps and deps.catalog or data.loadCatalog()
local routeTimeline = import("mods/route/timeline.lua")
local invalidLocations = import("mods/route/invalid_locations.lua")
local rewardItems = import("mods/rewards/items.lua")
local rewardSemantics = import("mods/rewards/semantics.lua")
local rewardLegality = import("mods/rewards/legality.lua", nil, {
    conditions = import("mods/rewards/conditions.lua"),
    timeline = routeTimeline,
    rewardItems = rewardItems,
    semantics = rewardSemantics,
    invalidLocations = invalidLocations,
})
local routePlan = import("mods/logic/route_plan.lua", nil, {
    executionPlan = import("mods/logic/execution_plan.lua"),
    routeContext = import("mods/route/run_context.lua", nil, {
        rewardLegality = rewardLegality,
        timeline = routeTimeline,
        rewardItems = rewardItems,
        semantics = rewardSemantics,
    }),
})
local roomRouting = import("mods/logic/room_routing.lua", nil, {
    routePlan = routePlan,
})

function logic.defineCache(moduleRef)
    routePlan.defineCache(moduleRef)
end

function logic.registerHooks(moduleRef)
    routePlan.registerHooks(moduleRef, catalog)
    roomRouting.registerHooks(moduleRef, catalog)
end

function logic.attach(moduleRef)
    logic.defineCache(moduleRef)
    logic.registerHooks(moduleRef)
end

return logic
