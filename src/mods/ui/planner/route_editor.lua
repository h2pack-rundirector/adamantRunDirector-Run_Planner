local roomForm = import("mods/ui/forms/room.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local routeEditor = {}

local DEFAULT_OPTIONS = {
    title = "F route editor",
    notes = {},
}

local function drawHeader(imgui, opts)
    opts = opts or DEFAULT_OPTIONS
    widgets.text(imgui, opts.title or DEFAULT_OPTIONS.title)
    for _, note in ipairs(opts.notes or DEFAULT_OPTIONS.notes) do
        widgets.text(imgui, note)
    end
end

function routeEditor.draw(state, ctx, opts)
    local drawContext = ctx and ctx.draw or nil
    local imgui = drawContext and drawContext.imgui or nil

    drawHeader(imgui, opts)

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
