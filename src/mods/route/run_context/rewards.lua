local deps = ... or {}
local rewardItems = deps.rewardItems
local semantics = deps.semantics
local defaultRewardLegality = deps.rewardLegality

local rewards = {}
local EMPTY_LIST = {}
local GOD_LOOT_SOURCE_SCRATCH = {}

local function addGodLootSelection(selections, countedLookup, lootName)
    if lootName ~= nil and lootName ~= "" and countedLookup[lootName] and not selections[lootName] then
        selections[lootName] = true
        return 1
    end
    return 0
end

local function selectionCount(selections)
    local count = 0
    for _ in pairs(selections) do
        count = count + 1
    end
    return count
end

local function collectRewardGodLoot(item, countedLookup, selections, sourceScratch)
    local count = 0
    for _, source in ipairs(semantics.godLootSources(item, sourceScratch or GOD_LOOT_SOURCE_SCRATCH)) do
        count = count + addGodLootSelection(selections, countedLookup, source)
    end
    return count
end

local function collectRowGodLoot(row, countedLookup, selections, itemScratch, sourceScratch)
    local count = 0
    for _, item in ipairs(rewardItems.collect(row, itemScratch)) do
        count = count + collectRewardGodLoot(item, countedLookup, selections, sourceScratch)
    end
    return count
end

local function routeRewardLegalityState(context, routeKey)
    local state = context.rewardLegalityByRoute[routeKey]
    if state == nil then
        state = {
            dirty = true,
            result = nil,
        }
        context.rewardLegalityByRoute[routeKey] = state
    end
    return state
end

local function newRewardLegalityResult()
    return {
        invalidRows = {},
        byBiomeRow = {},
    }
end

function rewards.collectRewardGodLoot(item, countedLookup, selections, sourceScratch)
    return collectRewardGodLoot(item, countedLookup, selections, sourceScratch)
end

function rewards.collectRowGodLoot(row, countedLookup, selections, itemScratch, sourceScratch)
    return collectRowGodLoot(row, countedLookup, selections, itemScratch, sourceScratch)
end

function rewards.create(opts)
    opts = opts or {}
    local rewardLegalityEngine = opts.rewardLegality or defaultRewardLegality
    local routeControlName = opts.routeControlName

    local rewardState = {}

    function rewardState.collectPriorGodLoot(context, routeKey, biomeKey, countedLookup, selections, stopAtCount)
        if countedLookup == nil or selections == nil then
            return selections
        end

        local info = context:routeInfo(routeKey, biomeKey)
        if info == nil then
            return selections
        end

        local count = selectionCount(selections)
        context.rewardGodLootItemScratch = context.rewardGodLootItemScratch or {}
        context.rewardGodLootSourceScratch = context.rewardGodLootSourceScratch or {}
        for index = 1, info.index - 1 do
            local snapshot = context:controlSnapshot(info.route.key, info.route.biomes[index])
            for _, row in ipairs(snapshot and snapshot.rows or EMPTY_LIST) do
                count = count + collectRowGodLoot(
                    row,
                    countedLookup,
                    selections,
                    context.rewardGodLootItemScratch,
                    context.rewardGodLootSourceScratch
                )
                if stopAtCount ~= nil and count >= stopAtCount then
                    return selections
                end
            end
        end
        return selections
    end

    function rewardState.legality(context, routeKey)
        local state = routeRewardLegalityState(context, routeKey)
        if state.dirty or state.result == nil then
            if context:isLayerConfigured(routeKey, "rewards") and rewardLegalityEngine ~= nil then
                local previousRewardLegalityBuilding = context.rewardLegalityBuilding
                context.rewardLegalityBuilding = true
                state.result = rewardLegalityEngine.evaluate(context, routeKey, {
                    routeControlName = routeControlName,
                    snapshotForBiome = function(resolvedRouteKey, biomeKey)
                        return context:controlSnapshot(resolvedRouteKey, biomeKey)
                    end,
                })
                context.rewardLegalityBuilding = previousRewardLegalityBuilding
            else
                state.result = newRewardLegalityResult()
            end
            state.dirty = false
        end
        return state.result
    end

    function rewardState.rowValidation(context, routeKey, biomeKey, rowIndex)
        if context.snapshotBuilding or context.rewardLegalityBuilding then
            return nil
        end

        local result = rewardState.legality(context, routeKey)
        local byRow = result.byBiomeRow[biomeKey]
        return byRow and byRow[rowIndex] or nil
    end

    return rewardState
end

return rewards
