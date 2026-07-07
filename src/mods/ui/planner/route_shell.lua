local biomePanels = import("mods/ui/biomes/registry.lua")
local routeNav = import("mods/ui/planner/route_nav.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local routeShell = {}

function routeShell.draw(state, ctx)
    local imgui = ctx and ctx.draw and ctx.draw.imgui or nil
    state.bindUiContext(ctx)
    local evaluation = state.ensureEvaluation()
    widgets.text(imgui, "Run Planner")
    widgets.status(imgui, evaluation, state.feedbackLocationLabel)
    widgets.separator(imgui)
    routeNav.draw(state, ctx, evaluation, biomePanels)
    if state.dirty then
        state.ensureEvaluation()
    end
end

return routeShell
