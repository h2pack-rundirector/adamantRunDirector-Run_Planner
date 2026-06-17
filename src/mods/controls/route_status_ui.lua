local routeStatusUi = {}

local STATUS_COLUMN_X = 590
local INVALID_COLOR = { 1.0, 0.24, 0.16, 1.0 }
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

return routeStatusUi
