local roomForm = import("mods/ui/forms/room.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local routeEditor = {}

local TITLE = "Run Planner debug harness"
local HELP = "Minimal F route editor using the real form, history, validation, and feedback pipeline."

function routeEditor.draw(state, ctx)
    local drawContext = ctx and ctx.draw or nil
    local imgui = drawContext and drawContext.imgui or nil

    widgets.text(imgui, TITLE)
    widgets.text(imgui, HELP)
    widgets.text(imgui, "Uses docs/system_design contracts; not the final planner UI.")

    if widgets.button(imgui, "Reset F sample") then
        state.resetDraft()
    end
    widgets.sameLine(imgui)
    if widgets.button(imgui, "Append selected target") then
        state.appendSelectedTarget()
    end
    widgets.sameLine(imgui)
    if widgets.button(imgui, "Remove last room") then
        state.removeLastRoom()
    end

    local evaluation = state.ensureEvaluation()
    widgets.separator(imgui)
    widgets.status(imgui, evaluation)

    for roomIndex, room in ipairs(state.currentBiome().rooms or {}) do
        roomForm.draw(state, imgui, evaluation, {
            routeKey = state.draft.routeKey,
            biomeIndex = 1,
            roomIndex = roomIndex,
        }, room)
    end

    if state.dirty then
        state.ensureEvaluation()
    end
end

return routeEditor
