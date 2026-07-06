local guard = import("mods/declarations/guard.lua")

local query = {}

local function expectHistory(history)
    guard.expectTable(history, "history.query.history")
    guard.expectArray(history.events, "history.query.history.events")
    guard.expectArray(history.lootHistory, "history.query.history.lootHistory")
end

local function countSet(values)
    guard.expectNonEmptyArray(values, "history.query.countSet")
    local set = {}
    for _, value in ipairs(values) do
        set[guard.expectString(value, "history.query.countSet[]")] = true
    end
    return set
end

local function orderedStringSet(values, context)
    guard.expectNonEmptyArray(values, context)
    local ordered = {}
    local set = {}
    for _, value in ipairs(values) do
        local source = guard.expectString(value, context .. "[]")
        if not set[source] then
            set[source] = true
            ordered[#ordered + 1] = source
        end
    end
    return ordered, set
end

local function before(event, eventIndex)
    return guard.expectNumber(event.eventIndex, "history.query.event.eventIndex") < eventIndex
end

local function eventAt(history, eventIndex)
    expectHistory(history)
    local index = guard.expectNumber(eventIndex, "history.query.eventIndex")
    local event = history.events[index]
    if event == nil then
        guard.fail("history.query.eventIndex", "event index does not exist")
    end
    return event
end

local function selectorMatches(event, selector)
    guard.expectTable(selector, "history.query.eventSelector")
    local kind = guard.expectString(selector.kind, "history.query.eventSelector.kind")
    if event.kind ~= kind then
        return false
    end

    if selector.rewardType ~= nil then
        local rewardType = guard.expectString(selector.rewardType, "history.query.eventSelector.rewardType")
        if event.rewardType ~= rewardType then
            return false
        end
    end

    return true
end

local function roomAddressMatches(left, right)
    guard.expectTable(left, "history.query.leftAddress")
    guard.expectTable(right, "history.query.rightAddress")
    return left.routeKey == right.routeKey
        and left.biomeIndex == right.biomeIndex
        and left.roomIndex == right.roomIndex
end

local function axisValue(event, axis)
    if axis == "RoomHistoryOrdinal" then
        return event.roomHistoryOrdinal or event.roomHistoryOrdinalAfter
    elseif axis == "BiomeDepthCache" then
        return event.biomeDepthCache or event.biomeDepthCacheAfter
    elseif axis == "RunEncounterDepth" or axis == "EncounterDepth" then
        return event.runEncounterDepth or event.runEncounterDepthAfter
    elseif axis == "BiomeEncounterDepth" then
        return event.biomeEncounterDepth or event.biomeEncounterDepthAfter
    end

    guard.fail("history.query.axis", "unsupported event-distance axis '" .. tostring(axis) .. "'")
end

local function addPayloadSources(out, event)
    local payload = event.payload
    if type(payload) ~= "table" then
        return
    end

    if type(payload.source) == "string" then
        out[payload.source] = true
    end

    if type(payload.sources) == "table" then
        for _, source in ipairs(payload.sources) do
            if type(source) == "string" then
                out[source] = true
            end
        end
    end
end

local function acquiredLootSourceSetBefore(history, eventIndex)
    expectHistory(history)
    local beforeEventIndex = guard.expectNumber(eventIndex, "history.query.eventIndex")
    local seen = {}

    for _, event in ipairs(history.lootHistory) do
        if before(event, beforeEventIndex) then
            addPayloadSources(seen, event)
        end
    end

    return seen
end

function query.countAcquiredLootTypesBefore(history, lootTypes, eventIndex)
    expectHistory(history)
    local lootTypeSet = countSet(lootTypes)
    local beforeEventIndex = guard.expectNumber(eventIndex, "history.query.eventIndex")
    local count = 0

    for _, event in ipairs(history.lootHistory) do
        local acquiredLootType = event.acquiredLootType or event.rewardType
        if before(event, beforeEventIndex) and lootTypeSet[acquiredLootType] then
            count = count + 1
        end
    end

    return count
end

function query.countClearedBiomesBefore(history, eventIndex)
    guard.expectTable(history, "history.query.history")
    guard.expectArray(history.events, "history.query.history.events")
    local beforeEventIndex = guard.expectNumber(eventIndex, "history.query.eventIndex")
    local count = guard.expectOptionalNumber(history.initialClearedBiomes, "history.query.history.initialClearedBiomes") or 0

    for _, event in ipairs(history.events) do
        if event.kind == "biome.complete" and before(event, beforeEventIndex) then
            count = count + 1
        end
    end

    return count
end

function query.countPendingStoreOffersBefore(history, rewardTypes, eventIndex)
    guard.expectTable(history, "history.query.history")
    local pendingStoreOfferHistory = history.pendingStoreOfferHistory or {}
    guard.expectArray(pendingStoreOfferHistory, "history.query.history.pendingStoreOfferHistory")
    local rewardTypeSet = countSet(rewardTypes)
    local beforeEventIndex = guard.expectNumber(eventIndex, "history.query.eventIndex")
    local count = 0

    for _, event in ipairs(pendingStoreOfferHistory) do
        local rewardType = event.rewardType or event.name
        if before(event, beforeEventIndex) and rewardTypeSet[rewardType] then
            count = count + 1
        end
    end

    return count
end

function query.countDistinctAcquiredLootSourcesBefore(history, sourceValues, eventIndex)
    local _, sourceSet = orderedStringSet(sourceValues, "history.query.sourceValues")
    local seen = acquiredLootSourceSetBefore(history, eventIndex)
    local count = 0

    for source, _ in pairs(seen) do
        if sourceSet[source] then
            count = count + 1
        end
    end

    return count
end

function query.missingAcquiredLootSourcesBefore(history, sourceValues, eventIndex)
    local ordered = orderedStringSet(sourceValues, "history.query.sourceValues")
    local seen = acquiredLootSourceSetBefore(history, eventIndex)
    local missing = {}

    for _, source in ipairs(ordered) do
        if not seen[source] then
            missing[#missing + 1] = source
        end
    end

    return missing
end

function query.countersForEvent(history, eventIndex)
    local event = eventAt(history, eventIndex)
    return {
        runEncounterDepth = guard.expectNumber(event.runEncounterDepth, "history.query.event.runEncounterDepth"),
        biomeEncounterDepth = guard.expectNumber(event.biomeEncounterDepth, "history.query.event.biomeEncounterDepth"),
        biomeDepthCache = guard.expectNumber(event.biomeDepthCache, "history.query.event.biomeDepthCache"),
        roomHistoryOrdinal = guard.expectNumber(event.roomHistoryOrdinal, "history.query.event.roomHistoryOrdinal"),
    }
end

function query.countGeneratedDoorsAtEvent(history, eventIndex)
    guard.expectTable(history, "history.query.history")
    guard.expectArray(history.generatedDoorHistory, "history.query.history.generatedDoorHistory")
    local event = eventAt(history, eventIndex)
    local sourceAddress = guard.expectTable(event.sourceAddress, "history.query.event.sourceAddress")
    local count = 0

    for _, door in ipairs(history.generatedDoorHistory) do
        if roomAddressMatches(sourceAddress, door.sourceAddress) then
            count = count + 1
        end
    end

    return count
end

function query.roomsSinceMatchingEvent(history, selector, axis, eventIndex)
    local current = eventAt(history, eventIndex)
    local currentAxis = axisValue(current, guard.expectString(axis, "history.query.axis"))
    local lastMatchingEvent

    for _, event in ipairs(history.events) do
        if before(event, eventIndex) and selectorMatches(event, selector) then
            lastMatchingEvent = event
        end
    end

    if lastMatchingEvent == nil then
        return nil
    end

    return currentAxis - guard.expectNumber(axisValue(lastMatchingEvent, axis), "history.query.lastMatchingAxis")
end

function query.requirementQueries(history, eventIndex)
    guard.expectNumber(eventIndex, "history.query.eventIndex")
    return {
        countLootTypeHistory = function(lootTypes)
            return query.countAcquiredLootTypesBefore(history, lootTypes, eventIndex)
        end,
        countClearedBiomes = function()
            return query.countClearedBiomesBefore(history, eventIndex)
        end,
        countPendingStoreOffers = function(rewardTypes)
            return query.countPendingStoreOffersBefore(history, rewardTypes, eventIndex)
        end,
        countDistinctLootSources = function(sourceValues)
            return query.countDistinctAcquiredLootSourcesBefore(history, sourceValues, eventIndex)
        end,
        missingLootSources = function(sourceValues)
            return query.missingAcquiredLootSourcesBefore(history, sourceValues, eventIndex)
        end,
        countGeneratedDoors = function()
            return query.countGeneratedDoorsAtEvent(history, eventIndex)
        end,
        roomsSinceEvent = function(selector, axis)
            return query.roomsSinceMatchingEvent(history, selector, axis, eventIndex)
        end,
    }
end

return query
