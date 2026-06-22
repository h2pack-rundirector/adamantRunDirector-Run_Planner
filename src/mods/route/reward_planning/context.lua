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

local function copyList(source)
    local copy = {}
    for index, value in ipairs(source or EMPTY_LIST) do
        copy[index] = value
    end
    return copy
end

local function copyListMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = copyList(value)
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

local function copyNestedListMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = copyListMap(value)
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
        rewardTypeOccurrences = copyMap(state.rewardTypeOccurrences),
        boonSourceOccurrences = copyMap(state.boonSourceOccurrences),
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

local function biomeCounterOccurrences(context, biomeKey)
    local occurrences = context.biomeCounterOccurrences[biomeKey]
    if occurrences == nil then
        occurrences = {}
        context.biomeCounterOccurrences[biomeKey] = occurrences
    end
    return occurrences
end

local function countersForScope(context, scope, biomeKey)
    if scope == "biome" then
        return biomeCounters(context, biomeKey)
    end
    return context.routeCounters
end

local function counterOccurrencesForScope(context, scope, biomeKey)
    if scope == "biome" then
        return biomeCounterOccurrences(context, biomeKey)
    end
    return context.routeCounterOccurrences
end

local function newOccurrence(rowContext, event)
    return {
        ctx = rowContext,
        event = event,
    }
end

local function appendCounterOccurrence(context, counterKey, scope, biomeKey, rowContext, event)
    if event == nil then
        return
    end
    local occurrencesByCounter = counterOccurrencesForScope(context, scope, biomeKey)
    local occurrences = occurrencesByCounter[counterKey]
    if occurrences == nil then
        occurrences = {}
        occurrencesByCounter[counterKey] = occurrences
    end
    occurrences[#occurrences + 1] = newOccurrence(rowContext, event)
end

local function selectedOccurrence(occurrences, select)
    if occurrences == nil then
        return nil
    end
    if select == "first" then
        return occurrences[1]
    end
    return occurrences[#occurrences]
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
        routeCounterOccurrences = {},
        biomeCounterOccurrences = {},
        godLootSeen = {},
        lastRewardRoomHistoryOrdinal = {},
        lastRewardOccurrences = {},
        activeRewardRowGroup = nil,
        pendingOfferOccurrences = {},
        pendingEntries = {},
        stagedPendingOfferOccurrences = {},
        stagedPendingEntries = {},
        previousRows = {},
    }
end

function rewardContext.snapshot(context)
    return {
        routeCounters = copyMap(context and context.routeCounters),
        biomeCounters = copyNestedMap(context and context.biomeCounters),
        routeCounterOccurrences = copyListMap(context and context.routeCounterOccurrences),
        biomeCounterOccurrences = copyNestedListMap(context and context.biomeCounterOccurrences),
        godLootSeen = copyMap(context and context.godLootSeen),
        lastRewardRoomHistoryOrdinal = copyMap(context and context.lastRewardRoomHistoryOrdinal),
        lastRewardOccurrences = copyMap(context and context.lastRewardOccurrences),
        activeRewardRowGroup = copyRowGroupState(context and context.activeRewardRowGroup),
        pendingOfferOccurrences = copyListMap(context and context.pendingOfferOccurrences),
        pendingEntries = copyPendingEntries(context and context.pendingEntries),
        stagedPendingOfferOccurrences = copyListMap(context and context.stagedPendingOfferOccurrences),
        stagedPendingEntries = copyPendingEntries(context and context.stagedPendingEntries),
        previousRows = copyMap(context and context.previousRows),
    }
end

function rewardContext.counterValue(context, counterKey, scope, biomeKey)
    return countersForScope(context, scope, biomeKey)[counterKey] or 0
end

function rewardContext.incrementCounter(context, counterKey, scope, biomeKey, rowContext, event)
    local counters = countersForScope(context, scope, biomeKey)
    counters[counterKey] = (counters[counterKey] or 0) + 1
    appendCounterOccurrence(context, counterKey, scope, biomeKey, rowContext, event)
end

function rewardContext.applyCount(context, count, rowContext, event)
    rewardContext.incrementCounter(context, count.key, count.scope, rowContext.biomeKey, rowContext, event)
end

function rewardContext.applyCounts(context, counts, rowContext, event)
    for _, count in ipairs(counts or EMPTY_LIST) do
        rewardContext.applyCount(context, count, rowContext, event)
    end
end

function rewardContext.counterProducerOccurrence(context, counterKey, scope, biomeKey, select)
    local occurrences = counterOccurrencesForScope(context, scope, biomeKey)[counterKey]
    return selectedOccurrence(occurrences, select)
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
    return context.pendingOfferOccurrences[rewardType] ~= nil
end

function rewardContext.pendingOfferOccurrence(context, rewardType, select)
    return selectedOccurrence(context.pendingOfferOccurrences[rewardType], select)
end

function rewardContext.lastRewardRoomHistoryOrdinal(context, rewardType)
    return context.lastRewardRoomHistoryOrdinal[rewardType]
end

function rewardContext.lastRewardOccurrence(context, rewardType)
    return context.lastRewardOccurrences[rewardType]
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
        context.lastRewardOccurrences[event.rewardType] = newOccurrence(rowContext, event)
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
        rewardTypeOccurrences = {},
        boonSourceOccurrences = {},
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
    return state ~= nil and state.key == groupKey and state.rewardTypeOccurrences[rewardType] ~= nil
end

function rewardContext.rewardRowGroupRewardTypeOccurrence(context, groupKey, rewardType)
    local state = context.activeRewardRowGroup
    if state == nil or state.key ~= groupKey then
        return nil
    end
    return state.rewardTypeOccurrences[rewardType]
end

function rewardContext.rewardRowGroupHasBoonSource(context, groupKey, boonSource)
    local state = context.activeRewardRowGroup
    return state ~= nil and state.key == groupKey and state.boonSourceOccurrences[boonSource] ~= nil
end

function rewardContext.rewardRowGroupBoonSourceOccurrence(context, groupKey, boonSource)
    local state = context.activeRewardRowGroup
    if state == nil or state.key ~= groupKey then
        return nil
    end
    return state.boonSourceOccurrences[boonSource]
end

function rewardContext.storeRewardRowGroupOccurrence(context, rowContext, event)
    local group = event and event.item and event.item.rewardRowGroup or nil
    if group == nil or group.key == nil then
        return
    end

    local state = rewardContext.beginRewardRowGroup(context, group)
    if event.rewardType ~= nil and event.rewardType ~= "" then
        state.rewardTypeOccurrences[event.rewardType] = newOccurrence(rowContext, event)
    end
    if event.rewardType == "Boon" and event.boonSource ~= nil and event.boonSource ~= "" then
        state.boonSourceOccurrences[event.boonSource] = newOccurrence(rowContext, event)
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
    local occurrence = newOccurrence(rowContext, event)
    context.stagedPendingEntries[#context.stagedPendingEntries + 1] = occurrence
    local occurrences = context.stagedPendingOfferOccurrences[event.rewardType]
    if occurrences == nil then
        occurrences = {}
        context.stagedPendingOfferOccurrences[event.rewardType] = occurrences
    end
    occurrences[#occurrences + 1] = occurrence
end

function rewardContext.clearPending(context)
    clearMap(context.pendingOfferOccurrences)
    clearMap(context.stagedPendingOfferOccurrences)
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
    clearMap(context.pendingOfferOccurrences)
    for index = #context.pendingEntries, 1, -1 do
        context.pendingEntries[index] = nil
    end
end

function rewardContext.activateStagedPending(context)
    clearMap(context.pendingOfferOccurrences)
    for index = #context.pendingEntries, 1, -1 do
        context.pendingEntries[index] = nil
    end
    for rewardType, occurrences in pairs(context.stagedPendingOfferOccurrences) do
        context.pendingOfferOccurrences[rewardType] = occurrences
    end
    for index, entry in ipairs(context.stagedPendingEntries) do
        context.pendingEntries[index] = entry
        context.stagedPendingEntries[index] = nil
    end
    clearMap(context.stagedPendingOfferOccurrences)
end

function rewardContext.storePreviousRow(context, rowContext, row)
    context.previousRows[rowContext.biomeKey] = row
end

function rewardContext.clearPreviousRow(context, rowContext)
    context.previousRows[rowContext.biomeKey] = nil
end

return rewardContext
