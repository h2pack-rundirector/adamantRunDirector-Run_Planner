local rewardContext = {}
local EMPTY_LIST = {}

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function copyMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function copyNestedMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = copyMap(value)
    end
    return copy
end

local function biomeCounters(context, biomeKey)
    local counters = context.biomeCounters[biomeKey]
    if counters == nil then
        counters = {}
        context.biomeCounters[biomeKey] = counters
    end
    return counters
end

local function countersForScope(context, scope, biomeKey)
    if scope == "biome" then
        return biomeCounters(context, biomeKey)
    end
    return context.routeCounters
end

local function storeGodLootValue(context, lootName)
    if lootName ~= nil and lootName ~= "" then
        context.godLootSeen[lootName] = true
    end
end

function rewardContext.create()
    return {
        routeCounters = {},
        biomeCounters = {},
        godLootSeen = {},
        lastRewardRoomHistoryOrdinal = {},
        previousShopRewards = {},
        previousRows = {},
    }
end

function rewardContext.snapshot(context)
    return {
        routeCounters = copyMap(context and context.routeCounters),
        biomeCounters = copyNestedMap(context and context.biomeCounters),
        godLootSeen = copyMap(context and context.godLootSeen),
        lastRewardRoomHistoryOrdinal = copyMap(context and context.lastRewardRoomHistoryOrdinal),
        previousShopRewards = copyMap(context and context.previousShopRewards),
        previousRows = copyMap(context and context.previousRows),
    }
end

function rewardContext.counterValue(context, counterKey, scope, biomeKey)
    return countersForScope(context, scope, biomeKey)[counterKey] or 0
end

function rewardContext.incrementCounter(context, counterKey, scope, biomeKey)
    local counters = countersForScope(context, scope, biomeKey)
    counters[counterKey] = (counters[counterKey] or 0) + 1
end

function rewardContext.applyCount(context, count, rowContext)
    rewardContext.incrementCounter(context, count.key, count.scope, rowContext.biomeKey)
end

function rewardContext.applyCounts(context, counts, rowContext)
    for _, count in ipairs(counts or EMPTY_LIST) do
        rewardContext.applyCount(context, count, rowContext)
    end
end

function rewardContext.seenGodLootCount(context, requirement)
    local count = 0
    for _, lootName in ipairs(requirement.countedLootNames or EMPTY_LIST) do
        if context.godLootSeen[lootName] then
            count = count + 1
        end
    end
    return count
end

function rewardContext.previousRow(context, biomeKey)
    return context.previousRows[biomeKey]
end

function rewardContext.hasPreviousShopReward(context, rewardType)
    return context.previousShopRewards[rewardType] == true
end

function rewardContext.lastRewardRoomHistoryOrdinal(context, rewardType)
    return context.lastRewardRoomHistoryOrdinal[rewardType]
end

function rewardContext.storeEventGodLoot(context, event)
    if event == nil then
        return
    end

    if event.rewardType == "Boon" then
        storeGodLootValue(context, event.boonSource)
    elseif event.rewardType == "Devotion" then
        storeGodLootValue(context, event.devotionSourceA)
        storeGodLootValue(context, event.devotionSourceB)
    else
        storeGodLootValue(context, event.boonSource)
    end
end

function rewardContext.storeRewardOccurrence(context, rowContext, event)
    if event.rewardType ~= nil and rowContext.roomHistoryOrdinal ~= nil then
        context.lastRewardRoomHistoryOrdinal[event.rewardType] = rowContext.roomHistoryOrdinal
    end
end

function rewardContext.storePreviousShopRewards(context, events)
    clearMap(context.previousShopRewards)
    for _, event in ipairs(events or EMPTY_LIST) do
        if event.item ~= nil and event.item.rewardKind == "shop" then
            context.previousShopRewards[event.rewardType] = true
        end
    end
end

function rewardContext.clearPreviousShopRewards(context)
    clearMap(context.previousShopRewards)
end

function rewardContext.storePreviousRow(context, rowContext, row)
    context.previousRows[rowContext.biomeKey] = row
end

function rewardContext.clearPreviousRow(context, rowContext)
    context.previousRows[rowContext.biomeKey] = nil
end

return rewardContext
