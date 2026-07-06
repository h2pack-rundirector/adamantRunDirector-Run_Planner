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

local function before(event, eventIndex)
    return guard.expectNumber(event.eventIndex, "history.query.event.eventIndex") < eventIndex
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
    }
end

return query
