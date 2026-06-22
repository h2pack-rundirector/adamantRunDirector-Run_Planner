local deps = ... or {}
local conditions = deps.conditions or {}
local rowRewardItems = deps.rewardItems
local semantics = deps.semantics
local invalidLocations = deps.invalidLocations
local rewardContext = deps.context

local rewardLegality = {}
local EMPTY_LIST = {}

local function buildLookup(values)
    local lookup = {}
    for _, value in ipairs(values or EMPTY_LIST) do
        lookup[value] = true
    end
    return lookup
end

local function collectRewardBatches(row, batches, items, events)
    semantics.batchesForRow(row, rowRewardItems, batches, items, events)
end

local function compileRules(rules)
    local byTarget = {}
    for _, rule in ipairs(rules or EMPTY_LIST) do
        if rule.appliesToRewardKinds ~= nil and rule.appliesToRewardKindLookup == nil then
            rule.appliesToRewardKindLookup = buildLookup(rule.appliesToRewardKinds)
        end
        for _, target in ipairs(rule.targets or EMPTY_LIST) do
            local targetRules = byTarget[target]
            if targetRules == nil then
                targetRules = {}
                byTarget[target] = targetRules
            end
            targetRules[#targetRules + 1] = rule
        end
    end
    return byTarget
end

local compiledRulesByTarget = compileRules(conditions)

local function newResult()
    return {
        invalidRows = {},
        byBiomeRow = {},
        candidateRows = {},
        valueStatesByBiomeRow = {},
    }
end

local function invalidRowKey(biomeKey, rowIndex, code, address)
    return tostring(biomeKey or "")
        .. ":"
        .. tostring(rowIndex or "")
        .. ":"
        .. tostring(code or "")
        .. ":"
        .. tostring(address or "")
end

local function candidateRowsForBiome(result, biomeKey)
    local byBiome = result.candidateRows[biomeKey]
    if byBiome == nil then
        byBiome = {}
        result.candidateRows[biomeKey] = byBiome
    end
    return byBiome
end

local function candidateRowFor(result, rewardCtx, ctx, row)
    if row == nil or row.valid == false then
        return nil
    end

    local byBiome = candidateRowsForBiome(result, ctx.biomeKey)
    local candidateRow = byBiome[row.rowIndex]
    if candidateRow == nil then
        candidateRow = {
            rewardCtx = rewardContext.snapshot(rewardCtx),
            ctx = ctx,
            row = row,
        }
        byBiome[row.rowIndex] = candidateRow
    end
    return candidateRow
end

local function storeCandidateEventContext(result, rewardCtx, ctx, event)
    local row = event and event.row or nil
    local address = event and event.address or nil
    if row == nil or address == nil then
        return
    end

    local candidateRow = candidateRowFor(result, rewardCtx, ctx, row)
    if candidateRow == nil then
        return
    end
    local byAddress = candidateRow.rewardCtxByAddress
    if byAddress == nil then
        byAddress = {}
        candidateRow.rewardCtxByAddress = byAddress
    end
    byAddress[address] = rewardContext.snapshot(rewardCtx)
end

local function addInvalid(context, result, seenInvalids, ctx, event, code, message)
    local row = event and event.row or nil
    if row == nil then
        return
    end

    local key = invalidRowKey(ctx.biomeKey, row.rowIndex, code, event.address)
    if seenInvalids[key] then
        return
    end
    seenInvalids[key] = true

    local invalid = {
        valid = false,
        biomeKey = ctx.biomeKey,
        controlName = ctx.controlName,
        rowIndex = row.rowIndex,
        routeOrdinal = row.routeOrdinal,
        address = event.address,
        rewardType = event.rewardType,
        locationLabel = invalidLocations.rewardEvent(context, ctx, event),
        code = code,
        message = message,
    }
    result.invalidRows[#result.invalidRows + 1] = invalid

    local byRow = result.byBiomeRow[ctx.biomeKey]
    if byRow == nil then
        byRow = {}
        result.byBiomeRow[ctx.biomeKey] = byRow
    end
    if byRow[row.rowIndex] == nil then
        byRow[row.rowIndex] = invalid
    end
    return invalid
end

local function requirementSkipped(requirement, ctx)
    for _, biomeKey in ipairs(requirement.exceptBiomes or EMPTY_LIST) do
        if biomeKey == ctx.biomeKey then
            return true
        end
    end
    return false
end

local function previousRoomExitCountInvalid(requirement, rewardCtx, ctx)
    local previousRow = rewardContext.previousRow(rewardCtx, ctx.biomeKey)
    if previousRow == nil
        or previousRow.valid == false
        or previousRow.roleKey == "Vanilla"
        or previousRow.option == nil
    then
        return requirement
    end

    local exitCount = tonumber(previousRow.option.exitCount)
    if exitCount == nil or exitCount < requirement.minCount then
        return requirement
    end
    return nil
end

local function minRoomHistorySpacingInvalid(requirement, rewardCtx, ctx, event)
    local rewardType = requirement.event or event.rewardType
    local previousOrdinal = rewardContext.lastRewardRoomHistoryOrdinal(rewardCtx, rewardType)
    if previousOrdinal == nil then
        return nil
    end
    local currentOrdinal = ctx.roomHistoryOrdinal
    if currentOrdinal == nil or currentOrdinal - previousOrdinal < requirement.min then
        return requirement
    end
    return nil
end

local function minRunEncounterDepthInvalid(requirement, ctx)
    local runEncounterDepthMin = ctx.runEncounterDepthMin or ctx.runEncounterDepth
    if runEncounterDepthMin == nil or runEncounterDepthMin < requirement.min then
        return requirement
    end
    return nil
end

local function devotionSourcesInPriorGodLootInvalid(requirement, rewardCtx, event)
    if event.rewardType ~= "Devotion" then
        return nil
    end
    if not rewardContext.hasSeenGodLoot(rewardCtx, event.devotionSourceA)
        or not rewardContext.hasSeenGodLoot(rewardCtx, event.devotionSourceB)
    then
        return requirement
    end
    return nil
end

local function inRange(value, range)
    if range == nil or value == nil then
        return true
    end
    if range.exact ~= nil and value ~= range.exact then
        return false
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    if range.minExclusive ~= nil and value <= range.minExclusive then
        return false
    end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then
        return false
    end
    return true
end

local function phaseMatches(phase, count, ctx)
    if phase.priorCount ~= nil and count ~= phase.priorCount then
        return false
    end
    return inRange(ctx.routeBiomeIndex, phase.routeBiomeIndex)
end

local function requirementInvalid(requirement, rewardCtx, ctx, event)
    if requirementSkipped(requirement, ctx) then
        return nil
    end

    if requirement.kind == "pendingOfferExclusion" then
        for _, rewardType in ipairs(requirement.rewards or EMPTY_LIST) do
            if rewardContext.hasPendingOffer(rewardCtx, rewardType) then
                return requirement
            end
        end
        return nil
    end

    if requirement.kind == "priorDistinctGodLoot" then
        if rewardContext.seenGodLootCount(rewardCtx, requirement) < requirement.minDistinct then
            return requirement
        end
        return nil
    elseif requirement.kind == "previousRoomExitCount" then
        return previousRoomExitCountInvalid(requirement, rewardCtx, ctx)
    elseif requirement.kind == "minRoomHistorySpacing" then
        return minRoomHistorySpacingInvalid(requirement, rewardCtx, ctx, event)
    elseif requirement.kind == "minRunEncounterDepth" then
        return minRunEncounterDepthInvalid(requirement, ctx)
    elseif requirement.kind == "devotionSourcesInPriorGodLoot" then
        return devotionSourcesInPriorGodLootInvalid(requirement, rewardCtx, event)
    end

    local count = rewardContext.counterValue(rewardCtx, requirement.counter, requirement.scope, ctx.biomeKey)
    if requirement.kind == "maxCount" then
        if count >= requirement.max then
            return requirement
        end
    elseif requirement.kind == "minPriorCount" then
        if count < requirement.min then
            return requirement
        end
    elseif requirement.kind == "phase" then
        for _, phase in ipairs(requirement.phases or EMPTY_LIST) do
            if phaseMatches(phase, count, ctx) then
                return nil
            end
        end
        return requirement
    end
    return nil
end

local function rewardLabel(value)
    if value == "Boon" then
        return "Boon"
    end
    return tostring(value)
end

local function rewardRowGroupConstraints(group)
    return group and group.constraints or EMPTY_LIST
end

local function duplicateRewardTypesConstraint(group)
    return rewardRowGroupConstraints(group).uniqueRewardTypes
end

local function duplicateBoonSourceConstraint(group)
    return rewardRowGroupConstraints(group).uniqueBoonSource
end

local function rewardRowGroupInvalid(rewardCtx, event)
    local group = event and event.item and event.item.rewardRowGroup or nil
    if group == nil or group.key == nil or event.rewardType == nil or event.rewardType == "" then
        return nil
    end

    local uniqueRewardTypes = duplicateRewardTypesConstraint(group)
    if uniqueRewardTypes ~= nil then
        local allow = uniqueRewardTypes.allow or EMPTY_LIST
        if not allow[event.rewardType]
            and rewardContext.rewardRowGroupHasRewardType(rewardCtx, group.key, event.rewardType)
        then
            return {
                code = "duplicate_reward_type",
                message = rewardLabel(event.rewardType) .. " is already planned in this reward group",
            }
        end
    end

    if duplicateBoonSourceConstraint(group)
        and event.rewardType == "Boon"
        and event.boonSource ~= nil
        and event.boonSource ~= ""
        and rewardContext.rewardRowGroupHasBoonSource(rewardCtx, group.key, event.boonSource)
    then
        return {
            code = "duplicate_boon_source",
            message = "Boon source is already planned in this reward group",
        }
    end
    return nil
end

local function ruleApplies(rule, event)
    local lookup = rule.appliesToRewardKindLookup
    if lookup == nil then
        return true
    end
    return lookup[event.item and event.item.rewardKind or ""] == true
end

local function ruleInvalid(rule, rewardCtx, ctx, event)
    for _, requirement in ipairs(rule.requirements or EMPTY_LIST) do
        local invalid = requirementInvalid(requirement, rewardCtx, ctx, event)
        if invalid ~= nil then
            return invalid
        end
    end
    return nil
end

local function eventInvalid(rewardCtx, ctx, event)
    local groupInvalid = rewardRowGroupInvalid(rewardCtx, event)
    if groupInvalid ~= nil then
        return groupInvalid
    end

    local rules = compiledRulesByTarget[event.rewardType]
    if rules == nil then
        return nil
    end

    for _, rule in ipairs(rules) do
        if ruleApplies(rule, event) then
            local invalid = ruleInvalid(rule, rewardCtx, ctx, event)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

local function applyEventEffects(rewardCtx, ctx, event)
    local rules = compiledRulesByTarget[event.rewardType]
    if rules ~= nil then
        for _, rule in ipairs(rules) do
            if ruleApplies(rule, event) then
                rewardContext.applyCounts(rewardCtx, rule.countsAs, ctx)
            end
        end
    end
    rewardContext.storeEventGodLoot(rewardCtx, event)
    rewardContext.storeRewardOccurrence(rewardCtx, ctx, event)
end

local function validateBatch(context, result, seenInvalids, rewardCtx, ctx, batch)
    for index = batch.firstEventIndex, batch.lastEventIndex do
        local event = batch.events[index]
        local invalid = eventInvalid(rewardCtx, ctx, event)
        if invalid ~= nil then
            return addInvalid(context, result, seenInvalids, ctx, event, invalid.code, invalid.message)
        end
    end
    return nil
end

local function applyBatchEffects(rewardCtx, ctx, batch)
    for index = batch.firstEventIndex, batch.lastEventIndex do
        applyEventEffects(rewardCtx, ctx, batch.events[index])
    end
end

local function stagePendingBatch(rewardCtx, ctx, batch)
    for index = batch.firstEventIndex, batch.lastEventIndex do
        rewardContext.stagePendingEvent(rewardCtx, ctx, batch.events[index])
    end
end

local function promotePendingEffects(rewardCtx)
    rewardContext.promotePending(rewardCtx, function(ctx, event)
        applyEventEffects(rewardCtx, ctx, event)
    end)
end

local function stageBatchAfterRewardRowGroup(rewardCtx, ctx, batch)
    for index = batch.firstEventIndex, batch.lastEventIndex do
        rewardContext.stageAfterRewardRowGroupEvent(rewardCtx, ctx, batch.events[index])
    end
end

local function applyRewardRowGroupEffects(rewardCtx)
    for _, entry in ipairs(rewardContext.activeRewardRowGroupPendingEntries(rewardCtx)) do
        applyEventEffects(rewardCtx, entry.ctx, entry.event)
    end
end

local function validateAfterRewardRowGroupEntry(context, result, seenInvalids, rewardCtx, entry)
    storeCandidateEventContext(result, rewardCtx, entry.ctx, entry.event)
    local invalid = eventInvalid(rewardCtx, entry.ctx, entry.event)
    if invalid == nil then
        return nil
    end
    return addInvalid(context, result, seenInvalids, entry.ctx, entry.event, invalid.code, invalid.message)
end

local function closeRewardRowGroup(context, result, seenInvalids, rewardCtx)
    if rewardContext.activeRewardRowGroupKey(rewardCtx) == nil then
        return nil
    end

    applyRewardRowGroupEffects(rewardCtx)
    for _, entry in ipairs(rewardContext.activeRewardRowGroupAfterEntries(rewardCtx)) do
        local invalid = validateAfterRewardRowGroupEntry(context, result, seenInvalids, rewardCtx, entry)
        if invalid ~= nil then
            rewardContext.clearRewardRowGroup(rewardCtx)
            return invalid
        end
        applyEventEffects(rewardCtx, entry.ctx, entry.event)
    end
    rewardContext.clearRewardRowGroup(rewardCtx)
    return nil
end

local function rowRewardGroup(row, itemScratch)
    for _, item in ipairs(rowRewardItems.collect(row, itemScratch)) do
        local group = item.rewardRowGroup
        if group ~= nil and group.key ~= nil then
            return group
        end
    end
    return nil
end

local function ensureLegalityScratch(scratch)
    scratch = scratch or {}
    scratch.seenInvalids = scratch.seenInvalids or {}
    scratch.groupItems = scratch.groupItems or {}
    return scratch
end

function rewardLegality.emptyResult()
    return newResult()
end

function rewardLegality.beginRoute()
    return rewardContext.create()
end

function rewardLegality.snapshotContext(rewardCtx)
    return rewardContext.snapshot(rewardCtx)
end

function rewardLegality.candidateInvalid(rewardCtx, ctx, event)
    return eventInvalid(rewardCtx, ctx, event)
end

function rewardLegality.prepareRow(context, result, rewardCtx, _ctx, row, scratch)
    scratch = ensureLegalityScratch(scratch)
    local group = rowRewardGroup(row, scratch.groupItems)
    local activeGroupKey = rewardContext.activeRewardRowGroupKey(rewardCtx)
    local rowGroupKey = group and group.key or nil
    if activeGroupKey ~= nil and activeGroupKey ~= rowGroupKey then
        return closeRewardRowGroup(context, result, scratch.seenInvalids, rewardCtx)
    end
    return nil
end

function rewardLegality.finishRoute(context, result, rewardCtx, scratch)
    scratch = ensureLegalityScratch(scratch)
    return closeRewardRowGroup(context, result, scratch.seenInvalids, rewardCtx)
end

function rewardLegality.evaluateRow(context, result, rewardCtx, ctx, row, scratch)
    if row == nil or row.valid == false then
        rewardContext.clearPending(rewardCtx)
        rewardContext.clearPreviousRow(rewardCtx, ctx)
        return nil
    end
    local promotePendingAfterRow = rewardContext.hasPendingEntries(rewardCtx)

    scratch = ensureLegalityScratch(scratch)
    local batches = scratch.batches or {}
    local events = scratch.events or {}
    local rewardItemScratch = scratch.rewardItems or {}
    scratch.batches = batches
    scratch.events = events
    scratch.rewardItems = rewardItemScratch

    collectRewardBatches(row, batches, rewardItemScratch, events)
    for _, batch in ipairs(batches) do
        local group = batch.item and batch.item.rewardRowGroup or nil
        if group ~= nil and group.key ~= nil then
            rewardContext.beginRewardRowGroup(rewardCtx, group)
        elseif rewardContext.activeRewardRowGroupKey(rewardCtx) ~= nil then
            stageBatchAfterRewardRowGroup(rewardCtx, ctx, batch)
        else
            local invalid = validateBatch(context, result, scratch.seenInvalids, rewardCtx, ctx, batch)
            if invalid ~= nil then
                return invalid
            end
        end
        if group ~= nil and group.key ~= nil then
            local invalid = validateBatch(context, result, scratch.seenInvalids, rewardCtx, ctx, batch)
            if invalid ~= nil then
                return invalid
            end
            for index = batch.firstEventIndex, batch.lastEventIndex do
                rewardContext.storeRewardRowGroupEvent(rewardCtx, batch.events[index])
                rewardContext.stageRewardRowGroupEvent(rewardCtx, ctx, batch.events[index])
            end
        elseif rewardContext.activeRewardRowGroupKey(rewardCtx) == nil then
            if batch.effectTiming == "afterNextRow" then
                stagePendingBatch(rewardCtx, ctx, batch)
            else
                applyBatchEffects(rewardCtx, ctx, batch)
            end
        end
    end
    if promotePendingAfterRow then
        promotePendingEffects(rewardCtx)
    end
    rewardContext.activateStagedPending(rewardCtx)
    rewardContext.storePreviousRow(rewardCtx, ctx, row)
    return nil
end

return rewardLegality
