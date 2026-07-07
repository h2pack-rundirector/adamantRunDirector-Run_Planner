local routeSelection = import("mods/ui/planner/route_selection.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local routeNav = {}
local defaultInstance

local EMPTY_LIST = {}

local function routeNavCache(state)
    local cache = state.routeNavCache
    if cache == nil or cache.catalog ~= state.catalog then
        cache = {
            catalog = state.catalog,
            biomeTabsByRoute = {},
        }
        state.routeNavCache = cache
    end
    return cache
end

local function biomeLabel(catalog, biomeKey)
    local biome = catalog and catalog.biomes and catalog.biomes.lookup and catalog.biomes.lookup[biomeKey] or nil
    if biome ~= nil and biome.label ~= nil then
        return tostring(biome.label) .. " (" .. tostring(biomeKey) .. ")"
    end
    return tostring(biomeKey)
end

local function routeLabel(route)
    return tostring((route and route.label) or (route and route.key) or "Route")
end

local function tabListForRoute(catalog, route)
    local tabs = {}
    for _, biomeKey in ipairs(route and route.biomeKeys or EMPTY_LIST) do
        tabs[#tabs + 1] = {
            key = biomeKey,
            label = biomeLabel(catalog, biomeKey),
        }
    end
    return tabs
end

local function cachedTabListForRoute(state, route)
    if route == nil then
        return EMPTY_LIST
    end
    local cache = routeNavCache(state)
    local tabs = cache.biomeTabsByRoute[route.key]
    if tabs == nil then
        tabs = tabListForRoute(state.catalog, route)
        cache.biomeTabsByRoute[route.key] = tabs
    end
    return tabs
end

local function drawFallbackBiomeNav(service, imgui, catalog, route, activeBiome)
    service.widgets.text(imgui, "Biomes")
    for _, biomeKey in ipairs(route and route.biomeKeys or EMPTY_LIST) do
        local marker = biomeKey == activeBiome and "* " or "  "
        service.widgets.text(imgui, marker .. biomeLabel(catalog, biomeKey))
    end
end

local function drawBiomeNav(service, state, ctx, route, activeBiome)
    local draw = ctx and ctx.draw or nil
    local nav = draw and draw.nav or nil
    if nav ~= nil and type(nav.verticalTabs) == "function" then
        local selected = nav.verticalTabs({
            id = "RunPlanner" .. tostring(route.key) .. "BiomeTabs",
            navWidth = 180,
            activeKey = activeBiome,
            tabs = cachedTabListForRoute(state, route),
        })
        if selected ~= nil and selected ~= activeBiome then
            service.routeSelection.setActiveBiome(ctx, route.key, selected)
            return selected
        end
        return activeBiome
    end

    local imgui = draw and draw.imgui or nil
    drawFallbackBiomeNav(service, imgui, state.catalog, route, activeBiome)
    return activeBiome
end

local function drawRouteContent(service, state, ctx, route, evaluation, biomePanels)
    local imgui = ctx and ctx.draw and ctx.draw.imgui or nil
    local biomeKey = service.routeSelection.activeBiomeKey(ctx, route)
    service.widgets.text(imgui, "Route: " .. routeLabel(route))
    biomeKey = drawBiomeNav(service, state, ctx, route, biomeKey)
    service.widgets.separator(imgui)
    biomePanels.draw(state, ctx, route, biomeKey, evaluation)
end

local function drawFallbackRoutes(service, state, ctx, evaluation, biomePanels)
    drawRouteContent(service, state, ctx, service.routeSelection.activeRoute(state, ctx), evaluation, biomePanels)
end

local function drawRouteTabs(service, state, ctx, evaluation, biomePanels)
    local imgui = ctx and ctx.draw and ctx.draw.imgui or nil
    if imgui == nil or imgui.BeginTabBar == nil or imgui.BeginTabItem == nil or imgui.EndTabItem == nil or imgui.EndTabBar == nil then
        drawFallbackRoutes(service, state, ctx, evaluation, biomePanels)
        return
    end

    if not imgui.BeginTabBar("RunPlannerRouteTabs") then
        drawFallbackRoutes(service, state, ctx, evaluation, biomePanels)
        return
    end

    for _, route in ipairs(service.routeSelection.routeDefinitions(state.catalog)) do
        if imgui.BeginTabItem(routeLabel(route)) then
            service.routeSelection.setActiveRoute(ctx, route.key)
            drawRouteContent(service, state, ctx, route, evaluation, biomePanels)
            imgui.EndTabItem()
        end
    end
    imgui.EndTabBar()
end

function routeNav.create(deps)
    deps = deps or {}
    local service = {
        routeSelection = deps.routeSelection or routeSelection,
        widgets = deps.widgets or widgets,
    }

    function service.draw(state, ctx, evaluation, biomePanels)
        return drawRouteTabs(service, state, ctx, evaluation, biomePanels)
    end

    return service
end

function routeNav.draw(state, ctx, evaluation, biomePanels)
    if defaultInstance == nil then
        defaultInstance = routeNav.create()
    end
    return defaultInstance.draw(state, ctx, evaluation, biomePanels)
end

return routeNav
