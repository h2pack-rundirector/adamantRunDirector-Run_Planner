local assembly = {}

function assembly.create(opts)
    opts = opts or {}

    local catalog = opts.catalog
    local route = opts.route
    local runState = import("mods/logic/run_state.lua")
    local routePlan = import("mods/logic/route_plan.lua", nil, {
        executionPlan = import("mods/logic/execution_plan.lua", nil, {
            timeline = route.timeline,
            biomeLookup = catalog.lookup,
        }),
        routeContext = route.runContext,
        runState = runState,
    })
    local roomRouting = import("mods/logic/room_routing.lua", nil, {
        routePlan = routePlan,
        runState = runState,
    })
    local rewardRouting = import("mods/logic/reward_routing.lua", nil, {
        routePlan = routePlan,
        runState = runState,
    })
    local npcRouting = import("mods/logic/npc_routing.lua", nil, {
        routePlan = routePlan,
        runState = runState,
    })
    local featureRouting = import("mods/logic/feature_routing.lua", nil, {
        routePlan = routePlan,
        runState = runState,
    })

    return import("mods/logic.lua", nil, {
        catalog = catalog,
        routePlan = routePlan,
        roomRouting = roomRouting,
        rewardRouting = rewardRouting,
        npcRouting = npcRouting,
        featureRouting = featureRouting,
        liveGameValidator = import("mods/biomes/live_validator.lua"),
        rewards = opts.rewards,
    })
end

return assembly
