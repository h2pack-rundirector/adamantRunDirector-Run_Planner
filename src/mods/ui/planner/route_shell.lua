local biomePanels = import("mods/ui/biomes/registry.lua")
local routeNav = import("mods/ui/planner/route_nav.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local routeShell = {}
local defaultInstance

local function childService(explicit, module, deps)
    if explicit ~= nil then
        return explicit
    end
    return module.create(deps)
end

local function drawShell(service, state, ctx)
    local imgui = ctx.draw.imgui
    state.bindUiContext(ctx)
    local evaluation = state.ensureEvaluation()
    service.widgets.text(imgui, "Run Planner")
    service.widgets.status(imgui, evaluation, state.feedbackLocationLabel)
    service.widgets.separator(imgui)
    service.routeNav.draw(state, ctx, evaluation, service.biomePanels)
    if state.dirty then
        state.ensureEvaluation()
    end
end

function routeShell.create(deps)
    deps = deps or {}
    local service = {
        widgets = deps.widgets or widgets,
        routeNav = childService(deps.routeNav, routeNav, {
            routeSelection = deps.routeSelection,
            widgets = deps.widgets or widgets,
        }),
        biomePanels = childService(deps.biomePanels, biomePanels, {
            fErebusPanel = deps.fErebusPanel,
            placeholderPanel = deps.placeholderPanel,
        }),
    }

    function service.draw(state, ctx)
        return drawShell(service, state, ctx)
    end

    return service
end

function routeShell.draw(state, ctx)
    if defaultInstance == nil then
        defaultInstance = routeShell.create()
    end
    return defaultInstance.draw(state, ctx)
end

return routeShell
