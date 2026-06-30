local deps = ... or {}

local routeHistory = deps.history
local routeQuery = deps.query

local rewardValidator = {}

local EMPTY_LIST = {}

local function validResult()
    return {
        valid = true,
        invalids = {},
    }
end

local function buildRulesByTarget(rules)
    local byTarget = {}
    for _, rule in ipairs(rules or EMPTY_LIST) do
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

local function compare(value, comparison, target)
    if comparison == "==" then
        return value == target
    elseif comparison == "~=" then
        return value ~= target
    elseif comparison == ">=" then
        return value >= target
    elseif comparison == "<=" then
        return value <= target
    elseif comparison == ">" then
        return value > target
    elseif comparison == "<" then
        return value < target
    end
    return false
end

local function skipped(requirement, entry, opts)
    if opts ~= nil
        and opts.skipRequirementKinds ~= nil
        and opts.skipRequirementKinds[requirement.kind]
    then
        return true
    end
    for _, biomeKey in ipairs(requirement.exceptBiomes or EMPTY_LIST) do
        if biomeKey == entry.biomeKey then
            return true
        end
    end
    return false
end

local function lootTypeHistoryCount(history, entry, lootTypes)
    local count = 0
    for _, lootType in ipairs(lootTypes or EMPTY_LIST) do
        count = count + routeQuery.lootTypeHistoryCount(history, entry, lootType)
    end
    return count
end

local function biomeUseRecordCount(history, entry, lootTypes)
    local count = 0
    for _, lootType in ipairs(lootTypes or EMPTY_LIST) do
        count = count + routeQuery.biomeUseRecordCount(history, entry, lootType)
    end
    return count
end

local function matchingLastLoot(history, entry, lootTypes)
    local latest = nil
    for _, lootType in ipairs(lootTypes or EMPTY_LIST) do
        local current = routeQuery.lastLootType(history, entry, lootType)
        if current ~= nil
            and (
                latest == nil
                or (current.roomHistoryOrdinal or 0) > (latest.roomHistoryOrdinal or 0)
            )
        then
            latest = current
        end
    end
    return latest
end

local function currentLootSourcesSeen(history, entry)
    for _, sourceValue in ipairs(entry.sourceValues or EMPTY_LIST) do
        if not routeQuery.hasLootSource(history, entry, sourceValue) then
            return false
        end
    end
    return true
end

local function eventRequirement(requirement)
    local spec = {}
    for key, value in pairs(requirement.event or {}) do
        spec[key] = value
    end
    spec.axis = requirement.axis
    spec.count = requirement.count
    return spec
end

local function relatedEvents(history, entry, requirement, context)
    local related = {}
    for _, item in ipairs(requirement.related or EMPTY_LIST) do
        if item.kind == "lastMatchingLoot" then
            local last = context.lastMatchingLoot
                or matchingLastLoot(history, entry, requirement.countOf)
            if last ~= nil then
                related[#related + 1] = last
            end
        elseif item.kind == "pendingOffer" then
            local valid, pending = routeQuery.requiredNotInStore(history, entry, item.name)
            if not valid and pending ~= nil then
                related[#related + 1] = pending
            end
        end
    end
    return related
end

local function failure(requirement, context)
    return {
        code = requirement.code,
        message = requirement.message,
        requirement = requirement,
        relatedEvents = context and context.relatedEvents or nil,
    }
end

local evaluateRequirement

local function evaluateAll(history, entry, requirements, opts)
    for _, requirement in ipairs(requirements or EMPTY_LIST) do
        local invalid = evaluateRequirement(history, entry, requirement, opts)
        if invalid ~= nil then
            return invalid
        end
    end
    return nil
end

local function evaluateAny(history, entry, requirement, opts)
    local firstInvalid = nil
    for _, child in ipairs(requirement.requirements or EMPTY_LIST) do
        local invalid = evaluateRequirement(history, entry, child, opts)
        if invalid == nil then
            return nil
        end
        firstInvalid = firstInvalid or invalid
    end
    return failure(requirement, {
        relatedEvents = firstInvalid and firstInvalid.relatedEvents or nil,
    })
end

function evaluateRequirement(history, entry, requirement, opts)
    if skipped(requirement, entry, opts) then
        return nil
    end

    local kind = requirement.kind
    if kind == "All" then
        return evaluateAll(history, entry, requirement.requirements, opts)
    elseif kind == "Any" then
        return evaluateAny(history, entry, requirement, opts)
    elseif kind == "LootTypeHistory" then
        local count = lootTypeHistoryCount(history, entry, requirement.countOf)
        if not compare(count, requirement.comparison, requirement.value) then
            return failure(requirement, {
                relatedEvents = relatedEvents(history, entry, requirement, {
                    lastMatchingLoot = matchingLastLoot(history, entry, requirement.countOf),
                }),
            })
        end
    elseif kind == "BiomeUseRecord" then
        local count = biomeUseRecordCount(history, entry, requirement.countOf)
        if not compare(count, requirement.comparison, requirement.value) then
            return failure(requirement, {
                relatedEvents = relatedEvents(history, entry, requirement, {
                    lastMatchingLoot = matchingLastLoot(history, entry, requirement.countOf),
                }),
            })
        end
    elseif kind == "PriorDistinctLootSources" then
        local count = routeQuery.distinctLootSourceCount(history, entry, requirement.sourceValues)
        if not compare(count, requirement.comparison, requirement.value) then
            return failure(requirement)
        end
    elseif kind == "RequiredMinExits" then
        if not routeQuery.requiredMinExits(history, entry, requirement.value) then
            return failure(requirement)
        end
    elseif kind == "RunEncounterDepth" then
        if not compare(routeQuery.runEncounterDepth(entry), requirement.comparison, requirement.value) then
            return failure(requirement)
        end
    elseif kind == "EnteredBiomes" then
        if not compare(routeQuery.enteredBiomes(entry), requirement.comparison, requirement.value) then
            return failure(requirement)
        end
    elseif kind == "RequiredMinRoomsSinceEvent" then
        local valid, previous = routeQuery.requiredMinRoomsSinceEvent(history, entry, eventRequirement(requirement))
        if not valid then
            return failure(requirement, {
                relatedEvents = previous ~= nil and { previous } or nil,
            })
        end
    elseif kind == "RequiredNotInStore" then
        local valid, pending = routeQuery.requiredNotInStore(history, entry, requirement.name)
        if not valid then
            return failure(requirement, {
                relatedEvents = pending ~= nil and { pending } or nil,
            })
        end
    elseif kind == "CurrentLootSourcesSeen" then
        if not currentLootSourcesSeen(history, entry) then
            return failure(requirement)
        end
    end
    return nil
end

function rewardValidator.rulesByTarget(rules)
    return buildRulesByTarget(rules)
end

function rewardValidator.invalidForLootType(history, entry, lootType, rulesByTarget, opts)
    for _, rule in ipairs((rulesByTarget or {})[lootType] or EMPTY_LIST) do
        local invalid = evaluateAll(history, entry, rule.requirements, opts)
        if invalid ~= nil then
            return invalid
        end
    end
    return nil
end

local function invalidAt(entry, invalid)
    return {
        code = invalid.code,
        message = invalid.message,
        routeKey = entry.routeKey,
        biomeKey = entry.biomeKey,
        routeBiomeIndex = entry.routeBiomeIndex,
        rowIndex = entry.rowIndex,
        routeOrdinal = entry.routeOrdinal,
        roomHistoryOrdinal = entry.roomHistoryOrdinal,
        roomKey = entry.parentRoomKey,
        address = entry.address,
        controlAlias = entry.controlAlias,
        rewardClass = entry.rewardClass,
        rewardStore = entry.rewardStore,
        rewardType = entry.lootType,
        entry = entry,
        relatedEvents = invalid.relatedEvents,
    }
end

function rewardValidator.validate(args)
    local history = args and args.history or nil
    local rulesByTarget = buildRulesByTarget(args and args.selectedLegalityRules)
    for _, loot in ipairs(routeHistory.byKind(history, "loot")) do
        local invalid = rewardValidator.invalidForLootType(
            history,
            loot,
            loot.lootType,
            rulesByTarget
        )
        if invalid ~= nil then
            return {
                valid = false,
                invalids = { invalidAt(loot, invalid) },
            }
        end
    end
    return validResult()
end

return rewardValidator
