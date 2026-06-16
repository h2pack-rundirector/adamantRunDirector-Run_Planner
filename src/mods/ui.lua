local ui = {}

local UNDERWORLD_REGION = "Underworld"
local SURFACE_REGION = "Surface"

local routeNavOpts = {}
local routeControlByTab = {}
local activeRouteTabs = {}

local roomRoutingOpts = {
    label = "Room Routing",
}
local rewardRoutingOpts = {
    label = "Reward Routing",
}
local planModeOpts

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
            controls[entry.key] = entry.controlName
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

local function drawRegionTab(ctx, region, childId)
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
    local controlName = routeControlByTab[region][activeTab]
    if controlName ~= nil then
        draw.control(ctx.controls.get(controlName), "planner")
    end
    imgui.EndChild()
end

local function drawRouteTabs(ctx)
    local imgui = ctx.draw.imgui
    if not imgui.BeginTabBar("RunPlannerRouteTabs") then
        return
    end

    if routeNavOpts[UNDERWORLD_REGION] ~= nil and imgui.BeginTabItem("Underworld") then
        drawRegionTab(ctx, UNDERWORLD_REGION, "RunPlannerUnderworld")
        imgui.EndTabItem()
    end

    if routeNavOpts[SURFACE_REGION] ~= nil and imgui.BeginTabItem("Surface") then
        drawRegionTab(ctx, SURFACE_REGION, "RunPlannerSurface")
        imgui.EndTabItem()
    end

    imgui.EndTabBar()
end

function ui.bind(deps)
    deps = deps or {}
    local data = deps.data or deps
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
    drawRouteTabs(ctx)
end

return ui
