local deps = ... or {}
local rewardItems = deps.rewardItems
local semantics = deps.semantics
local defaultRewardLegality = deps.rewardLegality
local routeTimeline = deps.timeline
local routeValueStates = deps.valueStates

local rewards = {}
local EMPTY_LIST = {}
local GOD_LOOT_SOURCE_SCRATCH = {}
local NO_VALUE_STATES = false
local INVALID_VALUE_STATE = routeValueStates and routeValueStates.INVALID or 2

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
            stopBeforeBiomeIndex = nil,
            stopBeforeRouteOrdinal = nil,
        }
        context.rewardLegalityByRoute[routeKey] = state
    end
    return state
end

local function newRewardLegalityResult()
    return {
        invalidRows = {},
        byBiomeRow = {},
        candidateRows = {},
        valueStatesByBiomeRow = {},
    }
end

local function defaultRouteControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

local function routeBoundaryReached(rowContext, opts)
    if opts.stopBeforeBiomeIndex ~= nil and rowContext.routeBiomeIndex >= opts.stopBeforeBiomeIndex then
        return true
    end
    if opts.stopBeforeRouteOrdinal ~= nil and rowContext.routeOrdinal >= opts.stopBeforeRouteOrdinal then
        return true
    end
    return false
end

local function rewardRowContext(rowContext, routeControlName)
    local biomeKey = rowContext.biomeKey
    return {
        biomeKey = biomeKey,
        routeBiomeIndex = rowContext.routeBiomeIndex,
        controlName = routeControlName(biomeKey),
        routeOrdinal = rowContext.routeOrdinal,
        roomHistoryOrdinal = rowContext.roomHistoryOrdinal,
        runDepthCache = rowContext.runDepthCache,
        runEncounterDepth = rowContext.runEncounterDepth,
        runEncounterDepthMin = rowContext.runEncounterDepthMin,
        runEncounterDepthMax = rowContext.runEncounterDepthMax,
        biomeDepthCache = rowContext.biomeDepthCache,
        biomeEncounterDepth = rowContext.biomeEncounterDepth,
        biomeEncounterDepthMin = rowContext.biomeEncounterDepthMin,
        biomeEncounterDepthMax = rowContext.biomeEncounterDepthMax,
    }
end

local function itemForAddress(row, rewardAddress)
    rewardAddress = rewardAddress or "row"
    for _, item in ipairs(row and row.rewardItems or EMPTY_LIST) do
        if item.address == rewardAddress then
            return item
        end
    end
    return nil
end

local function candidateRowsForBiome(result, biomeKey)
    local byBiome = result.candidateRows[biomeKey]
    if byBiome == nil then
        byBiome = {}
        result.candidateRows[biomeKey] = byBiome
    end
    return byBiome
end

local function valueStatesForBiome(result, biomeKey)
    local byBiome = result.valueStatesByBiomeRow[biomeKey]
    if byBiome == nil then
        byBiome = {}
        result.valueStatesByBiomeRow[biomeKey] = byBiome
    end
    return byBiome
end

local function valueStatesForRow(result, biomeKey, rowIndex)
    local byRow = valueStatesForBiome(result, biomeKey)
    local rowStates = byRow[rowIndex]
    if rowStates == nil then
        rowStates = {}
        byRow[rowIndex] = rowStates
    end
    return rowStates
end

local function valueStatesForAddress(result, biomeKey, rowIndex, rewardAddress)
    local rowStates = valueStatesForRow(result, biomeKey, rowIndex)
    rewardAddress = rewardAddress or "row"
    local addressStates = rowStates[rewardAddress]
    if addressStates == nil then
        addressStates = {}
        rowStates[rewardAddress] = addressStates
    end
    return addressStates
end

local function cachedControlValueStates(result, biomeKey, rowIndex, rewardAddress, controlAlias)
    local rowStates = result.valueStatesByBiomeRow[biomeKey]
    local addressStates = rowStates and rowStates[rowIndex] and rowStates[rowIndex][rewardAddress or "row"] or nil
    if addressStates == nil then
        return nil
    end
    return addressStates[controlAlias]
end

local function storeControlValueStates(result, biomeKey, rowIndex, rewardAddress, controlAlias, states)
    valueStatesForAddress(result, biomeKey, rowIndex, rewardAddress)[controlAlias] = states or NO_VALUE_STATES
end

local function storeCandidateRow(result, rewardLegalityEngine, rewardCtx, ctx, row)
    if row == nil or row.valid == false or rewardLegalityEngine.snapshotContext == nil then
        return
    end
    candidateRowsForBiome(result, ctx.biomeKey)[row.rowIndex] = {
        rewardCtx = rewardLegalityEngine.snapshotContext(rewardCtx),
        ctx = ctx,
        row = row,
    }
end

local function directCandidateRewardType(control, value)
    if value == nil or value == "" or control == nil then
        return nil
    end
    if control.kind == "rewardType" or control.kind == "shopOption" then
        return value
    end
    return nil
end

local function candidateItem(row, rewardAddress, control)
    if control == nil then
        return nil
    end

    local item = itemForAddress(row, rewardAddress)
    if item ~= nil then
        return item
    end
    if rewardAddress ~= "row" then
        return nil
    end
    return itemForAddress(row, "row")
end

local function candidateEvent(row, item, control, value, rewardAddress)
    local rewardType = directCandidateRewardType(control, value)
    if rewardType == nil or item == nil then
        return nil
    end
    return {
        row = row,
        item = item,
        rewardType = rewardType,
        address = rewardAddress or item.address,
        rowLabel = item.rowLabel,
    }
end

local function buildCandidateValueStates(rewardLegalityEngine, candidateRow, rewardAddress, control)
    if rewardLegalityEngine == nil or rewardLegalityEngine.candidateInvalid == nil or candidateRow == nil then
        return nil
    end

    local item = candidateItem(candidateRow.row, rewardAddress, control)
    if item == nil then
        return nil
    end

    local states = nil
    for _, value in ipairs(control and control.values or EMPTY_LIST) do
        local event = candidateEvent(candidateRow.row, item, control, value, rewardAddress)
        if event ~= nil
            and rewardLegalityEngine.candidateInvalid(candidateRow.rewardCtx, candidateRow.ctx, event) ~= nil
        then
            states = states or {}
            states[value] = INVALID_VALUE_STATE
        end
    end
    return states
end

local function evaluateRouteLegality(context, routeKey, opts)
    opts = opts or {}
    local rewardLegalityEngine = opts.rewardLegality
    local route = context.routes.lookup and context.routes.lookup[routeKey] or nil
    local result = rewardLegalityEngine ~= nil and rewardLegalityEngine.emptyResult() or newRewardLegalityResult()
    if route == nil or rewardLegalityEngine == nil or routeTimeline == nil then
        return result
    end

    local rewardCtx = rewardLegalityEngine.beginRoute()
    local routeControlName = opts.routeControlName or defaultRouteControlName
    local scratch = {}
    local stopped = false
    routeTimeline.walkRoute(route, {
        biomeLookup = context.biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return context:controlSnapshot(route.key, biomeKey)
        end,
        onRow = function(rowContext)
            if stopped then
                return
            end
            if routeBoundaryReached(rowContext, opts) then
                stopped = true
                return
            end

            local ctx = rewardRowContext(rowContext, routeControlName)
            storeCandidateRow(result, rewardLegalityEngine, rewardCtx, ctx, rowContext.row)

            local invalid = rewardLegalityEngine.evaluateRow(
                context,
                result,
                rewardCtx,
                ctx,
                rowContext.row,
                scratch
            )
            if opts.stopAfterFirstInvalid and invalid ~= nil then
                stopped = true
            end
        end,
    })
    return result
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
    local routeControlName = opts.routeControlName or defaultRouteControlName

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

    function rewardState.legality(context, routeKey, rewardOpts)
        local state = routeRewardLegalityState(context, routeKey)
        rewardOpts = rewardOpts or {}
        local stopBeforeBiomeIndex = rewardOpts.stopBeforeBiomeIndex
        local stopBeforeRouteOrdinal = rewardOpts.stopBeforeRouteOrdinal
        if state.dirty
            or state.result == nil
            or state.stopBeforeBiomeIndex ~= stopBeforeBiomeIndex
            or state.stopBeforeRouteOrdinal ~= stopBeforeRouteOrdinal
        then
            if context:isLayerConfigured(routeKey, "rewards") and rewardLegalityEngine ~= nil then
                local previousRewardLegalityBuilding = context.rewardLegalityBuilding
                context.rewardLegalityBuilding = true
                state.result = evaluateRouteLegality(context, routeKey, {
                    rewardLegality = rewardLegalityEngine,
                    routeControlName = routeControlName,
                    stopAfterFirstInvalid = true,
                    stopBeforeBiomeIndex = stopBeforeBiomeIndex,
                    stopBeforeRouteOrdinal = stopBeforeRouteOrdinal,
                })
                context.rewardLegalityBuilding = previousRewardLegalityBuilding
            else
                state.result = newRewardLegalityResult()
            end
            state.stopBeforeBiomeIndex = stopBeforeBiomeIndex
            state.stopBeforeRouteOrdinal = stopBeforeRouteOrdinal
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

    function rewardState.valueStates(
        context,
        routeKey,
        biomeKey,
        rowIndex,
        rewardAddress,
        controlAlias,
        control,
        _fields,
        _rewardContext
    )
        if context.snapshotBuilding or context.rewardLegalityBuilding then
            return nil
        end
        if routeKey == nil or biomeKey == nil or rowIndex == nil or controlAlias == nil then
            return nil
        end

        local result = rewardState.legality(context, routeKey)
        local cached = cachedControlValueStates(result, biomeKey, rowIndex, rewardAddress, controlAlias)
        if cached ~= nil then
            if cached == NO_VALUE_STATES then
                return nil
            end
            return cached
        end

        local candidateRow = result.candidateRows[biomeKey] and result.candidateRows[biomeKey][rowIndex] or nil
        local states = buildCandidateValueStates(rewardLegalityEngine, candidateRow, rewardAddress, control)
        storeControlValueStates(result, biomeKey, rowIndex, rewardAddress, controlAlias, states)
        return states
    end

    return rewardState
end

return rewards
