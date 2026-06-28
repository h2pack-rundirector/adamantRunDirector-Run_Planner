local routeEvents = {}

local EMPTY_LIST = {}

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

local function appendIndexed(index, key, event)
    if key == nil or key == "" then
        return
    end
    local events = index[key]
    if events == nil then
        events = {}
        index[key] = events
    end
    events[#events + 1] = event
end

local function lastValue(values)
    return values and values[#values] or nil
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

function routeEvents.createHistory()
    return {
        events = {},
        byEventKey = {},
        byGroupKey = {},
    }
end

function routeEvents.emit(history, fields)
    return routeEvents.append(history, routeEvents.create(fields))
end

function routeEvents.emitAt(history, position, fields)
    return routeEvents.append(history, routeEvents.createAt(position, fields))
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

function routeEvents.append(history, event)
    if event == nil then
        return nil
    end
    history.events[#history.events + 1] = event
    appendIndexed(history.byEventKey, event.eventKey, event)
    appendIndexed(history.byGroupKey, event.groupKey, event)
    return event
end

function routeEvents.lastEvent(history, eventKey)
    return lastValue(history and history.byEventKey and history.byEventKey[eventKey])
end

function routeEvents.lastInGroup(history, groupKey)
    return lastValue(history and history.byGroupKey and history.byGroupKey[groupKey])
end

function routeEvents.list(history)
    return history and history.events or EMPTY_LIST
end

function routeEvents.matchesSpec(event, spec)
    return matchesSpec(event, spec)
end

return routeEvents
