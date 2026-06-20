local rewardOfferRules = {}

local EMPTY = {}

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function pickValueByKey(item, key)
    for _, pick in ipairs(item and item.rewardPicks or EMPTY) do
        if pick.key == key then
            return pick.value
        end
    end
    return nil
end

local function rewardType(item)
    if item == nil then
        return nil
    end
    if item.rewardType ~= nil then
        return item.rewardType
    end

    local rewards = item.rewards or EMPTY
    if item.rewardKind == "boonSource" then
        return "Boon"
    elseif item.rewardKind == "roomStore" then
        return rewards[1]
    elseif item.rewardKind == "majorMinor" or item.rewardKind == "shipWheel" then
        if rewards[1] == "Major" or rewards[1] == "Minor" then
            return rewards[2]
        end
    elseif item.rewardKind == "devotionPair" then
        return "Devotion"
    elseif item.rewardKind == "fixedReward" then
        return item.fixedRewardType or rewards[1]
    end
    return nil
end

local function boonSource(item)
    if item == nil then
        return nil
    end
    if item.boonSource ~= nil then
        return item.boonSource
    end

    local rewards = item.rewards or EMPTY
    if item.rewardKind == "boonSource" then
        return pickValueByKey(item, "boonSource") or rewards[1]
    elseif item.rewardKind == "roomStore" and rewards[1] == "Boon" then
        return pickValueByKey(item, "boonSource") or rewards[2]
    elseif (item.rewardKind == "majorMinor" or item.rewardKind == "shipWheel")
        and rewards[1] == "Major"
        and rewards[2] == "Boon"
    then
        return pickValueByKey(item, "boonSource") or rewards[3]
    end
    return nil
end

local function itemRouteOrdinal(item)
    return item and item.routeOrdinal or nil
end

local function itemRowIndex(item)
    return item and item.rowIndex or nil
end

local function invalid(code, message, item)
    return {
        valid = false,
        rowIndex = itemRowIndex(item),
        routeOrdinal = itemRouteOrdinal(item),
        code = code,
        message = message,
    }
end

local function fillInvalid(target, code, message, item)
    target.valid = false
    target.rowIndex = itemRowIndex(item)
    target.routeOrdinal = itemRouteOrdinal(item)
    target.code = code
    target.message = message
    return target
end

local function appendInvalid(results, result)
    if result ~= nil and not result.valid then
        results[#results + 1] = result
    end
end

local function rewardLabel(value)
    if value == "Boon" then
        return "Boon"
    end
    return tostring(value)
end

local function validateItem(policy, seenRewardTypes, seenBoonSources, item, invalidOut)
    local selectedRewardType = rewardType(item)
    if selectedRewardType == nil or selectedRewardType == "" then
        return nil
    end

    if policy.uniqueRewardTypes
        and not (policy.allowDuplicateRewardTypes and policy.allowDuplicateRewardTypes[selectedRewardType])
    then
        local previous = seenRewardTypes[selectedRewardType]
        if previous ~= nil then
            return invalidOut ~= nil and fillInvalid(
                invalidOut,
                "duplicate_reward_type",
                rewardLabel(selectedRewardType) .. " is already planned in this reward offer",
                item
            ) or invalid(
                "duplicate_reward_type",
                rewardLabel(selectedRewardType) .. " is already planned in this reward offer",
                item
            )
        end
        seenRewardTypes[selectedRewardType] = item
    end

    if policy.uniqueBoonSource and selectedRewardType == "Boon" then
        local selectedBoonSource = boonSource(item)
        if selectedBoonSource ~= nil and selectedBoonSource ~= "" then
            local previous = seenBoonSources[selectedBoonSource]
            if previous ~= nil then
                return invalidOut ~= nil and fillInvalid(
                    invalidOut,
                    "duplicate_boon_source",
                    "Boon source is already planned in this reward offer",
                    item
                ) or invalid(
                    "duplicate_boon_source",
                    "Boon source is already planned in this reward offer",
                    item
                )
            end
            seenBoonSources[selectedBoonSource] = item
        end
    end

    return nil
end

function rewardOfferRules.policyForScope(policies, policyKey, scope)
    local policy = policies and policies[policyKey] or nil
    if policy == nil or policy.scope ~= scope then
        return nil
    end
    return policy
end

function rewardOfferRules.firstInvalid(policy, items, scratch)
    if policy == nil then
        return nil
    end

    scratch = scratch or {}
    scratch.seenRewardTypes = scratch.seenRewardTypes or {}
    scratch.seenBoonSources = scratch.seenBoonSources or {}
    scratch.invalid = scratch.invalid or {}
    clearMap(scratch.seenRewardTypes)
    clearMap(scratch.seenBoonSources)

    for _, item in ipairs(items or EMPTY) do
        local invalidItem = validateItem(policy, scratch.seenRewardTypes, scratch.seenBoonSources, item, scratch.invalid)
        if invalidItem ~= nil then
            return invalidItem
        end
    end
    return nil
end

function rewardOfferRules.validateOffer(policy, items)
    local invalids = {}
    if policy == nil then
        return invalids
    end

    local seenRewardTypes = {}
    local seenBoonSources = {}
    for _, item in ipairs(items or EMPTY) do
        appendInvalid(invalids, validateItem(policy, seenRewardTypes, seenBoonSources, item))
    end
    return invalids
end

return rewardOfferRules
