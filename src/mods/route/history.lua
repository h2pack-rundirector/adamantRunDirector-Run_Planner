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

local function indexLoot(history, entry)
    if entry.kind ~= "loot" then
        return
    end

    local loot = history.loot
    appendIndexed(loot.byLootType, entry.lootType, entry)
    appendNestedIndexed(loot.byBiomeLootType, entry.biomeKey, entry.lootType, entry)

    if entry.timing == "pendingOffer" then
        appendIndexed(loot.pendingByLootType, entry.lootType, entry)
    end

    for _, sourceValue in ipairs(entry.sourceValues or EMPTY_LIST) do
        appendIndexed(loot.bySourceValue, sourceValue, entry)
    end
end

function routeHistory.create()
    return {
        entries = {},
        byKind = {},
        byEventKey = {},
        byGroupKey = {},
        loot = {
            byLootType = {},
            byBiomeLootType = {},
            pendingByLootType = {},
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
    indexLoot(history, entry)
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

function routeHistory.lootEntries(history, lootType)
    return history and history.loot and history.loot.byLootType[lootType] or EMPTY_LIST
end

function routeHistory.biomeLootEntries(history, biomeKey, lootType)
    local byBiome = history and history.loot and history.loot.byBiomeLootType[biomeKey] or nil
    return byBiome and byBiome[lootType] or EMPTY_LIST
end

function routeHistory.pendingLootEntries(history, lootType)
    return history and history.loot and history.loot.pendingByLootType[lootType] or EMPTY_LIST
end

function routeHistory.sourceEntries(history, sourceValue)
    return history and history.loot and history.loot.bySourceValue[sourceValue] or EMPTY_LIST
end

function routeHistory.count(history, spec)
    if spec == nil then
        return #(history and history.entries or EMPTY_LIST)
    end
    if spec.kind == "loot" and spec.lootType ~= nil then
        if spec.biomeKey ~= nil then
            return #routeHistory.biomeLootEntries(history, spec.biomeKey, spec.lootType)
        end
        return #routeHistory.lootEntries(history, spec.lootType)
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

function routeHistory.hasPendingLoot(history, lootType)
    return routeHistory.pendingLootEntries(history, lootType)[1] ~= nil
end

return routeHistory
