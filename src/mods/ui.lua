local ui = {}

local EMPTY_LIST = {}

local routeNavOpts = {}
local routeControlByTab = {}
local routeDefinitions = {}
local biomeDefinitions = {}
local npcDefinitions = {}
local featureDefinitions = {}
local routeContextFactory
local routeStatusUi
local activeRouteContext
local activeRouteTabs = {}

local roomRoutingOpts = {
    label = "Room Routing",
}
local rewardRoutingOpts = {
    label = "Reward Routing",
}
local planModeOpts

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

local function buildRegionTabs(routeControlTabs)
    routeNavOpts = {}
    routeControlByTab = {}

    for region, entries in pairs(routeControlTabs or {}) do
        local tabs = {}
        local controls = {}
        for _, entry in ipairs(entries) do
            tabs[#tabs + 1] = {
                key = entry.key,
                label = entry.label,
            }
            controls[entry.key] = entry.controlNames or { entry.controlName }
        end
        routeNavOpts[region] = {
            id = "RunPlanner" .. tostring(region) .. "Tabs",
            navWidth = 180,
            tabs = tabs,
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

local function drawRegionTab(ctx, region, childId, routeContext)
    local draw = ctx.draw
    local imgui = draw.imgui
    local navOpts = routeNavOpts[region]
    if navOpts == nil or navOpts.tabs[1] == nil then
        return
    end

    if routeControlByTab[region][activeRouteTabs[region]] == nil then
        activeRouteTabs[region] = navOpts.tabs[1].key
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
    if routeStatusUi == nil or routeContext == nil then
        return
    end

    local drewStatus = false
    for _, route in ipairs(routeDefinitions.ordered or EMPTY_LIST) do
        if drewStatus then
            draw.imgui.SameLine()
        end
        routeStatusUi.drawRouteStatus(draw, routeContext:overview(route.key))
        drewStatus = true
    end
    if drewStatus then
        draw.imgui.Spacing()
    end
end

function ui.bind(deps)
    deps = deps or {}
    local data = deps.data or deps
    routeDefinitions = deps.routes
        or (deps.catalog and deps.catalog.routes)
        or fallbackRouteDefinitions(deps.routeControlTabs)
    biomeDefinitions = deps.biomes or (deps.catalog and deps.catalog.lookup) or {}
    npcDefinitions = deps.npcs or (deps.catalog and deps.catalog.npcs) or {}
    featureDefinitions = deps.features or (deps.catalog and deps.catalog.features) or {}
    routeContextFactory = deps.routeContext
    routeStatusUi = deps.routeStatusUi
    buildRegionTabs(deps.routeControlTabs)
    planModeOpts = {
        label = "Plan Mode",
        values = data.PLAN_MODE_VALUES,
        controlWidth = 180,
    }
    return ui
end

function ui.drawQuickContent(_, ctx)
    local draw = ctx.draw
    local state = ctx.data

    draw.widgets.checkbox(state.get("RoomRoutingEnabled"), roomRoutingOpts)
    draw.widgets.checkbox(state.get("RewardRoutingEnabled"), rewardRoutingOpts)
end

function ui.drawTab(_, ctx)
    local draw = ctx.draw
    local state = ctx.data

    draw.widgets.checkbox(state.get("RoomRoutingEnabled"), roomRoutingOpts)
    draw.widgets.checkbox(state.get("RewardRoutingEnabled"), rewardRoutingOpts)
    draw.widgets.dropdown(state.get("PlanMode"), planModeOpts)
    draw.widgets.separator()
    local routeContext = beginRouteContext(ctx)
    drawRouteOverview(draw, routeContext)
    drawRouteTabs(ctx, routeContext)
end

return ui
