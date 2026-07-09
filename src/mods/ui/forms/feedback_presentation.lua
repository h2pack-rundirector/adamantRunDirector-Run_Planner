local presentationColors = import("mods/ui/planner/presentation_colors.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local feedbackPresentation = {}

function feedbackPresentation.colorFor(finding, role)
    return presentationColors.forFinding(finding, role)
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
