local deps = ... or {}
local conditions = deps.conditions or {}
local rowRewardItems = deps.rewardItems
local semantics = deps.semantics
local rewardContext = deps.context
local markers = deps.markers
local topologyBranches = deps.topologyBranches
local controlRequirements = deps.controlRequirements
local routeQuery = deps.query

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

local function clearList(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function newResult()
    return {
        invalidRows = {},
        byBiomeRow = {},
        decisionsByBiomeRowAddress = {},
        topologyByBiomeRow = {},
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

local function topologiesForBiome(result, biomeKey)
    local byBiome = result.topologyByBiomeRow[biomeKey]
    if byBiome == nil then
        byBiome = {}
        result.topologyByBiomeRow[biomeKey] = byBiome
    end
    return byBiome
end

local function topologyForRow(result, biomeKey, rowIndex)
    local byBiome = result.topologyByBiomeRow[biomeKey]
    return byBiome and byBiome[rowIndex] or nil
end

local function recordRowTopology(result, ctx, row)
    if row ~= nil and row.roomTopology ~= nil then
        topologiesForBiome(result, ctx.biomeKey)[row.rowIndex] = row.roomTopology
    end
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

local function addInvalid(context, result, seenInvalids, ctx, event, invalid)
    local row = event and event.row or nil
    if row == nil then
        return
    end

    local key = invalidRowKey(ctx.biomeKey, row.rowIndex, invalid.code, event.address)
    if seenInvalids[key] then
        return
    end
    seenInvalids[key] = true

    local primaryMarker = markers.primary(context, ctx, event, invalid)
    result.invalidRows[#result.invalidRows + 1] = primaryMarker
    for _, relatedEvent in ipairs(invalid.relatedEvents or EMPTY_LIST) do
        result.invalidRows[#result.invalidRows + 1] = markers.related(context, {
            ctx = ctx,
            event = relatedEvent,
        }, invalid)
    end
    for _, occurrence in ipairs(invalid.relatedOccurrences or EMPTY_LIST) do
        result.invalidRows[#result.invalidRows + 1] = markers.related(context, occurrence, invalid)
    end

    local byRow = result.byBiomeRow[ctx.biomeKey]
    if byRow == nil then
        byRow = {}
        result.byBiomeRow[ctx.biomeKey] = byRow
    end
    if byRow[row.rowIndex] == nil then
        byRow[row.rowIndex] = primaryMarker
    end
    return primaryMarker
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
    if not routeQuery.requiredMinExits(previousRow, requirement.minCount) then
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
    local previousRunDepthCache = previousOrdinal + 1
    if not routeQuery.minRoomsSinceDepth(ctx, previousRunDepthCache, requirement.min) then
        return requirement
    end
    return nil
end

local function minRunEncounterDepthInvalid(requirement, ctx)
    if ctx.runEncounterDepth == nil or ctx.runEncounterDepth < requirement.min then
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

local function relatedOccurrenceForSpec(spec, rewardCtx, ctx, event, requirement)
    if spec.source == "counterProducer" then
        return rewardContext.counterProducerOccurrence(
            rewardCtx,
            requirement.counter,
            requirement.scope,
            ctx.biomeKey,
            spec.select
        )
    elseif spec.source == "pendingOffer" then
        local rewardType = (requirement.rewards or EMPTY_LIST)[1]
        return rewardContext.pendingOfferOccurrence(rewardCtx, rewardType, spec.select)
    elseif spec.source == "lastOccurrence" then
        local rewardType = requirement.event or event.rewardType
        return rewardContext.lastRewardOccurrence(rewardCtx, rewardType)
    end
    return nil
end

local function relatedOccurrencesForRequirement(requirement, rewardCtx, ctx, event)
    local related = nil
    for _, spec in ipairs(requirement.relatedParticipants or EMPTY_LIST) do
        local occurrence = relatedOccurrenceForSpec(spec, rewardCtx, ctx, event, requirement)
        if occurrence ~= nil then
            related = related or {}
            related[#related + 1] = occurrence
        end
    end
    return related
end

local function requirementPayload(requirement, rewardCtx, ctx, event)
    return {
        code = requirement.code,
        message = requirement.message,
        relatedOccurrences = relatedOccurrencesForRequirement(requirement, rewardCtx, ctx, event),
    }
end

local function requirementInvalid(requirement, rewardCtx, ctx, event)
    if requirementSkipped(requirement, ctx) then
        return nil
    end

    if requirement.kind == "pendingOfferExclusion" then
        for _, rewardType in ipairs(requirement.rewards or EMPTY_LIST) do
            if rewardContext.hasPendingOffer(rewardCtx, rewardType) then
                return requirementPayload(requirement, rewardCtx, ctx, event)
            end
        end
        return nil
    end

    if requirement.kind == "priorDistinctGodLoot" then
        if rewardContext.seenGodLootCount(rewardCtx, requirement) < requirement.minDistinct then
            return requirementPayload(requirement, rewardCtx, ctx, event)
        end
        return nil
    elseif requirement.kind == "previousRoomExitCount" then
        if previousRoomExitCountInvalid(requirement, rewardCtx, ctx) ~= nil then
            return requirementPayload(requirement, rewardCtx, ctx, event)
        end
        return nil
    elseif requirement.kind == "minRoomHistorySpacing" then
        if minRoomHistorySpacingInvalid(requirement, rewardCtx, ctx, event) ~= nil then
            return requirementPayload(requirement, rewardCtx, ctx, event)
        end
        return nil
    elseif requirement.kind == "minRunEncounterDepth" then
        if minRunEncounterDepthInvalid(requirement, ctx) ~= nil then
            return requirementPayload(requirement, rewardCtx, ctx, event)
        end
        return nil
    elseif requirement.kind == "devotionSourcesInPriorGodLoot" then
        if devotionSourcesInPriorGodLootInvalid(requirement, rewardCtx, event) ~= nil then
            return requirementPayload(requirement, rewardCtx, ctx, event)
        end
        return nil
    end

    local count = rewardContext.counterValue(rewardCtx, requirement.counter, requirement.scope, ctx.biomeKey)
    if requirement.kind == "maxCount" then
        if count >= requirement.max then
            return requirementPayload(requirement, rewardCtx, ctx, event)
        end
    elseif requirement.kind == "minPriorCount" then
        if count < requirement.min then
            return requirementPayload(requirement, rewardCtx, ctx, event)
        end
    elseif requirement.kind == "phase" then
        for _, phase in ipairs(requirement.phases or EMPTY_LIST) do
            if phaseMatches(phase, count, ctx) then
                return nil
            end
        end
        return requirementPayload(requirement, rewardCtx, ctx, event)
    end
    return nil
end

local function rewardLabel(value)
    if value == "Boon" then
        return "Boon"
    end
    return tostring(value)
end

local function nonEmpty(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function selectionRequirementLabel(requirement)
    return nonEmpty(requirement and requirement.label)
        or (requirement and requirement.kind == "boonSource" and "God" or nil)
        or "Reward"
end

local function selectionRequirementAddress(item, requirement)
    return nonEmpty(requirement and requirement.address)
        or nonEmpty(item and item.address)
        or "row"
end

local function selectionRequirementEvent(row, item, requirement)
    local address = selectionRequirementAddress(item, requirement)
    local tabKey = nonEmpty(requirement and requirement.tabKey) or "rewards"
    return {
        row = row,
        item = item,
        tabKey = tabKey,
        rewardType = "SelectionRequirement",
        address = address,
        addressLabel = item and item.sourceLabel or nil,
        controlTargets = controlRequirements.selectedTargets({
            tabKey = tabKey,
            address = address,
            controlAlias = requirement.controlAlias,
        }),
        valueTargets = EMPTY_LIST,
    }
end

local function selectionRequirementInvalid(row, item)
    for _, requirement in ipairs(item and item.selectionRequirements or EMPTY_LIST) do
        if requirement.controlAlias ~= nil and requirement.controlAlias ~= "" then
            return selectionRequirementEvent(row, item, requirement), {
                code = "selection_required",
                message = selectionRequirementLabel(requirement) .. " needs a concrete selection",
            }
        end
    end
    return nil, nil
end

local function validateSelectionRequirements(context, result, seenInvalids, ctx, row, itemScratch)
    for _, item in ipairs(rowRewardItems.collect(row, itemScratch)) do
        local event, invalid = selectionRequirementInvalid(row, item)
        if invalid ~= nil then
            return addInvalid(context, result, seenInvalids, ctx, event, invalid)
        end
    end
    return nil
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
    clearList(constraintEventScratch)
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
                relatedEvents = { other },
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
                relatedEvents = { other },
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
            local occurrence = rewardContext.rewardRowGroupRewardTypeOccurrence(rewardCtx, group.key, event.rewardType)
            return {
                code = "duplicate_reward_type",
                message = rewardLabel(event.rewardType) .. " is already planned in this reward group",
                relatedOccurrences = occurrence and { occurrence } or nil,
            }
        end
    end

    if duplicateBoonSourceConstraint(group)
        and event.rewardType == "Boon"
        and event.boonSource ~= nil
        and event.boonSource ~= ""
        and rewardContext.rewardRowGroupHasBoonSource(rewardCtx, group.key, event.boonSource)
    then
        local occurrence = rewardContext.rewardRowGroupBoonSourceOccurrence(rewardCtx, group.key, event.boonSource)
        return {
            code = "duplicate_boon_source",
            message = "Boon source is already planned in this reward group",
            relatedOccurrences = occurrence and { occurrence } or nil,
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

local function countDedupeKey(count, ctx)
    local scope = count.scope or "route"
    local biomeKey = scope == "biome" and ctx.biomeKey or ""
    return tostring(scope) .. ":" .. tostring(count.key) .. ":" .. tostring(biomeKey)
end

local function applyEventEffectsWithDedupe(rewardCtx, ctx, event, seenCounts, seenOccurrences)
    local rules = compiledRulesByTarget[event.rewardType]
    if rules ~= nil then
        for _, rule in ipairs(rules) do
            if ruleApplies(rule, event) then
                for _, count in ipairs(rule.countsAs or EMPTY_LIST) do
                    local dedupeKey = countDedupeKey(count, ctx)
                    if seenCounts == nil or not seenCounts[dedupeKey] then
                        rewardContext.applyCount(rewardCtx, count, ctx, event)
                        if seenCounts ~= nil then
                            seenCounts[dedupeKey] = true
                        end
                    end
                end
            end
        end
    end
    rewardContext.storeEventGodLoot(rewardCtx, event)
    if seenOccurrences == nil or not seenOccurrences[event.rewardType] then
        rewardContext.storeRewardOccurrence(rewardCtx, ctx, event)
        if seenOccurrences ~= nil then
            seenOccurrences[event.rewardType] = true
        end
    end
end

local function applyEventEffects(rewardCtx, ctx, event)
    applyEventEffectsWithDedupe(rewardCtx, ctx, event)
end

local function validateBatch(context, result, seenInvalids, rewardCtx, ctx, batch)
    local decision = recordSelectedBatch(result, rewardCtx, ctx, batch)
    for index = batch.firstEventIndex, batch.lastEventIndex do
        local event = batch.events[index]
        local invalid = eventInvalid(rewardCtx, ctx, event)
        if invalid ~= nil then
            local selectedInvalid = addInvalid(context, result, seenInvalids, ctx, event, invalid)
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

local function choiceGroupKey(batch)
    local group = batch and batch.item and batch.item.rewardChoiceGroup or nil
    if group == nil or group.effectTiming ~= "sameChoiceUnion" then
        return nil
    end
    return group.key
end

local function validateChoiceGroup(context, result, seenInvalids, rewardCtx, ctx, batches, groupKey)
    for _, batch in ipairs(batches) do
        if choiceGroupKey(batch) == groupKey then
            local invalid = validateBatch(context, result, seenInvalids, rewardCtx, ctx, batch)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

local function applyChoiceGroupUnionEffects(rewardCtx, ctx, batches, groupKey, seenCounts, seenOccurrences)
    clearMap(seenCounts)
    clearMap(seenOccurrences)
    for _, batch in ipairs(batches) do
        if choiceGroupKey(batch) == groupKey then
            for index = batch.firstEventIndex, batch.lastEventIndex do
                applyEventEffectsWithDedupe(rewardCtx, ctx, batch.events[index], seenCounts, seenOccurrences)
            end
        end
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
    local selectedInvalid = addInvalid(context, result, seenInvalids, entry.ctx, entry.event, invalid)
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
    scratch.choiceGroups = scratch.choiceGroups or {}
    scratch.choiceGroupSeenCounts = scratch.choiceGroupSeenCounts or {}
    scratch.choiceGroupSeenOccurrences = scratch.choiceGroupSeenOccurrences or {}
    scratch.topologyBranches = scratch.topologyBranches or {}
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

function rewardLegality.valueStatesForControl(result, biomeKey, rowIndex, rewardAddress, controlAlias, control, states)
    return topologyBranches.valueStatesForControl(
        topologyForRow(result, biomeKey, rowIndex),
        rewardAddress,
        controlAlias,
        control,
        states
    )
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
    recordRowTopology(result, ctx, row)
    local topologyEvent, topologyInvalid = topologyBranches.invalidForRow(row, scratch.topologyBranches)
    if topologyInvalid ~= nil then
        return addInvalid(context, result, scratch.seenInvalids, ctx, topologyEvent, topologyInvalid)
    end

    local batches = scratch.batches or {}
    local events = scratch.events or {}
    local rewardItemScratch = scratch.rewardItems or {}
    local processedChoiceGroups = scratch.choiceGroups
    scratch.batches = batches
    scratch.events = events
    scratch.rewardItems = rewardItemScratch
    clearMap(processedChoiceGroups)

    local selectionInvalid = validateSelectionRequirements(
        context,
        result,
        scratch.seenInvalids,
        ctx,
        row,
        rewardItemScratch
    )
    if selectionInvalid ~= nil then
        return selectionInvalid
    end

    collectRewardBatches(row, batches, rewardItemScratch, events)
    for _, batch in ipairs(batches) do
        local choiceKey = choiceGroupKey(batch)
        local group = batch.item and batch.item.rewardRowGroup or nil
        local handledChoiceGroup = false
        if choiceKey ~= nil then
            handledChoiceGroup = true
            if not processedChoiceGroups[choiceKey] then
                local invalid = validateChoiceGroup(context, result, scratch.seenInvalids, rewardCtx, ctx, batches, choiceKey)
                if invalid ~= nil then
                    return invalid
                end
                applyChoiceGroupUnionEffects(
                    rewardCtx,
                    ctx,
                    batches,
                    choiceKey,
                    scratch.choiceGroupSeenCounts,
                    scratch.choiceGroupSeenOccurrences
                )
                processedChoiceGroups[choiceKey] = true
            end
        elseif group ~= nil and group.key ~= nil then
            rewardContext.beginRewardRowGroup(rewardCtx, group)
        elseif rewardContext.activeRewardRowGroupKey(rewardCtx) ~= nil then
            stageBatchAfterRewardRowGroup(rewardCtx, ctx, batch)
        else
            local invalid = validateBatch(context, result, scratch.seenInvalids, rewardCtx, ctx, batch)
            if invalid ~= nil then
                return invalid
            end
        end
        if not handledChoiceGroup then
            if group ~= nil and group.key ~= nil then
                local invalid = validateBatch(context, result, scratch.seenInvalids, rewardCtx, ctx, batch)
                if invalid ~= nil then
                    return invalid
                end
                for index = batch.firstEventIndex, batch.lastEventIndex do
                    rewardContext.storeRewardRowGroupOccurrence(rewardCtx, ctx, batch.events[index])
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
    end
    if promotePendingAfterRow then
        promotePendingEffects(rewardCtx)
    end
    rewardContext.activateStagedPending(rewardCtx)
    rewardContext.storePreviousRow(rewardCtx, ctx, row)
    return nil
end

return rewardLegality
