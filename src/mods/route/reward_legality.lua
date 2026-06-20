local deps = ... or {}
local routeRules = deps.routeRules or deps.rules or {}

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

local function rewardPickValue(item, key)
    for _, pick in ipairs(item and item.rewardPicks or EMPTY_LIST) do
        if pick.key == key then
            return pick.value
        end
    end
    return nil
end

local function rewardPickValueByKind(item, kind)
    for _, pick in ipairs(item and item.rewardPicks or EMPTY_LIST) do
        if pick.kind == kind then
            return pick.value
        end
    end
    return nil
end

local function concreteRewardType(item)
    if item == nil or item.valid == false then
        return nil
    end

    local kind = item.rewardKind
    local rewards = item.rewards or EMPTY_LIST
    if kind == "boonSource" then
        return "Boon"
    elseif kind == "devotionPair" then
        return "Devotion"
    elseif kind == "fixedReward" then
        return item.fixedRewardType or rewards[1]
    elseif kind == "roomStore" then
        return rewardPickValue(item, "rewardType") or rewards[1]
    elseif kind == "majorMinor" or kind == "shipWheel" then
        local branch = rewards[1]
        if branch == "Major" then
            return rewardPickValue(item, "rewardType") or rewards[2]
        elseif branch == "Minor" then
            return rewardPickValue(item, "rewardType") or rewards[4]
        end
    end
    return nil
end

local function appendRewardEvent(events, row, item, address)
    local rewardType = concreteRewardType(item)
    if rewardType == nil or rewardType == "" then
        return
    end
    events[#events + 1] = {
        row = row,
        item = item,
        rewardType = rewardType,
        address = address,
    }
end

local function appendShopRewardEvents(events, row, item)
    local rewards = item and item.rewards or EMPTY_LIST
    if item == nil or item.valid == false or item.rewardKind ~= "shop" then
        return false
    end

    local appended = false
    for index, rewardType in ipairs(rewards) do
        if rewardType ~= nil and rewardType ~= "" then
            appended = true
            events[#events + 1] = {
                row = row,
                item = item,
                rewardType = rewardType,
                address = "shop:" .. tostring(index),
            }
        end
    end
    return appended
end

local function appendRewardItemEvents(events, row, item, address)
    if not appendShopRewardEvents(events, row, item) then
        appendRewardEvent(events, row, item, address)
    end
end

local function buildLookup(values)
    local lookup = {}
    for _, value in ipairs(values or EMPTY_LIST) do
        lookup[value] = true
    end
    return lookup
end

local function collectRewardEvents(row, events)
    appendRewardItemEvents(events, row, row, "row")
    for _, sideRoom in ipairs(row and row.sideRooms or EMPTY_LIST) do
        appendRewardItemEvents(events, row, sideRoom, "side:" .. tostring(sideRoom.sideIndex or ""))
    end
    for _, cageReward in ipairs(row and row.cageRewards or EMPTY_LIST) do
        appendRewardItemEvents(events, row, cageReward, "cage:" .. tostring(cageReward.cageIndex or ""))
    end
    for _, encounterRewardLeg in ipairs(row and row.encounterRewardLegs or EMPTY_LIST) do
        appendRewardItemEvents(events, row, encounterRewardLeg, "encounter:" .. tostring(encounterRewardLeg.legIndex or ""))
    end
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

local compiledRulesByTarget = compileRules(routeRules)

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

local function addInvalid(result, seenInvalids, ctx, event, code, message)
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

local function requirementInvalid(requirement, state, ctx)
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

local function ruleInvalid(rule, state, ctx)
    for _, requirement in ipairs(rule.requirements or EMPTY_LIST) do
        local invalid = requirementInvalid(requirement, state, ctx)
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
    local item = event and event.item or nil
    if item == nil then
        return
    end

    local rewards = item.rewards or EMPTY_LIST
    if event.rewardType == "Boon" then
        storeGodLootValue(state, rewardPickValue(item, "boonSource") or rewardPickValueByKind(item, "boonSource") or rewards[2])
    elseif event.rewardType == "Devotion" then
        local fallbackA = rewards[1]
        local fallbackB = rewards[2]
        if item.rewardKind == "roomStore" then
            fallbackA = rewards[3]
            fallbackB = rewards[4]
        elseif item.rewardKind == "majorMinor" or item.rewardKind == "shipWheel" then
            fallbackA = rewards[5]
            fallbackB = rewards[6]
        end
        storeGodLootValue(state, rewardPickValue(item, "lootAName") or fallbackA)
        storeGodLootValue(state, rewardPickValue(item, "lootBName") or fallbackB)
    end
end

local function applyEventRules(result, seenInvalids, state, ctx, event)
    local rules = compiledRulesByTarget[event.rewardType]
    if rules == nil then
        storeEventGodLoot(state, event)
        return
    end

    for _, rule in ipairs(rules) do
        if ruleApplies(rule, event) then
            local invalid = ruleInvalid(rule, state, ctx)
            if invalid ~= nil then
                addInvalid(result, seenInvalids, ctx, event, invalid.code, invalid.message)
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
        previousShopRewards = {},
        previousRows = {},
    }
    local events = {}
    local seenInvalids = {}

    for routeBiomeIndex, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
        local snapshot = snapshotForBiome and snapshotForBiome(route.key, biomeKey) or nil
        local ctx = {
            biomeKey = biomeKey,
            routeBiomeIndex = routeBiomeIndex,
            controlName = snapshot and snapshot.controlName or routeControlName(biomeKey),
        }
        for _, row in ipairs(snapshot and snapshot.rows or EMPTY_LIST) do
            if row ~= nil and row.valid ~= false then
                for index in pairs(events) do
                    events[index] = nil
                end
                collectRewardEvents(row, events)
                for _, event in ipairs(events) do
                    applyEventRules(result, seenInvalids, state, ctx, event)
                end
                storePreviousShopRewards(state, events)
                state.previousRows[biomeKey] = row
            else
                clearMap(state.previousShopRewards)
                state.previousRows[biomeKey] = nil
            end
        end
    end

    return result
end

return rewardLegality
