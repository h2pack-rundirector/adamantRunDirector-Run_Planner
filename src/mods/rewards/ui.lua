local deps = ... or {}
local runtime = deps.runtime
local dropdownValues = deps.dropdownValues

local ui = {}

local ROW_HEADER_WIDTH = 80
local GENERIC_REWARD_HEADER = "Reward"

local function conditionMatches(condition, fields)
    return fields:read(condition.alias) == condition.value
end

local function sourceActive(sourceIndex, opts)
    if sourceIndex == nil then
        return true
    end
    local sourceCount = opts and opts.sourceCount or nil
    if sourceCount == nil then
        return true
    end
    return sourceIndex <= sourceCount
end

local function conditionActive(condition, fields)
    if condition == nil then
        return true
    end
    for _, item in ipairs(condition.any or {}) do
        if conditionMatches(item, fields) then
            return true
        end
    end
    if condition.any ~= nil then
        return false
    end
    for _, item in ipairs(condition.all or {}) do
        if not conditionMatches(item, fields) then
            return false
        end
    end
    if condition.all ~= nil then
        return true
    end
    return conditionMatches(condition, fields)
end

local function isControlVisible(control, fields, opts)
    return sourceActive(control and control.sourceIndex or nil, opts)
        and conditionActive(control and control.visibleWhen or nil, fields)
end

local function drawRowHeader(imgui, header)
    imgui.AlignTextToFramePadding()
    imgui.Text(tostring(header or ""))
    imgui.SameLine()
end

local function drawGroupedRowStart(imgui, startX, header, reserveHeaderColumn)
    if header ~= nil then
        drawRowHeader(imgui, header)
    end
    if header ~= nil or reserveHeaderColumn then
        imgui.SetCursorPosX(startX + ROW_HEADER_WIDTH)
    else
        imgui.SetCursorPosX(startX)
    end
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function memberAlias(member)
    if type(member) == "table" then
        return member.alias
    end
    return member
end

local function groupMembers(group)
    if group.members ~= nil then
        return group.members
    end
    return group.aliases or {}
end

local function localValueStates(surface, fields, control, opts)
    if runtime == nil or runtime.valueStates == nil then
        return nil
    end
    local uniqueValueGroups = surface and surface.uniqueValueGroups
    if uniqueValueGroups == nil or uniqueValueGroups[1] == nil then
        return nil
    end
    local controlAlias = control.alias
    local participates = false
    for _, group in ipairs(uniqueValueGroups) do
        for _, member in ipairs(groupMembers(group)) do
            if memberAlias(member) == controlAlias then
                participates = true
                break
            end
        end
        if participates then
            break
        end
    end
    if not participates then
        return nil
    end
    local states = control._localValueStates
    if states == nil then
        states = {}
        control._localValueStates = states
    end
    return runtime.valueStates(surface, fields, control, states, opts)
end

local function externalValueStates(fields, control, opts)
    if opts == nil or opts.valueStatesForControl == nil then
        return nil
    end
    return opts.valueStatesForControl(control, fields, fields.rewardContext)
end

local function combineValueStates(control, first, second)
    if first == nil then
        return second
    elseif second == nil then
        return first
    end

    local states = control._combinedValueStates
    if states == nil then
        states = {}
        control._combinedValueStates = states
    else
        clearMap(states)
    end
    for key, value in pairs(first) do
        states[key] = value
    end
    for key, value in pairs(second) do
        states[key] = value
    end
    return states
end

local function drawControl(draw, surface, fields, control, opts)
    local field = fields:get(control.alias)
    local drawOpts = control.drawOpts
    if opts ~= nil
        and opts.hideGenericRewardLabel
        and control.genericRewardLabelHiddenDrawOpts ~= nil
    then
        drawOpts = control.genericRewardLabelHiddenDrawOpts
    end
    if control.kind == "boonSource"
        and opts ~= nil
        and opts.godSource ~= nil
        and opts.godSource.godSourceDrawOpts ~= nil
    then
        drawOpts = opts.godSource:godSourceDrawOpts(drawOpts, field:read())
    end
    local valueStates = combineValueStates(
        control,
        externalValueStates(fields, control, opts),
        localValueStates(surface, fields, control, opts)
    )
    drawOpts = dropdownValues.decorate(control, drawOpts, valueStates)
    local changed = draw.widgets.dropdown(field, drawOpts)
    if changed and opts ~= nil and opts.onControlChanged ~= nil then
        opts.onControlChanged(control, fields, fields.rewardContext)
    end
    return changed
end

local function hasGroupedRows(surface)
    if surface.rowHeader ~= nil then
        return true
    end
    for _, control in ipairs(surface.controls or {}) do
        if control.rowIndex ~= nil then
            return true
        end
    end
    return false
end

local function drawGroupedControls(draw, surface, fields, opts)
    local imgui = draw.imgui
    local startX = imgui.GetCursorPosX()
    local rowIndex = nil
    local drew = false
    local changed = false
    local rowHeader = surface.rowHeader
    if opts ~= nil and opts.hideGenericRewardLabel and rowHeader == GENERIC_REWARD_HEADER then
        rowHeader = nil
    end
    local reserveHeaderColumn = rowHeader ~= nil

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields, opts) then
            if rowIndex ~= control.rowIndex then
                rowIndex = control.rowIndex
                drawGroupedRowStart(imgui, startX, not drew and rowHeader or nil, reserveHeaderColumn)
            else
                imgui.SameLine()
            end
            changed = drawControl(draw, surface, fields, control, opts) or changed
            drew = true
        end
    end
    return changed
end

function ui.draw(draw, surface, fields, opts)
    if runtime ~= nil and not runtime.hasControls(surface) then
        return false
    end
    if surface == nil or fields == nil then
        return false
    end

    local drew = false
    local changed = false
    local imgui = draw.imgui
    if hasGroupedRows(surface) then
        return drawGroupedControls(draw, surface, fields, opts)
    end

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields, opts) then
            if drew then
                imgui.SameLine()
            end
            changed = drawControl(draw, surface, fields, control, opts) or changed
            drew = true
        end
    end
    return changed
end

return ui
