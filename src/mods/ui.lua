local deps = ...
local coordinator = deps.coordinator
local selectors = deps.selectors
local layoutDrawers = deps.layoutDrawers

local uiModule = {}

local RESET_OPTS = {
    confirmLabel = "Confirm Reset All",
}

local NAV_OPTS = {
    Underworld = {
        id = "RunPlannerUnderworldNavigation",
        navWidth = 180,
    },
    Surface = {
        id = "RunPlannerSurfaceNavigation",
        navWidth = 180,
    },
}

local function activePanel(ui, routeKey, routeView)
    local field = ui.data.get(selectors.routePanels[routeKey])
    local active = field:read()
    local visible = false
    for _, tab in ipairs(routeView.navTabs) do
        if tab.key == active then
            visible = true
            break
        end
    end
    if not visible then
        active = "route"
        field:write(active)
    end
    local opts = NAV_OPTS[routeKey]
    opts.activeKey = active
    opts.tabs = routeView.navTabs
    local selected = ui.draw.nav.verticalTabs(opts)
    if selected ~= active then
        field:write(selected)
    end
    return selected
end

local function drawRoute(ui, routeKey, routeView)
    local active = activePanel(ui, routeKey, routeView)
    ui.draw.imgui.BeginChild("RunPlanner" .. routeKey .. "Detail", 0, 0, false)
    if active == "route" then
        ui.draw.widgets.text(routeView.label .. " Route")
        ui.draw.widgets.separator()
        ui.draw.control(ui.controls.get(routeKey), "default")
    else
        local biome = routeView.biomes.lookup[active]
        local drawer = biome and layoutDrawers[biome.layoutKind] or nil
        if drawer == nil then
            error("missing authored UI drawer for layout kind '"
                .. tostring(biome and biome.layoutKind) .. "'", 0)
        end
        drawer.draw(ui, biome, coordinator:uiPlan(ui, biome.key))
    end
    ui.draw.imgui.EndChild()
end

local function drawSettings(ui)
    ui.draw.widgets.text("Run Planner Settings")
    ui.draw.widgets.separator()
    ui.draw.widgets.text("The authored editor is active; runtime planning remains disabled.")
    ui.draw.imgui.Spacing()
    if ui.draw.widgets.confirmButton(
        "RunPlannerResetAll",
        "Reset To Defaults",
        RESET_OPTS
    ) then
        ui.resetAll()
    end
end

function uiModule.drawTab(_, ui)
    local published = coordinator:get()
    if published == nil then
        ui.draw.widgets.text("Run Planner authored editor is unavailable.")
        return
    end
    local imgui = ui.draw.imgui
    if not imgui.BeginTabBar("RunPlannerRouteTabs") then
        return
    end
    local underworld = published.routes.lookup.Underworld
    if imgui.BeginTabItem("Underworld") then
        drawRoute(ui, "Underworld", underworld)
        imgui.EndTabItem()
    end
    local surface = published.routes.lookup.Surface
    if imgui.BeginTabItem("Surface") then
        drawRoute(ui, "Surface", surface)
        imgui.EndTabItem()
    end
    if imgui.BeginTabItem("Settings") then
        drawSettings(ui)
        imgui.EndTabItem()
    end
    imgui.EndTabBar()
end

function uiModule.attach(module)
    module.ui.tab(uiModule.drawTab)
    module.onActivate(function(_, runtime)
        coordinator:rebuild(runtime)
    end)
    module.onCommit(function(_, runtime, commit)
        if commit.hadConfigChanges() then
            coordinator:rebuild(runtime)
        end
    end)
    module.onReload(function(_, runtime, reload)
        if reload.hadSettingChanges() then
            coordinator:rebuild(runtime)
        end
    end)
end

return uiModule
