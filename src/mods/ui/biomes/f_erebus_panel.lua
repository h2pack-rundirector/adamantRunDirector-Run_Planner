local roomForm = import("mods/ui/forms/room.lua")
local presentationColors = import("mods/ui/planner/presentation_colors.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local fErebusPanel = {}

local DEFAULT_OPTIONS = {
    title = "F / Erebus",
    notes = {},
}

local function drawHeader(imgui, opts)
    opts = opts or DEFAULT_OPTIONS
    widgets.text(imgui, opts.title or DEFAULT_OPTIONS.title)
    for _, note in ipairs(opts.notes or DEFAULT_OPTIONS.notes) do
        widgets.text(imgui, note)
    end
end

local function firstIssue(evaluation)
    return evaluation and evaluation.status and evaluation.status.firstIssue or nil
end

local function firstIssueRoomIndex(evaluation)
    local issue = firstIssue(evaluation)
    local address = issue and issue.address or nil
    return address and address.roomIndex or nil
end

local function inactiveMarkerText(state, evaluation)
    local issue = firstIssue(evaluation)
    local location = issue and issue.address and state.feedbackLocationLabel(issue.address) or nil
    if location ~= nil then
        return "Downstream inactive after first issue: " .. tostring(location)
    end
    return "Downstream inactive after first issue"
end

function fErebusPanel.draw(state, ctx, opts)
    opts = opts or DEFAULT_OPTIONS
    local imgui = ctx.draw.imgui

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

    local evaluation = opts.evaluation or state.ensureEvaluation()
    if opts.hideStatus ~= true then
        widgets.separator(imgui)
        widgets.status(imgui, evaluation, state.feedbackLocationLabel)
    end

    local blockerRoomIndex = firstIssueRoomIndex(evaluation)
    local inactiveMarkerDrawn = false
    for roomIndex, room in ipairs(state.currentBiome().rooms or {}) do
        local downstream = blockerRoomIndex ~= nil and roomIndex > blockerRoomIndex
        if downstream and not inactiveMarkerDrawn then
            widgets.textColored(imgui, inactiveMarkerText(state, evaluation), presentationColors.muted)
            inactiveMarkerDrawn = true
        end
        local disabled = widgets.beginDisabled(imgui, downstream)
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

return fErebusPanel
