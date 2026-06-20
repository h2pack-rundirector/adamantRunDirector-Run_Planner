local logic = {}

function logic.bind(data)
    local catalog = data.loadCatalog()
    local routeTimeline = import("mods/route/timeline.lua")
    local rewardLegality = import("mods/route/reward_legality.lua", nil, {
        routeRules = import("mods/rewards/route_rules.lua"),
        timeline = routeTimeline,
    })
    local routePlan = import("mods/logic/route_plan.lua", nil, {
        executionPlan = import("mods/logic/execution_plan.lua"),
        routeContext = import("mods/route/run_context.lua", nil, {
            rewardLegality = rewardLegality,
            timeline = routeTimeline,
        }),
    })
    local roomRouting = import("mods/logic/room_routing.lua", nil, {
        routePlan = routePlan,
    })
    local bound = {}

    function bound.defineCache(moduleRef)
        routePlan.defineCache(moduleRef)
    end

    function bound.registerHooks(moduleRef)
        routePlan.registerHooks(moduleRef, catalog)
        roomRouting.registerHooks(moduleRef, catalog)
    end

    function bound.attach(moduleRef)
        bound.defineCache(moduleRef)
        bound.registerHooks(moduleRef)
    end

    return bound
end

return logic
