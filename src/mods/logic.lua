local logic = {}

function logic.bind(data)
    local catalog = data.loadCatalog()
    local routePlan = import("mods/logic/route_plan.lua", nil, {
        executionPlan = import("mods/logic/execution_plan.lua"),
        routeContext = import("mods/route/run_context.lua"),
    })
    local bound = {}

    function bound.defineCache(moduleRef)
        routePlan.defineCache(moduleRef)
    end

    function bound.registerHooks(moduleRef)
        routePlan.registerHooks(moduleRef, catalog)
    end

    function bound.attach(moduleRef)
        bound.defineCache(moduleRef)
        bound.registerHooks(moduleRef)
    end

    return bound
end

return logic
