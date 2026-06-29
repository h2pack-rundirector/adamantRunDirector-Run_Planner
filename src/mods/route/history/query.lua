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

local function roomsSinceDepth(entry, previousRunDepthCache)
    local current = entry and entry.runDepthCache or nil
    if current == nil or previousRunDepthCache == nil then
        return nil
    end
    return current - previousRunDepthCache
end

local function axisDistance(entry, event, axis)
    local current = axisValue(entry, axis)
    local previous = axisValue(event, axis)
    if current == nil or previous == nil then
        return nil
    end
    return current - previous
end

local function eventInAxisWindow(event, entry, axis, count)
    local current = axisValue(entry, axis)
    local previous = axisValue(event, axis)
    if current == nil or previous == nil then
        return false
    end
    local window = math.max(0, math.floor(tonumber(count) or 0) - 1)
    return previous <= current and previous >= current - window
end

local function anyEventInWindow(history, entry, requirement, defaultAxis)
    local axis = requirement and requirement.axis or defaultAxis
    local count = requirement and requirement.count or nil
    for _, event in ipairs(routeHistory.entries(history)) do
        if eventInAxisWindow(event, entry, axis, count)
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

function query.runDepthCache(entry)
    return entry and entry.runDepthCache or nil
end

function query.biomeDepthCache(entry)
    return entry and entry.biomeDepthCache or nil
end

function query.enteredBiomes(entry)
    return entry and entry.routeBiomeIndex or nil
end

function query.runEncounterDepth(entry)
    return entry and entry.runEncounterDepth or nil
end

function query.biomeEncounterDepth(entry)
    return entry and entry.biomeEncounterDepth or nil
end

function query.requiredMinRoomsSinceRunDepth(entry, previousRunDepthCache, count)
    local rooms = roomsSinceDepth(entry, previousRunDepthCache)
    return rooms ~= nil and rooms >= count
end

function query.requiredMinRoomsSinceEvent(history, entry, requirement)
    local event = routeHistory.lastEvent(history, requirement and requirement.eventKey)
    if event == nil then
        return true, nil
    end
    local distance = axisDistance(entry, event, requirement.axis or "runDepthCache")
    if distance == nil then
        return false, event
    end
    return distance == 0 or distance >= requirement.count, event
end

function query.sumPrevRooms(history, entry, requirement)
    return anyEventInWindow(history, entry, requirement, "roomHistory")
end

function query.requiredMinExits(row, count)
    local rowExitCount = exitCount(row)
    return rowExitCount ~= nil and rowExitCount >= count
end

return query
