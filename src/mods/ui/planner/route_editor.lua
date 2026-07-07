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

local function firstIssueRoomIndex(evaluation)
    local firstIssue = evaluation and evaluation.status and evaluation.status.firstIssue or nil
    local address = firstIssue and firstIssue.address or nil
    return address and address.roomIndex or nil
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
    widgets.status(imgui, evaluation, state.feedbackLocationLabel)

    local blockerRoomIndex = firstIssueRoomIndex(evaluation)
    for roomIndex, room in ipairs(state.currentBiome().rooms or {}) do
        local downstream = blockerRoomIndex ~= nil and roomIndex > blockerRoomIndex
        local disabled = widgets.beginDisabled(imgui, downstream, "Inactive after route blocker")
        roomForm.draw(state, imgui, evaluation, {
            routeKey = state.draft.routeKey,
            biomeIndex = 1,
            roomIndex = roomIndex,
        }, room)
        widgets.endDisabled(imgui, disabled)
    end

    if state.dirty then
        state.ensureEvaluation()
    end
end

return routeEditor
