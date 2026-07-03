local deps = ... or {}

local query = {}

local routeEvents = deps.events
local routeHistory = deps.history

local function numeric(value)
    if value == nil then
        return nil
    end
    return tonumber(value)
end

local function nonEmpty(value)
    if value == nil or value == "" then
        return nil
    end
    return value
end

local function effectiveRoomHistoryOrdinal(event)
    return event and (event.acquiredAfterRoomHistoryOrdinal or event.roomHistoryOrdinal) or nil
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

local function strictlyBefore(entry, candidate)
    local currentRoomHistory = entry and entry.roomHistoryOrdinal or nil
    local candidateRoomHistory = effectiveRoomHistoryOrdinal(candidate)
    if currentRoomHistory ~= nil and candidateRoomHistory ~= nil then
        return candidateRoomHistory < currentRoomHistory
    end

    local currentBiomeIndex = entry and entry.routeBiomeIndex or nil
    local candidateBiomeIndex = candidate and candidate.routeBiomeIndex or nil
    if currentBiomeIndex ~= nil and candidateBiomeIndex ~= nil and currentBiomeIndex ~= candidateBiomeIndex then
        return candidateBiomeIndex < currentBiomeIndex
    end

    local currentOrdinal = entry and entry.routeOrdinal or nil
    local candidateOrdinal = candidate and candidate.routeOrdinal or nil
    if currentOrdinal ~= nil and candidateOrdinal ~= nil then
        return candidateOrdinal < currentOrdinal
    end

    return false
end

local function latestByRoomHistory(currentLatest, candidate)
    if currentLatest == nil then
        return candidate
    end
    return (effectiveRoomHistoryOrdinal(candidate) or 0) > (effectiveRoomHistoryOrdinal(currentLatest) or 0)
        and candidate
        or currentLatest
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

local function topologyExits(topology)
    if topology == nil then
        return nil
    end
    if topology.exits ~= nil then
        return #topology.exits
    end
    local count = 0
    local picked = topology.picked or topology.selected
    if picked ~= nil then
        count = count + 1
    end
    local otherDoors = topology.otherDoors or topology.siblings
    if otherDoors ~= nil then
        count = count + #otherDoors
    elseif topology.sibling ~= nil then
        count = count + 1
    end
    return count > 0 and count or nil
end

local function generatedExitCount(entry)
    if entry == nil or entry.valid == false then
        return nil
    end

    local topology = entry.topology or entry.roomTopology
    local value = numeric(topology and topology.exitCount)
    if value ~= nil then
        return value
    end

    value = numeric(entry.exitCount)
    if value ~= nil then
        return value
    end

    value = numeric(entry.option and entry.option.exitCount)
    if value ~= nil then
        return value
    end

    return topologyExits(topology)
end

local function referenceRoomEntry(entry)
    if entry == nil then
        return nil
    end
    return entry.kind == "loot" and entry.parentEntry or entry
end

local function previousRoomEntry(history, entry)
    local reference = referenceRoomEntry(entry)
    local latest = nil
    for _, candidate in ipairs(routeHistory.entries(history)) do
        if candidate.kind == "room" and strictlyBefore(reference, candidate) then
            latest = latestByRoomHistory(latest, candidate)
        end
    end
    return latest
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
    local previous = query.lastEventBefore(history, entry, requirement)
    if previous == nil then
        return true, nil
    end
    local distance = axisDistance(entry, previous, requirement.axis or "runDepthCache")
    if distance == nil then
        return false, previous
    end
    return distance == 0 or distance >= requirement.count, previous
end

function query.sumPrevRooms(history, entry, requirement)
    return anyEventInWindow(history, entry, requirement, "roomHistory")
end

function query.lastEventBefore(history, entry, spec)
    local latest = nil
    for _, event in ipairs(routeHistory.entries(history)) do
        if strictlyBefore(entry, event) and routeEvents.matchesSpec(event, spec) then
            latest = latestByRoomHistory(latest, event)
        end
    end
    return latest
end

function query.lootTypeHistoryCount(history, entry, lootType)
    local count = 0
    for _, loot in ipairs(routeHistory.lootEntries(history, lootType)) do
        if strictlyBefore(entry, loot) then
            count = count + 1
        end
    end
    return count
end

function query.hasLootType(history, entry, lootType)
    return query.lootTypeHistoryCount(history, entry, lootType) > 0
end

function query.lastLootType(history, entry, lootType)
    local latest = nil
    for _, loot in ipairs(routeHistory.lootEntries(history, lootType)) do
        if strictlyBefore(entry, loot) then
            latest = latestByRoomHistory(latest, loot)
        end
    end
    return latest
end

function query.biomeUseRecordCount(history, entry, lootType)
    local biomeKey = entry and entry.biomeKey or nil
    local count = 0
    for _, loot in ipairs(routeHistory.biomeLootEntries(history, biomeKey, lootType)) do
        if strictlyBefore(entry, loot) then
            count = count + 1
        end
    end
    return count
end

function query.hasBiomeUseRecord(history, entry, lootType)
    return query.biomeUseRecordCount(history, entry, lootType) > 0
end

function query.hasLootSource(history, entry, sourceValue)
    sourceValue = nonEmpty(sourceValue)
    if sourceValue == nil then
        return false
    end
    for _, loot in ipairs(routeHistory.sourceEntries(history, sourceValue)) do
        if strictlyBefore(entry, loot) then
            return true
        end
    end
    return false
end

function query.distinctLootSourceCount(history, entry, sourceValues)
    local count = 0
    for _, sourceValue in ipairs(sourceValues or {}) do
        if query.hasLootSource(history, entry, sourceValue) then
            count = count + 1
        end
    end
    return count
end

function query.requiredNotInStore(history, entry, lootType)
    for _, loot in ipairs(routeHistory.pendingLootEntries(history, lootType)) do
        local untilRoomHistory = loot.pendingUntilRoomHistoryOrdinal
        local entryRoomHistory = entry and entry.roomHistoryOrdinal or nil
        if strictlyBefore(entry, loot)
            and untilRoomHistory ~= nil
            and entryRoomHistory ~= nil
            and entryRoomHistory <= untilRoomHistory
        then
            return false, loot
        end
    end
    return true, nil
end

function query.previousGeneratedExitCount(history, entry)
    local count = query.previousGeneratedExitDetails(history, entry)
    return count
end

function query.previousGeneratedExitDetails(history, entry)
    local previous = previousRoomEntry(history, entry)
    return generatedExitCount(previous), previous
end

function query.requiredMinExits(history, entry, count)
    local rowExitCount = query.previousGeneratedExitCount(history, entry)
    return rowExitCount ~= nil and rowExitCount >= count
end

return query
