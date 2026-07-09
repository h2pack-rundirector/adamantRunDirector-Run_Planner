local presentationColors = import("mods/ui/planner/presentation_colors.lua")

local widgets = {}

---@class PlannerDropdownProvider
---@field values table
---@field labels? table
---@field hidden? table
---@field colors? table
---@field messages? table
---@field version? integer

local EMPTY_PROVIDER = {
    values = {},
    labels = {},
}

local function providerOrEmpty(provider)
    return provider or EMPTY_PROVIDER
end

function widgets.valueIndex(provider, value)
    provider = providerOrEmpty(provider)
    for index, candidate in ipairs(provider.values or EMPTY_PROVIDER.values) do
        if candidate == value then
            return index
        end
    end
    return nil
end

function widgets.choiceLabel(provider, index, candidate)
    provider = providerOrEmpty(provider)
    local label = provider.labels and provider.labels[index] or nil
    if label == nil then
        label = candidate
    end
    return tostring(label)
end

function widgets.choiceVisible(provider, index)
    provider = providerOrEmpty(provider)
    return not (provider.hidden and provider.hidden[index])
end

function widgets.choiceColor(provider, index)
    provider = providerOrEmpty(provider)
    return provider.colors and provider.colors[index] or nil
end

function widgets.choiceMessage(provider, index)
    provider = providerOrEmpty(provider)
    return provider.messages and provider.messages[index] or nil
end

function widgets.preview(provider, value)
    provider = providerOrEmpty(provider)
    local index = widgets.valueIndex(provider, value)
    if index == nil then
        return tostring(value)
    end
    return widgets.choiceLabel(provider, index, provider.values[index])
end

function widgets.previewState(provider, value)
    provider = providerOrEmpty(provider)
    local index = widgets.valueIndex(provider, value)
    if index == nil then
        return tostring(value), nil, nil, nil
    end
    return widgets.choiceLabel(provider, index, provider.values[index]),
        widgets.choiceColor(provider, index),
        widgets.choiceMessage(provider, index),
        index
end

function widgets.text(imgui, text)
    imgui.Text(text)
end

function widgets.textMuted(imgui, text)
    imgui.TextDisabled(text)
end

function widgets.separator(imgui)
    imgui.Separator()
end

function widgets.sameLine(imgui)
    imgui.SameLine()
end

function widgets.button(imgui, label)
    return imgui.SmallButton(label)
end

local function pushTextColor(imgui, color)
    if color == nil then
        return false
    end
    imgui.PushStyleColor(imgui.ImGuiCol.Text, color[1], color[2], color[3], color[4] or 1)
    return true
end

local function popTextColor(imgui, pushed)
    if pushed then
        imgui.PopStyleColor()
    end
end

local function showTooltip(imgui, message)
    if message == nil then
        return
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(message)
    end
end

local function selectableId(provider, index, candidate)
    return widgets.choiceLabel(provider, index, candidate) .. "##" .. tostring(index)
end

local function selectableClicked(imgui, label, selected)
    local activated, changed = imgui.Selectable(label, selected)
    if changed ~= nil then
        return changed == true
    end
    return activated == true
end

function widgets.textColored(imgui, text, color)
    local pushed = pushTextColor(imgui, color)
    widgets.text(imgui, text)
    popTextColor(imgui, pushed)
end

function widgets.dropdown(imgui, label, value, provider)
    provider = providerOrEmpty(provider)

    local nextValue = value
    local changed = false
    local previewText, previewColor, previewMessage = widgets.previewState(provider, value)
    local previewPushed = pushTextColor(imgui, previewColor)
    local opened = imgui.BeginCombo(label, previewText)
    popTextColor(imgui, previewPushed)
    showTooltip(imgui, previewMessage)

    if opened then
        for index, candidate in ipairs(provider.values or EMPTY_PROVIDER.values) do
            if widgets.choiceVisible(provider, index) then
                local pushed = pushTextColor(imgui, widgets.choiceColor(provider, index))
                local selected = candidate == value
                if selectableClicked(imgui, selectableId(provider, index, candidate), selected) then
                    nextValue = candidate
                    changed = nextValue ~= value
                    imgui.CloseCurrentPopup()
                end
                showTooltip(imgui, widgets.choiceMessage(provider, index))
                popTextColor(imgui, pushed)
            end
        end
        imgui.EndCombo()
    end
    return nextValue, changed
end

function widgets.checkbox(imgui, label, value)
    return imgui.Checkbox(label, value == true)
end

function widgets.feedback(imgui, label, feedback)
    if feedback ~= nil then
        widgets.text(imgui, label .. ": " .. feedback.code .. " - " .. tostring(feedback.message))
    end
end

function widgets.labelValue(imgui, label, value)
    widgets.text(imgui, label .. ": " .. tostring(value))
end

function widgets.indent(imgui)
    imgui.Indent()
    return true
end

function widgets.unindent(imgui, pushed)
    if pushed then
        imgui.Unindent()
    end
end

function widgets.beginDisabled(imgui, disabled)
    if not disabled then
        return false
    end
    imgui.BeginDisabled(true)
    return true
end

function widgets.endDisabled(imgui, pushed)
    if pushed then
        imgui.EndDisabled()
    end
end

function widgets.status(imgui, evaluation, locationForAddress)
    widgets.textColored(
        imgui,
        "State: " .. tostring(evaluation.state),
        presentationColors.forEvaluation(evaluation)
    )
    widgets.text(imgui, "Complete: " .. tostring(evaluation.complete) .. "  Valid: " .. tostring(evaluation.valid))
    widgets.text(imgui, "Feedback: " .. tostring(evaluation.status.feedbackCount)
        .. "  Candidates: " .. tostring(#(evaluation.candidateResults or {})))
    if evaluation.history ~= nil then
        widgets.text(imgui, "Events: " .. tostring(#evaluation.history.events)
            .. "  Doors: " .. tostring(#evaluation.history.generatedDoorHistory)
            .. "  Offers: " .. tostring(#evaluation.history.rewardOfferHistory))
    end
    if evaluation.status.firstIssue ~= nil then
        local location = locationForAddress and locationForAddress(evaluation.status.firstIssue.address) or nil
        local issueLocation = tostring(evaluation.status.firstIssue.phase)
        if location ~= nil then
            issueLocation = location .. " (" .. issueLocation .. ")"
        end
        widgets.textColored(
            imgui,
            "First issue: " .. tostring(evaluation.status.firstIssue.code) .. " at " .. issueLocation,
            presentationColors.forFinding(evaluation.status.firstIssue)
        )
    end
end

function widgets.section(imgui, label)
    widgets.separator(imgui)
    widgets.text(imgui, label)
end

function widgets.subsection(imgui, label)
    widgets.textMuted(imgui, label)
end

return widgets
