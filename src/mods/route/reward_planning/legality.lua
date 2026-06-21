local deps = ... or {}
local conditions = deps.conditions or {}
local routeTimeline = deps.timeline
local rowRewardItems = deps.rewardItems
local semantics = deps.semantics
local invalidLocations = deps.invalidLocations
if routeTimeline == nil then
    error("route.planning.legality requires route timeline")
end
if rowRewardItems == nil then
    error("route.planning.legality requires reward items")
end
if semantics == nil then
    error("route.planning.legality requires reward semantics")
end
if invalidLocations == nil then
    error("route.planning.legality requires invalid location formatter")
end

local rewardLegality = {}
local EMPTY_LIST = {}

local function defaultRouteControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function buildLookup(values)
    local lookup = {}
    for _, value in ipairs(values or EMPTY_LIST) do
        lookup[value] = true
    end
    return lookup
end

local function collectRewardEvents(row, events, items)
    semantics.eventsForRow(row, rowRewardItems, events, items)
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
end

local function biomeCounters(state, biomeKey)
    local counters = state.biomeCounters[biomeKey]
    if counters == nil then
        counters = {}
        state.biomeCounters[biomeKey] = counters
    end
    return counters
end

local function countersForScope(state, scope, biomeKey)
    if scope == "biome" then
        return biomeCounters(state, biomeKey)
    end
    return state.routeCounters
end

local function counterValue(state, counterKey, scope, biomeKey)
    return countersForScope(state, scope, biomeKey)[counterKey] or 0
end

local function incrementCounter(state, counterKey, scope, biomeKey)
    local counters = countersForScope(state, scope, biomeKey)
    counters[counterKey] = (counters[counterKey] or 0) + 1
end

local function seenGodLootCount(state, requirement)
    local count = 0
    for _, lootName in ipairs(requirement.countedLootNames or EMPTY_LIST) do
        if state.godLootSeen[lootName] then
            count = count + 1
        end
    end
    return count
end

local function requirementSkipped(requirement, ctx)
    for _, biomeKey in ipairs(requirement.exceptBiomes or EMPTY_LIST) do
        if biomeKey == ctx.biomeKey then
            return true
        end
    end
    return false
end

local function previousRoomExitCountInvalid(requirement, state, ctx)
    local previousRow = state.previousRows[ctx.biomeKey]
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

local function minRoomHistorySpacingInvalid(requirement, state, ctx, event)
    local rewardType = requirement.event or event.rewardType
    local previousOrdinal = state.lastRewardRoomHistoryOrdinal[rewardType]
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

local function requirementInvalid(requirement, state, ctx, event)
    if requirementSkipped(requirement, ctx) then
        return nil
    end

    if requirement.kind == "previousShopExclusion" then
        for _, rewardType in ipairs(requirement.rewards or EMPTY_LIST) do
            if state.previousShopRewards[rewardType] then
                return requirement
            end
        end
        return nil
    end

    if requirement.kind == "priorDistinctGodLoot" then
        if seenGodLootCount(state, requirement) < requirement.minDistinct then
            return requirement
        end
        return nil
    elseif requirement.kind == "previousRoomExitCount" then
        return previousRoomExitCountInvalid(requirement, state, ctx)
    elseif requirement.kind == "minRoomHistorySpacing" then
        return minRoomHistorySpacingInvalid(requirement, state, ctx, event)
    elseif requirement.kind == "minRunEncounterDepth" then
        return minRunEncounterDepthInvalid(requirement, ctx)
    end

    local count = counterValue(state, requirement.counter, requirement.scope, ctx.biomeKey)
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

local function ruleApplies(rule, event)
    local lookup = rule.appliesToRewardKindLookup
    if lookup == nil then
        return true
    end
    return lookup[event.item and event.item.rewardKind or ""] == true
end

local function ruleInvalid(rule, state, ctx, event)
    for _, requirement in ipairs(rule.requirements or EMPTY_LIST) do
        local invalid = requirementInvalid(requirement, state, ctx, event)
        if invalid ~= nil then
            return invalid
        end
    end
    return nil
end

local function applyCounts(rule, state, ctx)
    for _, count in ipairs(rule.countsAs or EMPTY_LIST) do
        incrementCounter(state, count.key, count.scope, ctx.biomeKey)
    end
end

local function storeGodLootValue(state, lootName)
    if lootName ~= nil and lootName ~= "" then
        state.godLootSeen[lootName] = true
    end
end

local function storeEventGodLoot(state, event)
    if event == nil then
        return
    end

    if event.rewardType == "Boon" then
        storeGodLootValue(state, event.boonSource)
    elseif event.rewardType == "Devotion" then
        storeGodLootValue(state, event.devotionSourceA)
        storeGodLootValue(state, event.devotionSourceB)
    else
        storeGodLootValue(state, event.boonSource)
    end
end

local function storeRewardOccurrence(state, ctx, event)
    if event.rewardType ~= nil and ctx.roomHistoryOrdinal ~= nil then
        state.lastRewardRoomHistoryOrdinal[event.rewardType] = ctx.roomHistoryOrdinal
    end
end

local function applyEventRules(context, result, seenInvalids, state, ctx, event)
    local rules = compiledRulesByTarget[event.rewardType]
    if rules == nil then
        storeEventGodLoot(state, event)
        storeRewardOccurrence(state, ctx, event)
        return
    end

    for _, rule in ipairs(rules) do
        if ruleApplies(rule, event) then
            local invalid = ruleInvalid(rule, state, ctx, event)
            if invalid ~= nil then
                addInvalid(context, result, seenInvalids, ctx, event, invalid.code, invalid.message)
                return
            end
        end
    end

    for _, rule in ipairs(rules) do
        if ruleApplies(rule, event) then
            applyCounts(rule, state, ctx)
        end
    end
    storeEventGodLoot(state, event)
    storeRewardOccurrence(state, ctx, event)
end

local function storePreviousShopRewards(state, events)
    clearMap(state.previousShopRewards)
    for _, event in ipairs(events) do
        if event.item ~= nil and event.item.rewardKind == "shop" then
            state.previousShopRewards[event.rewardType] = true
        end
    end
end

function rewardLegality.emptyResult()
    return newResult()
end

function rewardLegality.evaluate(context, routeKey, opts)
    opts = opts or {}
    local route = context.routes.lookup and context.routes.lookup[routeKey] or nil
    local result = newResult()
    if route == nil then
        return result
    end

    local snapshotForBiome = opts.snapshotForBiome
    local routeControlName = opts.routeControlName or defaultRouteControlName
    local state = {
        routeCounters = {},
        biomeCounters = {},
        godLootSeen = {},
        lastRewardRoomHistoryOrdinal = {},
        previousShopRewards = {},
        previousRows = {},
    }
    local events = {}
    local rewardItemScratch = {}
    local seenInvalids = {}

    routeTimeline.walkRoute(route, {
        biomeLookup = context.biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return snapshotForBiome and snapshotForBiome(route.key, biomeKey) or nil
        end,
        onRow = function(rowContext)
            local row = rowContext.row
            local biomeKey = rowContext.biomeKey
            local ctx = {
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
            if row ~= nil and row.valid ~= false then
                for index in pairs(events) do
                    events[index] = nil
                end
                collectRewardEvents(row, events, rewardItemScratch)
                for _, event in ipairs(events) do
                    applyEventRules(context, result, seenInvalids, state, ctx, event)
                end
                storePreviousShopRewards(state, events)
                state.previousRows[biomeKey] = row
            else
                clearMap(state.previousShopRewards)
                state.previousRows[biomeKey] = nil
            end
        end,
    })

    return result
end

return rewardLegality
