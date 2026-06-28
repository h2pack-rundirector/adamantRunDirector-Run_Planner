local deps = ... or {}

local query = {}

local VANILLA_ROLE_KEY = "Vanilla"
local routeEvents = deps.events
local routeHistory = deps.history

local function numeric(value)
    if value == nil then
        return nil
    end
    return tonumber(value)
end

local AXIS_FIELDS = {
    runDepthCache = "runDepthCache",
    roomHistory = "roomHistoryOrdinal",
}

local function axisField(axis)
    return AXIS_FIELDS[axis]
end

local function axisValue(object, axis)
    local field = axisField(axis)
    return field and object and object[field] or nil
end

local function roomsSinceDepth(context, previousRunDepthCache)
    local current = context and context.runDepthCache or nil
    if current == nil or previousRunDepthCache == nil then
        return nil
    end
    return current - previousRunDepthCache
end

local function axisDistance(context, event, axis)
    local current = axisValue(context, axis)
    local previous = axisValue(event, axis)
    if current == nil or previous == nil then
        return nil
    end
    return current - previous
end

local function eventInAxisWindow(event, context, axis, count)
    local current = axisValue(context, axis)
    local previous = axisValue(event, axis)
    if current == nil or previous == nil then
        return false
    end
    local window = math.max(0, math.floor(tonumber(count) or 0) - 1)
    return previous <= current and previous >= current - window
end

local function anyEventInWindow(history, context, requirement, defaultAxis)
    local axis = requirement and requirement.axis or defaultAxis
    local count = requirement and requirement.count or nil
    for _, event in ipairs(routeHistory.entries(history)) do
        if eventInAxisWindow(event, context, axis, count)
            and routeEvents.matchesSpec(event, requirement)
        then
            return true, event
        end
    end
    return false, nil
end

local function exitCount(row)
    if row == nil or row.valid == false or row.roleKey == VANILLA_ROLE_KEY then
        return nil
    end

    local topology = row.roomTopology
    local value = numeric(topology and topology.exitCount)
    if value ~= nil then
        return value
    end

    value = numeric(row.exitCount)
    if value ~= nil then
        return value
    end

    return numeric(row.option and row.option.exitCount)
end

function query.runDepthCache(context)
    return context and context.runDepthCache or nil
end

function query.biomeDepthCache(context)
    return context and context.biomeDepthCache or nil
end

function query.enteredBiomes(context)
    return context and context.routeBiomeIndex or nil
end

function query.runEncounterDepth(context)
    return context and context.runEncounterDepth or nil
end

function query.biomeEncounterDepth(context)
    return context and context.biomeEncounterDepth or nil
end

function query.requiredMinRoomsSinceRunDepth(context, previousRunDepthCache, count)
    local rooms = roomsSinceDepth(context, previousRunDepthCache)
    return rooms ~= nil and rooms >= count
end

function query.requiredMinRoomsSinceEvent(history, context, requirement)
    local event = routeHistory.lastEvent(history, requirement and requirement.eventKey)
    if event == nil then
        return true, nil
    end
    local distance = axisDistance(context, event, requirement.axis or "runDepthCache")
    if distance == nil then
        return false, event
    end
    return distance == 0 or distance >= requirement.count, event
end

function query.sumPrevRooms(history, context, requirement)
    return anyEventInWindow(history, context, requirement, "roomHistory")
end

function query.requiredMinExits(row, count)
    local rowExitCount = exitCount(row)
    return rowExitCount ~= nil and rowExitCount >= count
end

return query
