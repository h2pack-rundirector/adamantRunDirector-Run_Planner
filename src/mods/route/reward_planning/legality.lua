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
local constraintEventScratch = {}

local function newResult()
    return {
        invalidRows = {},
        byBiomeRow = {},
        decisionsByBiomeRowAddress = {},
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

local function decisionsForBiome(result, biomeKey)
    local byBiome = result.decisionsByBiomeRowAddress[biomeKey]
    if byBiome == nil then
        byBiome = {}
        result.decisionsByBiomeRowAddress[biomeKey] = byBiome
    end
    return byBiome
end

local function decisionsForRow(result, biomeKey, rowIndex)
    local byBiome = decisionsForBiome(result, biomeKey)
    local byRow = byBiome[rowIndex]
    if byRow == nil then
        byRow = {}
        byBiome[rowIndex] = byRow
    end
    return byRow
end

local function decisionForItem(result, rewardCtx, ctx, row, item)
    local address = item and item.address or nil
    if row == nil or address == nil then
        return nil
    end

    local byRow = decisionsForRow(result, ctx.biomeKey, row.rowIndex)
    local decision = byRow[address]
    if decision == nil then
        decision = {
            biomeKey = ctx.biomeKey,
            rowIndex = row.rowIndex,
            address = address,
            row = row,
            item = item,
            ctx = ctx,
            rewardCtxBeforeDecision = rewardContext.snapshot(rewardCtx),
            selectedEvents = {},
            selectedInvalid = nil,
        }
        byRow[address] = decision
    end
    return decision
end

local function decisionForEvent(result, rewardCtx, ctx, event)
    return decisionForItem(result, rewardCtx, ctx, event and event.row or nil, event and event.item or nil)
end

local function recordSelectedEvent(result, rewardCtx, ctx, event)
    local decision = decisionForEvent(result, rewardCtx, ctx, event)
    if decision ~= nil then
        decision.selectedEvents[#decision.selectedEvents + 1] = event
    end
    return decision
end

local function recordSelectedBatch(result, rewardCtx, ctx, batch)
    local decision = decisionForItem(result, rewardCtx, ctx, batch and batch.row or nil, batch and batch.item or nil)
    for index = batch.firstEventIndex, batch.lastEventIndex do
        decision = recordSelectedEvent(result, rewardCtx, ctx, batch.events[index]) or decision
    end
    return decision
end

local function storeSelectedInvalid(decision, invalid)
    if decision ~= nil and decision.selectedInvalid == nil then
        decision.selectedInvalid = invalid
    end
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

local function constraintAppliesToEvent(constraint, event)
    local sourceIndices = constraint and constraint.sourceIndices or nil
    if sourceIndices == nil or sourceIndices[1] == nil then
        return true
    end
    for _, sourceIndex in ipairs(sourceIndices) do
        if sourceIndex == event.sourceIndex then
            return true
        end
    end
    return false
end

local function priorConstraintEvent(constraint, event, other)
    if other == nil or other.address == event.address or not constraintAppliesToEvent(constraint, other) then
        return false
    end
    if event.sourceIndex ~= nil and other.sourceIndex ~= nil then
        return other.sourceIndex < event.sourceIndex
    end
    return false
end

local function rewardConstraintEvents(event)
    semantics.eventsForItem(event.item, event.row, constraintEventScratch)
    return constraintEventScratch
end

local function duplicateRewardTypeConstraintInvalid(constraint, event)
    if event.rewardType == nil or event.rewardType == "" or not constraintAppliesToEvent(constraint, event) then
        return nil
    end
    local allow = constraint.allow or EMPTY_LIST
    if allow[event.rewardType] then
        return nil
    end
    for _, other in ipairs(rewardConstraintEvents(event)) do
        if priorConstraintEvent(constraint, event, other) and other.rewardType == event.rewardType then
            return {
                code = constraint.code or "duplicate_reward_type",
                message = constraint.message or (rewardLabel(event.rewardType) .. " is already planned in this reward group"),
            }
        end
    end
    return nil
end

local function duplicateBoonSourceConstraintInvalid(constraint, event)
    if not constraintAppliesToEvent(constraint, event) then
        return nil
    end
    if event.rewardType == "Devotion"
        and event.devotionSourceA ~= nil
        and event.devotionSourceA ~= ""
        and event.devotionSourceA == event.devotionSourceB
    then
        return {
            code = constraint.code or "duplicate_boon_source",
            message = constraint.message or "Boon sources must be different",
        }
    end

    if event.boonSource == nil or event.boonSource == "" then
        return nil
    end
    for _, other in ipairs(rewardConstraintEvents(event)) do
        if priorConstraintEvent(constraint, event, other)
            and other.boonSource ~= nil
            and other.boonSource ~= ""
            and other.boonSource == event.boonSource
        then
            return {
                code = constraint.code or "duplicate_boon_source",
                message = constraint.message or "Boon sources must be different",
            }
        end
    end
    return nil
end

local function rewardConstraintInvalid(event)
    for _, constraint in ipairs(event and event.item and event.item.rewardConstraints or EMPTY_LIST) do
        if constraint.kind == "uniqueRewardTypes" then
            local invalid = duplicateRewardTypeConstraintInvalid(constraint, event)
            if invalid ~= nil then
                return invalid
            end
        elseif constraint.kind == "uniqueBoonSource" then
            local invalid = duplicateBoonSourceConstraintInvalid(constraint, event)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
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
    local localInvalid = rewardConstraintInvalid(event)
    if localInvalid ~= nil then
        return localInvalid
    end

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
    local decision = recordSelectedBatch(result, rewardCtx, ctx, batch)
    for index = batch.firstEventIndex, batch.lastEventIndex do
        local event = batch.events[index]
        local invalid = eventInvalid(rewardCtx, ctx, event)
        if invalid ~= nil then
            local selectedInvalid = addInvalid(context, result, seenInvalids, ctx, event, invalid.code, invalid.message)
            storeSelectedInvalid(decision, selectedInvalid)
            return selectedInvalid
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
    if batch.firstEventIndex > batch.lastEventIndex then
        rewardContext.stageAfterRewardRowGroupItem(rewardCtx, ctx, batch.row, batch.item)
        return
    end
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
    if entry.event == nil then
        decisionForItem(result, rewardCtx, entry.ctx, entry.row, entry.item)
        return nil
    end

    local decision = recordSelectedEvent(result, rewardCtx, entry.ctx, entry.event)
    local invalid = eventInvalid(rewardCtx, entry.ctx, entry.event)
    if invalid == nil then
        return nil
    end
    local selectedInvalid = addInvalid(context, result, seenInvalids, entry.ctx, entry.event, invalid.code, invalid.message)
    storeSelectedInvalid(decision, selectedInvalid)
    return selectedInvalid
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
        if entry.event ~= nil then
            applyEventEffects(rewardCtx, entry.ctx, entry.event)
        end
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
