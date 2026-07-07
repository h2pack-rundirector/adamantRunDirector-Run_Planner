local plannerState = import("mods/ui/planner/state.lua")
local routeShell = import("mods/ui/planner/route_shell.lua")

local ui = {}
local defaultInstance

local function attachDrawTab(state)
    state.drawTab = function(_, ctx)
        return routeShell.draw(state, ctx)
    end
    return state
end

function ui.create(opts)
    return attachDrawTab(plannerState.create(opts))
end

function ui.drawTab(_, ctx)
    if defaultInstance == nil then
        defaultInstance = ui.create()
    end
    return defaultInstance.drawTab(nil, ctx)
end

return ui
