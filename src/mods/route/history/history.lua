local deps = ... or {}

local routeEvents = deps.events
local routeHistory = {}

local EMPTY_LIST = {}

local function appendIndexed(index, key, entry)
    if key == nil or key == "" then
        return
    end
    local entries = index[key]
    if entries == nil then
        entries = {}
        index[key] = entries
    end
    entries[#entries + 1] = entry
end

local function appendNestedIndexed(index, firstKey, secondKey, entry)
    if firstKey == nil or firstKey == "" or secondKey == nil or secondKey == "" then
        return
    end
    local nested = index[firstKey]
    if nested == nil then
        nested = {}
        index[firstKey] = nested
    end
    appendIndexed(nested, secondKey, entry)
end

local function lastValue(values)
    return values and values[#values] or nil
end

local function indexReward(history, entry)
    if entry.kind ~= "reward" then
        return
    end

    local reward = history.reward
    appendIndexed(reward.byRewardType, entry.rewardType, entry)
    appendNestedIndexed(reward.byBiomeRewardType, entry.biomeKey, entry.rewardType, entry)

    if entry.timing == "pendingOffer" then
        appendIndexed(reward.pendingByRewardType, entry.rewardType, entry)
    end

    for _, sourceValue in ipairs(entry.sourceValues or EMPTY_LIST) do
        appendIndexed(reward.bySourceValue, sourceValue, entry)
    end
end

function routeHistory.create()
    return {
        entries = {},
        byKind = {},
        byEventKey = {},
        byGroupKey = {},
        reward = {
            byRewardType = {},
            byBiomeRewardType = {},
            pendingByRewardType = {},
            bySourceValue = {},
        },
    }
end

function routeHistory.append(history, entry)
    if entry == nil then
        return nil
    end
    history.entries[#history.entries + 1] = entry
    appendIndexed(history.byKind, entry.kind, entry)
    appendIndexed(history.byEventKey, entry.eventKey, entry)
    appendIndexed(history.byGroupKey, entry.groupKey, entry)
    indexReward(history, entry)
    return entry
end

function routeHistory.emit(history, fields)
    return routeHistory.append(history, routeEvents.create(fields))
end

function routeHistory.emitAt(history, position, fields)
    return routeHistory.append(history, routeEvents.createAt(position, fields))
end

function routeHistory.entries(history)
    return history and history.entries or EMPTY_LIST
end

function routeHistory.byKind(history, kind)
    return history and history.byKind and history.byKind[kind] or EMPTY_LIST
end

function routeHistory.byEventKey(history, eventKey)
    return history and history.byEventKey and history.byEventKey[eventKey] or EMPTY_LIST
end

function routeHistory.byGroupKey(history, groupKey)
    return history and history.byGroupKey and history.byGroupKey[groupKey] or EMPTY_LIST
end

function routeHistory.lastEvent(history, eventKey)
    return lastValue(routeHistory.byEventKey(history, eventKey))
end

function routeHistory.lastInGroup(history, groupKey)
    return lastValue(routeHistory.byGroupKey(history, groupKey))
end

function routeHistory.rewardEntries(history, rewardType)
    return history and history.reward and history.reward.byRewardType[rewardType] or EMPTY_LIST
end

function routeHistory.biomeRewardEntries(history, biomeKey, rewardType)
    local byBiome = history and history.reward and history.reward.byBiomeRewardType[biomeKey] or nil
    return byBiome and byBiome[rewardType] or EMPTY_LIST
end

function routeHistory.pendingRewardEntries(history, rewardType)
    return history and history.reward and history.reward.pendingByRewardType[rewardType] or EMPTY_LIST
end

function routeHistory.sourceEntries(history, sourceValue)
    return history and history.reward and history.reward.bySourceValue[sourceValue] or EMPTY_LIST
end

function routeHistory.count(history, spec)
    if spec == nil then
        return #(history and history.entries or EMPTY_LIST)
    end
    if spec.kind == "reward" and spec.rewardType ~= nil then
        if spec.biomeKey ~= nil then
            return #routeHistory.biomeRewardEntries(history, spec.biomeKey, spec.rewardType)
        end
        return #routeHistory.rewardEntries(history, spec.rewardType)
    end
    if spec.kind ~= nil then
        return #routeHistory.byKind(history, spec.kind)
    end
    if spec.eventKey ~= nil then
        return #routeHistory.byEventKey(history, spec.eventKey)
    end
    if spec.groupKey ~= nil then
        return #routeHistory.byGroupKey(history, spec.groupKey)
    end
    return #(history and history.entries or EMPTY_LIST)
end

function routeHistory.hasPendingReward(history, rewardType)
    return routeHistory.pendingRewardEntries(history, rewardType)[1] ~= nil
end

return routeHistory
