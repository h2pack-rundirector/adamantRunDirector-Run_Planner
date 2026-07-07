local routeEditor = import("mods/ui/planner/route_editor.lua")
local plannerState = import("mods/ui/planner/state.lua")

local debugHarness = {}

function debugHarness.defaultDraft()
    return plannerState.defaultDraft()
end

function debugHarness.create(opts)
    local state = plannerState.create(opts)
    state.drawTab = function(_, ctx)
        return routeEditor.draw(state, ctx)
    end
    return state
end

return debugHarness
