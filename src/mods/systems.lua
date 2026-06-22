local systems = {}

local function createRewards()
    return import("mods/rewards/rewards.lua").create({
        definitions = import("mods/rewards/declarations/definitions.lua"),
        dropdownValues = import("mods/ui/dropdown_values.lua"),
    })
end

local function createTabStatus()
    return import("mods/ui/tab_status.lua")
end

local function createControlTemplates(route)
    local tabStatus = createTabStatus()
    return import("mods/controls/templates.lua", nil, {
        route = route,
        rewards = route.rewards,
        godData = import("mods/data/gods.lua"),
        dropdownValues = import("mods/ui/dropdown_values.lua"),
        tabStatus = tabStatus,
    })
end

local function createLogic(catalog, route)
    local routePlan = import("mods/logic/route_plan.lua", nil, {
        executionPlan = import("mods/logic/execution_plan.lua"),
        routeContext = route.runContext,
    })
    local roomRouting = import("mods/logic/room_routing.lua", nil, {
        routePlan = routePlan,
    })
    return import("mods/logic.lua", nil, {
        catalog = catalog,
        routePlan = routePlan,
        roomRouting = roomRouting,
    })
end

local function createUi(catalog, route, routeControlTabs)
    return import("mods/ui.lua", nil, {
        catalog = catalog,
        routeContext = route.runContext,
        routeControlTabs = routeControlTabs,
        tabStatus = createTabStatus(),
    })
end

function systems.create(opts)
    opts = opts or {}
    local data = opts.data or import("mods/data.lua")
    local catalog = opts.catalog or data.loadCatalog()
    local rewards = opts.rewards or createRewards()
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
        controlTemplates = opts.controlTemplates or createControlTemplates(route),
        logic = opts.logic or createLogic(catalog, route),
        ui = opts.ui or createUi(catalog, route, routeControlTabs),
    }
end

return systems
