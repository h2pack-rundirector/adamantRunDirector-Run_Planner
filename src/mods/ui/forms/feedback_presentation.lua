local widgets = import("mods/ui/planner/widgets.lua")

local feedbackPresentation = {}

local COLORS = {
    blocker = { 1.0, 0.25, 0.20, 1.0 },
    invalid = { 1.0, 0.35, 0.25, 1.0 },
    incomplete = { 1.0, 0.72, 0.25, 1.0 },
    warning = { 1.0, 0.82, 0.35, 1.0 },
    muted = { 0.65, 0.65, 0.65, 1.0 },
}

local function findingSeverity(finding)
    return finding and (finding.severity or finding.presentation) or nil
end

function feedbackPresentation.colorFor(finding, role)
    if finding == nil then
        return nil
    end
    if role == "blocker" then
        return COLORS.blocker
    end

    local severity = findingSeverity(finding)
    if severity == "incomplete" then
        return COLORS.incomplete
    end
    if severity == "warning" then
        return COLORS.warning
    end
    if severity == "muted" then
        return COLORS.muted
    end
    return COLORS.invalid
end

function feedbackPresentation.format(label, finding, opts)
    if finding == nil then
        return nil
    end
    opts = opts or {}

    local text = tostring(label) .. ": " .. tostring(finding.code)
    if finding.field ~= nil then
        text = text .. " [" .. tostring(finding.field) .. "]"
    end
    if finding.message ~= nil and finding.message ~= "" then
        text = text .. " - " .. tostring(finding.message)
    end
    if opts.location ~= nil then
        text = text .. " at " .. tostring(opts.location)
    end
    return text
end

function feedbackPresentation.draw(imgui, label, finding, opts)
    if finding == nil then
        return false
    end
    opts = opts or {}
    widgets.textColored(
        imgui,
        feedbackPresentation.format(label, finding, opts),
        feedbackPresentation.colorFor(finding, opts.role)
    )
    return true
end

return feedbackPresentation
