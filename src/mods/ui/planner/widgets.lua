local widgets = {}

local EMPTY_PROVIDER = {
    values = {},
    labels = {},
}

local function providerOrEmpty(provider)
    return provider or EMPTY_PROVIDER
end

local function valueIndex(provider, value)
    for index, candidate in ipairs(provider.values or EMPTY_PROVIDER.values) do
        if candidate == value then
            return index
        end
    end
    return nil
end

function widgets.preview(provider, value)
    provider = providerOrEmpty(provider)
    local index = valueIndex(provider, value)
    if index == nil then
        return tostring(value)
    end
    return provider.labels[index]
end

function widgets.text(imgui, text)
    if imgui ~= nil and imgui.Text ~= nil then
        imgui.Text(text)
    end
end

function widgets.separator(imgui)
    if imgui ~= nil and imgui.Separator ~= nil then
        imgui.Separator()
    end
end

function widgets.sameLine(imgui)
    if imgui ~= nil and imgui.SameLine ~= nil then
        imgui.SameLine()
    end
end

function widgets.button(imgui, label)
    if imgui == nil then
        return false
    end
    if imgui.SmallButton ~= nil then
        return imgui.SmallButton(label)
    end
    if imgui.Button ~= nil then
        return imgui.Button(label)
    end
    return false
end

local function pushTextColor(imgui, color)
    if color == nil or imgui == nil or imgui.PushStyleColor == nil then
        return false
    end

    local ok = pcall(imgui.PushStyleColor, "Text", color)
    if ok then
        return true
    end

    ok = pcall(imgui.PushStyleColor, "Text", color[1], color[2], color[3], color[4] or 1)
    return ok == true
end

local function popTextColor(imgui, pushed)
    if pushed and imgui ~= nil and imgui.PopStyleColor ~= nil then
        imgui.PopStyleColor()
    end
end

local function showTooltip(imgui, message)
    if message == nil or imgui == nil or imgui.IsItemHovered == nil or imgui.SetTooltip == nil then
        return
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(message)
    end
end

local function selectableId(provider, index, candidate)
    local label = provider.labels and provider.labels[index] or nil
    if label == nil then
        label = candidate
    end
    return tostring(label) .. "##" .. tostring(index)
end

local function selectableClicked(imgui, label, selected)
    local activated, changed = imgui.Selectable(label, selected)
    if changed ~= nil then
        return changed == true
    end
    return activated == true
end

function widgets.dropdown(imgui, label, value, provider)
    provider = providerOrEmpty(provider)
    if imgui == nil or imgui.BeginCombo == nil or imgui.Selectable == nil or imgui.EndCombo == nil then
        widgets.text(imgui, label .. ": " .. widgets.preview(provider, value))
        return value, false
    end

    local nextValue = value
    local changed = false
    if imgui.BeginCombo(label, widgets.preview(provider, value)) then
        for index, candidate in ipairs(provider.values or EMPTY_PROVIDER.values) do
            if not (provider.hidden and provider.hidden[index]) then
                local pushed = pushTextColor(imgui, provider.colors and provider.colors[index])
                local selected = candidate == value
                if selectableClicked(imgui, selectableId(provider, index, candidate), selected) then
                    nextValue = candidate
                    changed = nextValue ~= value
                    if imgui.CloseCurrentPopup ~= nil then
                        imgui.CloseCurrentPopup()
                    end
                end
                if selected and imgui.SetItemDefaultFocus ~= nil then
                    imgui.SetItemDefaultFocus()
                end
                showTooltip(imgui, provider.messages and provider.messages[index])
                popTextColor(imgui, pushed)
            end
        end
        imgui.EndCombo()
    end
    return nextValue, changed
end

function widgets.checkbox(imgui, label, value)
    local checked = value == true
    if imgui ~= nil and imgui.Checkbox ~= nil then
        return imgui.Checkbox(label, checked)
    end
    widgets.text(imgui, label .. ": " .. tostring(checked))
    return checked, false
end

function widgets.feedback(imgui, label, feedback)
    if feedback ~= nil then
        widgets.text(imgui, label .. ": " .. feedback.code .. " - " .. tostring(feedback.message))
    end
end

function widgets.beginDisabled(imgui, disabled, fallbackLabel)
    if not disabled then
        return false
    end
    if imgui ~= nil and imgui.BeginDisabled ~= nil then
        imgui.BeginDisabled(true)
        return true
    end
    widgets.text(imgui, fallbackLabel)
    return false
end

function widgets.endDisabled(imgui, pushed)
    if pushed and imgui ~= nil and imgui.EndDisabled ~= nil then
        imgui.EndDisabled()
    end
end

function widgets.status(imgui, evaluation, locationForAddress)
    widgets.text(imgui, "State: " .. tostring(evaluation.state))
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
        widgets.text(imgui, "First issue: " .. tostring(evaluation.status.firstIssue.code)
            .. " at " .. issueLocation)
    end
end

function widgets.section(imgui, label)
    widgets.separator(imgui)
    widgets.text(imgui, label)
end

return widgets
