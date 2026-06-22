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

local function copyPendingEntries(source)
    local copy = {}
    for index, entry in ipairs(source or EMPTY_LIST) do
        copy[index] = {
            ctx = entry.ctx,
            event = entry.event,
        }
    end
    return copy
end

local function copyRowGroupState(state)
    if state == nil then
        return nil
    end
    return {
        key = state.key,
        group = state.group,
        seenRewardTypes = copyMap(state.seenRewardTypes),
        seenBoonSources = copyMap(state.seenBoonSources),
    }
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
        activeRewardRowGroup = nil,
        pendingOffers = {},
        pendingEntries = {},
        stagedPendingOffers = {},
        stagedPendingEntries = {},
        previousRows = {},
    }
end

function rewardContext.snapshot(context)
    return {
        routeCounters = copyMap(context and context.routeCounters),
        biomeCounters = copyNestedMap(context and context.biomeCounters),
        godLootSeen = copyMap(context and context.godLootSeen),
        lastRewardRoomHistoryOrdinal = copyMap(context and context.lastRewardRoomHistoryOrdinal),
        activeRewardRowGroup = copyRowGroupState(context and context.activeRewardRowGroup),
        pendingOffers = copyMap(context and context.pendingOffers),
        pendingEntries = copyPendingEntries(context and context.pendingEntries),
        stagedPendingOffers = copyMap(context and context.stagedPendingOffers),
        stagedPendingEntries = copyPendingEntries(context and context.stagedPendingEntries),
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

function rewardContext.hasSeenGodLoot(context, lootName)
    return lootName ~= nil and lootName ~= "" and context.godLootSeen[lootName] == true
end

function rewardContext.previousRow(context, biomeKey)
    return context.previousRows[biomeKey]
end

function rewardContext.hasPendingOffer(context, rewardType)
    return context.pendingOffers[rewardType] == true
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

function rewardContext.activeRewardRowGroupKey(context)
    return context.activeRewardRowGroup and context.activeRewardRowGroup.key or nil
end

function rewardContext.beginRewardRowGroup(context, group)
    if group == nil or group.key == nil then
        return nil
    end

    local state = context.activeRewardRowGroup
    if state ~= nil and state.key == group.key then
        return state
    end

    state = {
        key = group.key,
        group = group,
        seenRewardTypes = {},
        seenBoonSources = {},
        pendingEntries = {},
        afterEntries = {},
    }
    context.activeRewardRowGroup = state
    return state
end

function rewardContext.activeRewardRowGroupPendingEntries(context)
    local state = context.activeRewardRowGroup
    return state and state.pendingEntries or EMPTY_LIST
end

function rewardContext.activeRewardRowGroupAfterEntries(context)
    local state = context.activeRewardRowGroup
    return state and state.afterEntries or EMPTY_LIST
end

function rewardContext.clearRewardRowGroup(context)
    context.activeRewardRowGroup = nil
end

function rewardContext.rewardRowGroupHasRewardType(context, groupKey, rewardType)
    local state = context.activeRewardRowGroup
    return state ~= nil and state.key == groupKey and state.seenRewardTypes[rewardType] ~= nil
end

function rewardContext.rewardRowGroupHasBoonSource(context, groupKey, boonSource)
    local state = context.activeRewardRowGroup
    return state ~= nil and state.key == groupKey and state.seenBoonSources[boonSource] ~= nil
end

function rewardContext.storeRewardRowGroupEvent(context, event)
    local group = event and event.item and event.item.rewardRowGroup or nil
    if group == nil or group.key == nil then
        return
    end

    local state = rewardContext.beginRewardRowGroup(context, group)
    if event.rewardType ~= nil and event.rewardType ~= "" then
        state.seenRewardTypes[event.rewardType] = true
    end
    if event.rewardType == "Boon" and event.boonSource ~= nil and event.boonSource ~= "" then
        state.seenBoonSources[event.boonSource] = true
    end
end

function rewardContext.stageRewardRowGroupEvent(context, rowContext, event)
    local state = context.activeRewardRowGroup
    if state == nil then
        return
    end
    state.pendingEntries[#state.pendingEntries + 1] = {
        ctx = rowContext,
        event = event,
    }
end

function rewardContext.stageAfterRewardRowGroupEvent(context, rowContext, event)
    local state = context.activeRewardRowGroup
    if state == nil then
        return
    end
    state.afterEntries[#state.afterEntries + 1] = {
        ctx = rowContext,
        event = event,
    }
end

function rewardContext.stageAfterRewardRowGroupItem(context, rowContext, row, item)
    local state = context.activeRewardRowGroup
    if state == nil then
        return
    end
    state.afterEntries[#state.afterEntries + 1] = {
        ctx = rowContext,
        row = row,
        item = item,
    }
end

function rewardContext.hasPendingEntries(context)
    return context.pendingEntries[1] ~= nil
end

function rewardContext.stagePendingEvent(context, rowContext, event)
    context.stagedPendingEntries[#context.stagedPendingEntries + 1] = {
        ctx = rowContext,
        event = event,
    }
    context.stagedPendingOffers[event.rewardType] = true
end

function rewardContext.clearPending(context)
    clearMap(context.pendingOffers)
    clearMap(context.stagedPendingOffers)
    for index = #context.pendingEntries, 1, -1 do
        context.pendingEntries[index] = nil
    end
    for index = #context.stagedPendingEntries, 1, -1 do
        context.stagedPendingEntries[index] = nil
    end
end

function rewardContext.promotePending(context, apply)
    for _, entry in ipairs(context.pendingEntries) do
        apply(entry.ctx, entry.event)
    end
    clearMap(context.pendingOffers)
    for index = #context.pendingEntries, 1, -1 do
        context.pendingEntries[index] = nil
    end
end

function rewardContext.activateStagedPending(context)
    clearMap(context.pendingOffers)
    for index = #context.pendingEntries, 1, -1 do
        context.pendingEntries[index] = nil
    end
    for rewardType in pairs(context.stagedPendingOffers) do
        context.pendingOffers[rewardType] = true
    end
    for index, entry in ipairs(context.stagedPendingEntries) do
        context.pendingEntries[index] = entry
        context.stagedPendingEntries[index] = nil
    end
    clearMap(context.stagedPendingOffers)
end

function rewardContext.storePreviousRow(context, rowContext, row)
    context.previousRows[rowContext.biomeKey] = row
end

function rewardContext.clearPreviousRow(context, rowContext)
    context.previousRows[rowContext.biomeKey] = nil
end

return rewardContext
