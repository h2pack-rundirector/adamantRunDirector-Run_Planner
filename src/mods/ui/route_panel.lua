local routePanel = {}

local EMPTY_LIST = {}

local function clearList(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

local function fallbackRouteDefinitions(routeControlTabs)
    local ordered = {}
    for key in pairs(routeControlTabs or {}) do
        ordered[#ordered + 1] = {
            key = key,
            label = key,
            biomes = {},
        }
    end
    return {
        ordered = ordered,
    }
end

function routePanel.create(deps)
    deps = deps or {}

    local panel = {}
    local routeNavOpts = {}
    local routeControlByTab = {}
    local routeDefinitions = deps.routes
        or (deps.catalog and deps.catalog.routes)
        or fallbackRouteDefinitions(deps.routeControlTabs)
    local biomeDefinitions = deps.biomes or (deps.catalog and deps.catalog.lookup) or {}
    local npcDefinitions = deps.npcs or (deps.catalog and deps.catalog.npcs) or {}
    local featureDefinitions = deps.features or (deps.catalog and deps.catalog.features) or {}
    local routeContextFactory = deps.routeContext
    local routeStatus = deps.routeStatus
    local activeRouteContext
    local activeRouteTabs = {}
    local routeAllTabs = {}
    local routeVisibleTabs = {}

    local function buildRegionTabs(routeControlTabs)
        routeNavOpts = {}
        routeControlByTab = {}
        routeAllTabs = {}
        routeVisibleTabs = {}

        for region, entries in pairs(routeControlTabs or {}) do
            local tabs = {}
            local visibleTabs = {}
            local controls = {}
            for _, entry in ipairs(entries) do
                tabs[#tabs + 1] = {
                    key = entry.key,
                    label = entry.label,
                    layer = entry.layer,
                }
                controls[entry.key] = entry.controlNames or { entry.controlName }
            end
            routeAllTabs[region] = tabs
            routeVisibleTabs[region] = visibleTabs
            routeNavOpts[region] = {
                id = "RunPlanner" .. tostring(region) .. "Tabs",
                navWidth = 180,
                tabs = visibleTabs,
            }
            routeControlByTab[region] = controls
            if activeRouteTabs[region] == nil and tabs[1] ~= nil then
                activeRouteTabs[region] = tabs[1].key
            end
        end
    end

    local function beginRouteContext(ctx)
        if routeContextFactory == nil then
            return nil
        end

        if activeRouteContext == nil then
            activeRouteContext = routeContextFactory.create({
                routes = routeDefinitions,
                biomes = biomeDefinitions,
                npcs = npcDefinitions,
                features = featureDefinitions,
            })
        end
        activeRouteContext:beginPass(ctx.controls)
        return activeRouteContext
    end

    local function tabLayerConfigured(routeContext, region, tab)
        if tab.layer == nil then
            return true
        end
        if routeContext == nil or routeContext.isLayerConfigured == nil then
            return true
        end
        return routeContext:isLayerConfigured(region, tab.layer) ~= false
    end

    local function refreshRegionTabs(routeContext, region)
        local visibleTabs = routeVisibleTabs[region]
        if visibleTabs == nil then
            return nil
        end

        clearList(visibleTabs)
        for _, tab in ipairs(routeAllTabs[region] or EMPTY_LIST) do
            if tabLayerConfigured(routeContext, region, tab) then
                visibleTabs[#visibleTabs + 1] = tab
            end
        end
        return visibleTabs
    end

    local function activeTabIsVisible(region)
        local activeTab = activeRouteTabs[region]
        for _, tab in ipairs(routeVisibleTabs[region] or EMPTY_LIST) do
            if tab.key == activeTab then
                return true
            end
        end
        return false
    end

    local function drawRegionTab(ctx, region, childId, routeContext)
        local draw = ctx.draw
        local imgui = draw.imgui
        local navOpts = routeNavOpts[region]
        local visibleTabs = refreshRegionTabs(routeContext, region)
        if navOpts == nil or visibleTabs == nil or visibleTabs[1] == nil then
            return
        end

        if routeControlByTab[region][activeRouteTabs[region]] == nil or not activeTabIsVisible(region) then
            activeRouteTabs[region] = visibleTabs[1].key
        end

        navOpts.activeKey = activeRouteTabs[region]
        local activeTab = draw.nav.verticalTabs(navOpts)
        activeRouteTabs[region] = activeTab

        imgui.BeginChild(childId .. "Detail", 0, 0, false)
        local controlNames = routeControlByTab[region][activeTab]
        for index, controlName in ipairs(controlNames or EMPTY_LIST) do
            if index > 1 then
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
            end
            local control = ctx.controls.get(controlName)
            if routeContext ~= nil then
                routeContext:bindControl(control, region)
            end
            draw.control(control, "planner")
        end
        imgui.EndChild()
    end

    local function drawRouteTabs(ctx, routeContext)
        local imgui = ctx.draw.imgui
        if not imgui.BeginTabBar("RunPlannerRouteTabs") then
            return
        end

        for _, route in ipairs(routeDefinitions.ordered or EMPTY_LIST) do
            if routeNavOpts[route.key] ~= nil and imgui.BeginTabItem(route.label or route.key) then
                drawRegionTab(ctx, route.key, "RunPlanner" .. tostring(route.key), routeContext)
                imgui.EndTabItem()
            end
        end

        imgui.EndTabBar()
    end

    local function drawRouteOverview(draw, routeContext)
        if routeStatus == nil or routeContext == nil then
            return
        end

        local drewStatus = false
        for _, route in ipairs(routeDefinitions.ordered or EMPTY_LIST) do
            routeStatus.drawRouteStatus(draw, routeContext:overview(route.key))
            drewStatus = true
        end
        if drewStatus then
            draw.imgui.Spacing()
        end
    end

    function panel.drawTab(ctx)
        local routeContext = beginRouteContext(ctx)
        drawRouteOverview(ctx.draw, routeContext)
        drawRouteTabs(ctx, routeContext)
    end

    buildRegionTabs(deps.routeControlTabs)
    return panel
end

return routePanel
