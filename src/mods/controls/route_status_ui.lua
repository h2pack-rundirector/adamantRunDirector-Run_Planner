local routeStatusUi = {}

local STATUS_COLUMN_X = 590
local INVALID_COLOR = { 1.0, 0.24, 0.16, 1.0 }
local VALID_COLOR = { 0.35, 0.9, 0.45, 1.0 }
local textColoredMode

local function drawColoredText(imgui, color, text)
    if imgui.TextColored == nil or textColoredMode == "none" then
        imgui.Text(text)
        return
    end

    if textColoredMode == "rgba" then
        imgui.TextColored(color[1], color[2], color[3], color[4], text)
        return
    elseif textColoredMode == "table" then
        imgui.TextColored(color, text)
        return
    end

    local ok = pcall(imgui.TextColored, color[1], color[2], color[3], color[4], text)
    if ok then
        textColoredMode = "rgba"
        return
    end
    ok = pcall(imgui.TextColored, color, text)
    if ok then
        textColoredMode = "table"
        return
    end
    textColoredMode = "none"
    imgui.Text(text)
end

local function firstInvalidMessage(routeSnapshot)
    local invalidRows = routeSnapshot and routeSnapshot.invalidRows or nil
    local invalid = invalidRows and invalidRows[1] or nil
    local message = invalid and (invalid.message or invalid.code) or nil
    if message == nil or message == "" then
        return nil
    end
    return tostring(message)
end

function routeStatusUi.drawInvalid(draw, validation, columnX)
    if validation == nil or validation.valid then
        return false
    end

    local imgui = draw.imgui
    imgui.SameLine()
    imgui.SetCursorPosX(columnX or STATUS_COLUMN_X)
    imgui.AlignTextToFramePadding()
    drawColoredText(imgui, INVALID_COLOR, "Invalid")
    return true
end

function routeStatusUi.drawInvalidInline(draw, validation)
    if validation == nil or validation.valid then
        return false
    end

    local imgui = draw.imgui
    imgui.SameLine()
    imgui.AlignTextToFramePadding()
    drawColoredText(imgui, INVALID_COLOR, "Invalid")
    return true
end

function routeStatusUi.drawRouteStatus(draw, routeSnapshot)
    local label = tostring((routeSnapshot and routeSnapshot.label) or (routeSnapshot and routeSnapshot.routeKey) or "Route")
    local valid = routeSnapshot ~= nil and routeSnapshot.valid
    local text = label .. ": " .. (valid and "Valid" or "Invalid")
    drawColoredText(draw.imgui, valid and VALID_COLOR or INVALID_COLOR, text)

    local message = not valid and firstInvalidMessage(routeSnapshot) or nil
    if message ~= nil then
        drawColoredText(draw.imgui, INVALID_COLOR, message)
    end
end

return routeStatusUi
