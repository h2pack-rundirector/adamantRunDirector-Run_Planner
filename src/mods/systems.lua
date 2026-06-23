local systems = {}

local function createRewards(decorations)
    return import("mods/rewards/rewards.lua").create({
        definitions = import("mods/rewards/declarations/definitions.lua"),
        decorations = decorations,
    })
end

local function createControlTemplates(route, decorations)
    return import("mods/controls/templates.lua", nil, {
        route = route,
        rewards = route.rewards,
        godData = import("mods/data/gods.lua"),
        decorations = decorations,
    })
end

local function createLogic(catalog, route)
    local runState = import("mods/logic/run_state.lua")
    local routePlan = import("mods/logic/route_plan.lua", nil, {
        executionPlan = import("mods/logic/execution_plan.lua"),
        routeContext = route.runContext,
        runState = runState,
    })
    local roomRouting = import("mods/logic/room_routing.lua", nil, {
        routePlan = routePlan,
        runState = runState,
    })
    return import("mods/logic.lua", nil, {
        catalog = catalog,
        routePlan = routePlan,
        roomRouting = roomRouting,
    })
end

local function createUi(catalog, route, routeControlTabs, decorations)
    return import("mods/ui.lua", nil, {
        catalog = catalog,
        routeContext = route.runContext,
        routeControlTabs = routeControlTabs,
        decorations = decorations,
    })
end

function systems.create(opts)
    opts = opts or {}
    local data = opts.data or import("mods/data.lua")
    local catalog = opts.catalog or data.loadCatalog()
    local decorations = opts.decorations or import("mods/ui/decorations.lua")
    local rewards = opts.rewards or createRewards(decorations)
    local route = opts.route or import("mods/route/route.lua").create({
        rewards = rewards,
    })
    local routeControlTabs = opts.routeControlTabs or data.routeControlTabs(catalog)

    return {
        data = data,
        catalog = catalog,
        rewards = rewards,
        route = route,
        routeContext = route.runContext,
        routeControls = opts.routeControls or data.buildControls(catalog),
        routeControlTabs = routeControlTabs,
        controlTemplates = opts.controlTemplates or createControlTemplates(route, decorations),
        logic = opts.logic or createLogic(catalog, route),
        ui = opts.ui or createUi(catalog, route, routeControlTabs, decorations),
    }
end

return systems
