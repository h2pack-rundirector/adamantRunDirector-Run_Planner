local routeStatus = {}
local deps = ... or {}
local decorations = deps.decorations

local ROUTE_MESSAGE_COLUMN_X = 165
local EMPTY_LIST = {}

local function invalidText(invalid)
    local message = invalid and (invalid.message or invalid.code) or nil
    if message == nil or message == "" then
        return nil
    end
    if invalid.locationLabel ~= nil and invalid.locationLabel ~= "" then
        return tostring(invalid.locationLabel) .. ": " .. tostring(message)
    end
    return tostring(message)
end

local function relatedInvalidText(invalid)
    local text = invalidText(invalid)
    if text == nil then
        return nil
    end
    return "Conflicts with " .. text
end

local function feedbackForRoute(routeSnapshot)
    return routeSnapshot and routeSnapshot.routeFeedback or nil
end

local function drawMessageLine(imgui, color, message, firstLine)
    if firstLine then
        imgui.SameLine()
    end
    imgui.SetCursorPosX(ROUTE_MESSAGE_COLUMN_X)
    decorations.drawColoredText(imgui, color, message)
end

function routeStatus.drawRouteStatus(draw, routeSnapshot)
    local label = tostring((routeSnapshot and routeSnapshot.label) or (routeSnapshot and routeSnapshot.routeKey) or "Route")
    local valid = routeSnapshot ~= nil and routeSnapshot.valid
    local incomplete = routeSnapshot ~= nil and routeSnapshot.incomplete == true
    local feedback, primaryInvalid
    if not valid and not incomplete then
        feedback = feedbackForRoute(routeSnapshot)
        primaryInvalid = feedback and feedback.primary or nil
    end
    local primaryMessage = incomplete and routeSnapshot.incompleteMessage or invalidText(primaryInvalid)
    local status = valid and "Valid" or (incomplete and "Incomplete" or "Invalid")
    local text = label .. " " .. status .. (primaryMessage ~= nil and ":" or "")
    local imgui = draw.imgui
    local invalidColor = decorations.invalidColor()
    local statusColor = valid and decorations.validColor() or (incomplete and decorations.warningColor() or invalidColor)
    decorations.drawColoredText(imgui, statusColor, text)

    if primaryMessage == nil then
        return
    end

    drawMessageLine(imgui, statusColor, primaryMessage, true)
    if incomplete then
        return
    end
    for _, related in ipairs((feedback and feedback.related) or EMPTY_LIST) do
        local relatedMessage = relatedInvalidText(related)
        if relatedMessage ~= nil then
            drawMessageLine(imgui, invalidColor, relatedMessage, false)
        end
    end
end

return routeStatus
