local routeEditor = import("mods/ui/planner/route_editor.lua")
local plannerState = import("mods/ui/planner/state.lua")

local debugHarness = {}

local ROUTE_EDITOR_OPTIONS = {
    title = "Run Planner debug harness",
    notes = {
        "Minimal F route editor using the real form, history, validation, and feedback pipeline.",
        "Uses docs/system_design contracts; not the final planner UI.",
    },
}

function debugHarness.defaultDraft()
    return plannerState.defaultDraft()
end

function debugHarness.create(opts)
    local state = plannerState.create(opts)
    state.drawTab = function(_, ctx)
        return routeEditor.draw(state, ctx, ROUTE_EDITOR_OPTIONS)
    end
    return state
end

return debugHarness
