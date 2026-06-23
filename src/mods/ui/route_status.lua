local routeStatus = {}
local deps = ... or {}
local decorations = deps.decorations

local ROUTE_MESSAGE_COLUMN_X = 165

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

local function firstInvalid(routeSnapshot)
    local invalidRows = routeSnapshot and routeSnapshot.invalidRows or nil
    return invalidRows, invalidRows and invalidRows[1] or nil
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
    local invalidRows, primaryInvalid
    if not valid then
        invalidRows, primaryInvalid = firstInvalid(routeSnapshot)
    end
    local primaryMessage = invalidText(primaryInvalid)
    local status = valid and "Valid" or "Invalid"
    local text = label .. " " .. status .. (primaryMessage ~= nil and ":" or "")
    local imgui = draw.imgui
    local invalidColor = decorations.invalidColor()
    decorations.drawColoredText(imgui, valid and decorations.validColor() or invalidColor, text)

    if primaryMessage == nil then
        return
    end

    drawMessageLine(imgui, invalidColor, primaryMessage, true)
    for index = 2, #invalidRows do
        local related = invalidRows[index]
        if related.markerKind ~= "related" then
            break
        end
        local relatedMessage = relatedInvalidText(related)
        if relatedMessage ~= nil then
            drawMessageLine(imgui, invalidColor, relatedMessage, false)
        end
    end
end

return routeStatus
