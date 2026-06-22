local routeStatus = {}
local deps = ... or {}
local decorations = deps.decorations

local ROUTE_MESSAGE_COLUMN_X = 165

local function firstInvalidMessage(routeSnapshot)
    local invalidRows = routeSnapshot and routeSnapshot.invalidRows or nil
    local invalid = invalidRows and invalidRows[1] or nil
    local message = invalid and (invalid.message or invalid.code) or nil
    if message == nil or message == "" then
        return nil
    end
    if invalid.locationLabel ~= nil and invalid.locationLabel ~= "" then
        return tostring(invalid.locationLabel) .. ": " .. tostring(message)
    end
    return tostring(message)
end

function routeStatus.drawRouteStatus(draw, routeSnapshot)
    local label = tostring((routeSnapshot and routeSnapshot.label) or (routeSnapshot and routeSnapshot.routeKey) or "Route")
    local valid = routeSnapshot ~= nil and routeSnapshot.valid
    local message = not valid and firstInvalidMessage(routeSnapshot) or nil
    local status = valid and "Valid" or "Invalid"
    local text = label .. " " .. status .. (message ~= nil and ":" or "")
    local imgui = draw.imgui
    local invalidColor = decorations.invalidColor()
    decorations.drawColoredText(imgui, valid and decorations.validColor() or invalidColor, text)

    if message ~= nil then
        imgui.SameLine()
        imgui.SetCursorPosX(ROUTE_MESSAGE_COLUMN_X)
        decorations.drawColoredText(imgui, invalidColor, message)
    end
end

return routeStatus
