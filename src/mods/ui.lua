local plannerState = import("mods/ui/planner/state.lua")
local routeShell = import("mods/ui/planner/route_shell.lua")

local ui = {}
local defaultInstance

local function createRouteShell(opts)
    if opts.routeShell ~= nil then
        return opts.routeShell
    end
    return routeShell.create({
        routeNav = opts.routeNav,
        routeSelection = opts.routeSelection,
        biomePanels = opts.biomePanels,
        fErebusPanel = opts.fErebusPanel,
        placeholderPanel = opts.placeholderPanel,
        widgets = opts.widgets,
    })
end

local function createPlannerState(opts)
    if opts.state ~= nil then
        return opts.state
    end
    local stateModule = opts.plannerState or plannerState
    return stateModule.create(opts)
end

local function attachDrawTab(state, shell)
    state.drawTab = function(_, ctx)
        return shell.draw(state, ctx)
    end
    return state
end

function ui.create(opts)
    opts = opts or {}
    return attachDrawTab(createPlannerState(opts), createRouteShell(opts))
end

function ui.drawTab(_, ctx)
    if defaultInstance == nil then
        defaultInstance = ui.create()
    end
    return defaultInstance.drawTab(nil, ctx)
end

return ui
