local deps = ... or {}
local runtime = deps.runtime
local decorations = deps.decorations

local ui = {}

local ROW_HEADER_WIDTH = 80
local GENERIC_REWARD_HEADER = "Reward"
local SHOP_BOUGHT_VALUE = "Bought"
local SHOP_SKIPPED_VALUE = "Skipped"

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
        if conditionActive(item, fields) then
            return true
        end
    end
    if condition.any ~= nil then
        return false
    end
    for _, item in ipairs(condition.all or {}) do
        if not conditionActive(item, fields) then
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

local function externalValueStates(fields, control, opts)
    if opts == nil or opts.valueStatesForControl == nil then
        return nil
    end
    return opts.valueStatesForControl(control, fields, fields.rewardContext)
end

local function drawControl(draw, fields, control, opts)
    local field = fields:get(control.alias)
    if control.kind == "purchaseState" then
        if control.prefixLabel ~= nil then
            draw.imgui.AlignTextToFramePadding()
            draw.imgui.Text(control.prefixLabel)
            draw.imgui.SameLine()
        end
        local current = field:read() == SHOP_BOUGHT_VALUE
        local label = control.label .. "##"
            .. tostring(fields.rewardContext and fields.rewardContext.rowIndex or "")
            .. ":"
            .. tostring(fields.rewardContext and fields.rewardContext.address or "")
            .. ":"
            .. tostring(control.alias)
        local nextValue, changed = draw.imgui.Checkbox(label, current)
        if changed then
            field:write(nextValue == true and SHOP_BOUGHT_VALUE or SHOP_SKIPPED_VALUE)
            if opts ~= nil and opts.onControlChanged ~= nil then
                opts.onControlChanged(control, fields, fields.rewardContext)
            end
        end
        return changed
    end
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
    local valueStates = externalValueStates(fields, control, opts)
    drawOpts = decorations.decorateDropdown(control, drawOpts, valueStates)
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
    local rowDrew = false
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
            elseif rowDrew then
                imgui.SameLine()
            end
            changed = drawControl(draw, fields, control, opts) or changed
            drew = true
            rowDrew = true
        end
    end
    return changed
end

function ui.draw(draw, surface, fields, opts)
    if runtime ~= nil and not runtime.hasDisplay(surface) then
        return false
    end
    if surface == nil or fields == nil then
        return false
    end

    local drew = false
    local changed = false
    local imgui = draw.imgui
    if surface.displayLabel ~= nil then
        imgui.AlignTextToFramePadding()
        imgui.Text(tostring(surface.displayLabel))
        return false
    end
    if hasGroupedRows(surface) then
        return drawGroupedControls(draw, surface, fields, opts)
    end

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields, opts) then
            if drew then
                imgui.SameLine()
            end
            changed = drawControl(draw, fields, control, opts) or changed
            drew = true
        end
    end
    return changed
end

return ui
