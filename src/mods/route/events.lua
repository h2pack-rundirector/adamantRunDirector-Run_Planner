local routeEvents = {}

local function copyPositionFields(target, source)
    target.biomeKey = source and source.biomeKey or nil
    target.rowIndex = source and source.rowIndex or nil
    target.routeOrdinal = source and source.routeOrdinal or nil
    target.roomHistoryOrdinal = source and source.roomHistoryOrdinal or nil
    target.runDepthCache = source and source.runDepthCache or nil
    target.runEncounterDepth = source and source.runEncounterDepth or nil
    target.biomeDepthCache = source and source.biomeDepthCache or nil
    target.biomeEncounterDepth = source and source.biomeEncounterDepth or nil
end

local function matchesSpec(event, spec)
    if spec == nil then
        return true
    end
    if spec.kind ~= nil and event.kind ~= spec.kind then
        return false
    end
    if spec.eventKey ~= nil and event.eventKey ~= spec.eventKey then
        return false
    end
    if spec.groupKey ~= nil and event.groupKey ~= spec.groupKey then
        return false
    end
    return true
end

function routeEvents.create(fields)
    local event = {}
    copyPositionFields(event, fields.position or fields)
    for key, value in pairs(fields) do
        if key ~= "position" then
            event[key] = value
        end
    end
    return event
end

function routeEvents.createAt(position, fields)
    local event = {}
    copyPositionFields(event, position)
    for key, value in pairs(fields or {}) do
        event[key] = value
    end
    return event
end

function routeEvents.matchesSpec(event, spec)
    return matchesSpec(event, spec)
end

return routeEvents
