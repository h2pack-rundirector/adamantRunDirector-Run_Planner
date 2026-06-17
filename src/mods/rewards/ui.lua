local deps = ... or {}
local runtime = deps.runtime

local ui = {}

local ROW_HEADER_WIDTH = 80

local function conditionMatches(condition, fields)
    return fields:read(condition.alias) == condition.value
end

local function isControlVisible(control, fields)
    local condition = control and control.visibleWhen
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

local function drawRowHeader(imgui, header)
    imgui.AlignTextToFramePadding()
    imgui.Text(tostring(header or ""))
    imgui.SameLine()
end

local function drawGroupedRowStart(imgui, startX, header)
    if header ~= nil then
        drawRowHeader(imgui, header)
    end
    imgui.SetCursorPosX(startX + ROW_HEADER_WIDTH)
end

local function drawControl(draw, fields, control)
    draw.widgets.dropdown(fields:get(control.alias), control.drawOpts)
end

local function drawGroupedControls(draw, surface, fields)
    local imgui = draw.imgui
    local startX = imgui.GetCursorPosX()
    local rowIndex = nil
    local drew = false

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields) then
            if rowIndex ~= control.rowIndex then
                rowIndex = control.rowIndex
                drawGroupedRowStart(imgui, startX, not drew and surface.rowHeader or nil)
            else
                imgui.SameLine()
            end
            drawControl(draw, fields, control)
            drew = true
        end
    end
    return drew
end

function ui.draw(draw, surface, fields)
    if runtime ~= nil and not runtime.hasControls(surface) then
        return false
    end
    if surface == nil or fields == nil then
        return false
    end

    local drew = false
    local imgui = draw.imgui
    if surface.rowHeader ~= nil then
        return drawGroupedControls(draw, surface, fields)
    end

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields) then
            if drew then
                imgui.SameLine()
            end
            drawControl(draw, fields, control)
            drew = true
        end
    end
    return drew
end

return ui
