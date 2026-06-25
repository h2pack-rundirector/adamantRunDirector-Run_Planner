local systems = {}

local function createRouteRules(godData)
    return import("mods/biomes/declaration_rules.lua")({
        godData = godData,
    })
end

local function createCatalogDeps(godData, routeRules, rewards)
    return {
        godData = godData,
        routeRules = routeRules,
        rewards = rewards,
    }
end

local function createRewards(godData, routeRules, decorations)
    return import("mods/rewards/rewards.lua").create({
        godData = godData,
        routeRules = routeRules,
        decorations = decorations,
    })
end

local function createControlTemplates(route, decorations, godData)
    return import("mods/controls/templates.lua", nil, {
        route = route,
        rewards = route.rewards,
        godData = godData,
        decorations = decorations,
    })
end

local function createLogic(catalog, route, rewards)
    return import("mods/logic/assembly.lua").create({
        catalog = catalog,
        route = route,
        rewards = rewards,
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
    local controlCatalog = opts.controlCatalog or import("mods/controls/catalog.lua")
    local godData = import("mods/data/gods.lua")
    local routeRules = createRouteRules(godData)
    local decorations = opts.decorations or import("mods/ui/decorations.lua")
    local rewards = opts.rewards or createRewards(godData, routeRules, decorations)
    local catalogDeps = createCatalogDeps(godData, routeRules, rewards)
    local catalog = opts.catalog or data.loadCatalog(catalogDeps)
    local route = opts.route or import("mods/route/route.lua").create({
        rewards = rewards,
    })
    local routeControlTabs = opts.routeControlTabs or controlCatalog.routeControlTabs(catalog)

    return {
        data = data,
        catalog = catalog,
        rewards = rewards,
        route = route,
        routeContext = route.runContext,
        routeControls = opts.routeControls or controlCatalog.build(catalog),
        routeControlTabs = routeControlTabs,
        controlTemplates = opts.controlTemplates or createControlTemplates(route, decorations, godData),
        logic = opts.logic or createLogic(catalog, route, rewards),
        ui = opts.ui or createUi(catalog, route, routeControlTabs, decorations),
    }
end

return systems
