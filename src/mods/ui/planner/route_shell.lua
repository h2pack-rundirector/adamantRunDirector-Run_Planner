local fErebusPanel = import("mods/ui/biomes/f_erebus_panel.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local routeShell = {}

local EMPTY_LIST = {}
local ROUTE_BIOME_SELECTION = {
    Underworld = "SelectedUnderworldBiome",
    Surface = "SelectedSurfaceBiome",
}

local function routeShellCache(state)
    local cache = state.routeShellCache
    if cache == nil or cache.catalog ~= state.catalog then
        cache = {
            catalog = state.catalog,
            biomeTabsByRoute = {},
        }
        state.routeShellCache = cache
    end
    return cache
end

local function routeDefinitions(catalog)
    return catalog and catalog.routes and catalog.routes.ordered or EMPTY_LIST
end

local function routeLookup(catalog, routeKey)
    return catalog and catalog.routes and catalog.routes.lookup and catalog.routes.lookup[routeKey] or nil
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

local function fieldFor(data, alias)
    if data == nil or type(data.get) ~= "function" then
        return nil
    end
    local ok, field = pcall(data.get, alias)
    if ok then
        return field
    end
    return nil
end

local function readData(ctx, alias)
    local data = ctx and ctx.data or nil
    if data == nil then
        return nil
    end
    if type(data.read) == "function" then
        local ok, value = pcall(data.read, alias)
        if ok then
            return value
        end
    end
    local field = fieldFor(data, alias)
    if field ~= nil and type(field.read) == "function" then
        local ok, value = pcall(field.read, field)
        if ok then
            return value
        end
    end
    return nil
end

local function writeData(ctx, alias, value)
    local data = ctx and ctx.data or nil
    if data == nil then
        return false
    end
    if type(data.write) == "function" then
        local ok, changed = pcall(data.write, alias, value)
        if ok then
            return changed ~= false
        end
    end
    local field = fieldFor(data, alias)
    if field ~= nil and type(field.write) == "function" then
        local ok, changed = pcall(field.write, field, value)
        if ok then
            return changed ~= false
        end
    end
    return false
end

local function contains(list, value)
    for _, candidate in ipairs(list or EMPTY_LIST) do
        if candidate == value then
            return true
        end
    end
    return false
end

local function defaultRoute(catalog)
    local route = routeDefinitions(catalog)[1]
    return route and route.key or "Underworld"
end

local function activeRouteKey(state, ctx)
    local stored = readData(ctx, "SelectedRoute")
    if routeLookup(state.catalog, stored) ~= nil then
        return stored
    end
    return defaultRoute(state.catalog)
end

local function activeBiomeKey(ctx, route)
    local alias = ROUTE_BIOME_SELECTION[route and route.key]
    local stored = alias and readData(ctx, alias) or nil
    if contains(route and route.biomeKeys, stored) then
        return stored
    end
    return route and route.biomeKeys and route.biomeKeys[1] or nil
end

local function setActiveRoute(ctx, routeKey)
    writeData(ctx, "SelectedRoute", routeKey)
end

local function setActiveBiome(ctx, routeKey, biomeKey)
    local alias = ROUTE_BIOME_SELECTION[routeKey]
    if alias ~= nil then
        writeData(ctx, alias, biomeKey)
    end
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
    local cache = routeShellCache(state)
    local tabs = cache.biomeTabsByRoute[route.key]
    if tabs == nil then
        tabs = tabListForRoute(state.catalog, route)
        cache.biomeTabsByRoute[route.key] = tabs
    end
    return tabs
end

local function drawPlaceholder(imgui, route, biomeKey)
    widgets.section(imgui, biomeLabel(nil, biomeKey))
    widgets.text(imgui, "Placeholder biome panel")
    widgets.text(imgui, "Route: " .. routeLabel(route))
    widgets.text(imgui, "Biome: " .. tostring(biomeKey))
    widgets.text(imgui, "This biome does not emit a planner snapshot yet.")
end

local function drawBiomePanel(state, ctx, route, biomeKey, evaluation)
    local imgui = ctx and ctx.draw and ctx.draw.imgui or nil
    if route ~= nil and route.key == "Underworld" and biomeKey == "F" then
        fErebusPanel.draw(state, ctx, {
            title = biomeLabel(state.catalog, "F"),
            hideStatus = true,
            evaluation = evaluation,
        })
        return
    end
    drawPlaceholder(imgui, route, biomeKey)
end

local function drawFallbackBiomeNav(imgui, catalog, route, activeBiome)
    widgets.text(imgui, "Biomes")
    for _, biomeKey in ipairs(route and route.biomeKeys or EMPTY_LIST) do
        local marker = biomeKey == activeBiome and "* " or "  "
        widgets.text(imgui, marker .. biomeLabel(catalog, biomeKey))
    end
end

local function drawBiomeNav(state, ctx, route, activeBiome)
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
            setActiveBiome(ctx, route.key, selected)
            return selected
        end
        return activeBiome
    end

    local imgui = draw and draw.imgui or nil
    drawFallbackBiomeNav(imgui, state.catalog, route, activeBiome)
    return activeBiome
end

local function drawRouteContent(state, ctx, route, evaluation)
    local imgui = ctx and ctx.draw and ctx.draw.imgui or nil
    local biomeKey = activeBiomeKey(ctx, route)
    widgets.text(imgui, "Route: " .. routeLabel(route))
    biomeKey = drawBiomeNav(state, ctx, route, biomeKey)
    widgets.separator(imgui)
    drawBiomePanel(state, ctx, route, biomeKey, evaluation)
end

local function drawFallbackRoutes(state, ctx, evaluation)
    local routeKey = activeRouteKey(state, ctx)
    local route = routeLookup(state.catalog, routeKey) or routeDefinitions(state.catalog)[1]
    drawRouteContent(state, ctx, route, evaluation)
end

local function drawRouteTabs(state, ctx, evaluation)
    local imgui = ctx and ctx.draw and ctx.draw.imgui or nil
    if imgui == nil or imgui.BeginTabBar == nil or imgui.BeginTabItem == nil or imgui.EndTabItem == nil or imgui.EndTabBar == nil then
        drawFallbackRoutes(state, ctx, evaluation)
        return
    end

    if not imgui.BeginTabBar("RunPlannerRouteTabs") then
        drawFallbackRoutes(state, ctx, evaluation)
        return
    end

    for _, route in ipairs(routeDefinitions(state.catalog)) do
        if imgui.BeginTabItem(routeLabel(route)) then
            setActiveRoute(ctx, route.key)
            drawRouteContent(state, ctx, route, evaluation)
            imgui.EndTabItem()
        end
    end
    imgui.EndTabBar()
end

function routeShell.draw(state, ctx)
    local imgui = ctx and ctx.draw and ctx.draw.imgui or nil
    state.bindUiContext(ctx)
    local evaluation = state.ensureEvaluation()
    widgets.text(imgui, "Run Planner")
    widgets.status(imgui, evaluation, state.feedbackLocationLabel)
    widgets.separator(imgui)
    drawRouteTabs(state, ctx, evaluation)
    if state.dirty then
        state.ensureEvaluation()
    end
end

return routeShell
