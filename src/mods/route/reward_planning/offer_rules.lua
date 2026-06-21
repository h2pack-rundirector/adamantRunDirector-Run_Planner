local deps = ... or {}
local semantics = deps.semantics

local rewardOfferRules = {}

local EMPTY = {}

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
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

local function validateItem(group, seenRewardTypes, seenBoonSources, item, invalidOut)
    local selectedRewardType = item.rewardType or semantics.rewardType(item)
    if selectedRewardType == nil or selectedRewardType == "" then
        return nil
    end

    if group.uniqueRewardTypes
        and not (group.allowDuplicateRewardTypes and group.allowDuplicateRewardTypes[selectedRewardType])
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

    if group.uniqueBoonSource and selectedRewardType == "Boon" then
        local selectedBoonSource = item.boonSource or semantics.boonSource(item)
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

function rewardOfferRules.groupForScope(groups, groupKey, scope)
    local group = groups and groups[groupKey] or nil
    if group == nil or group.scope ~= scope then
        return nil
    end
    return group
end

function rewardOfferRules.firstInvalid(group, items, scratch)
    if group == nil then
        return nil
    end

    scratch = scratch or {}
    scratch.seenRewardTypes = scratch.seenRewardTypes or {}
    scratch.seenBoonSources = scratch.seenBoonSources or {}
    scratch.invalid = scratch.invalid or {}
    clearMap(scratch.seenRewardTypes)
    clearMap(scratch.seenBoonSources)

    for _, item in ipairs(items or EMPTY) do
        local invalidItem = validateItem(group, scratch.seenRewardTypes, scratch.seenBoonSources, item, scratch.invalid)
        if invalidItem ~= nil then
            return invalidItem
        end
    end
    return nil
end

function rewardOfferRules.validateOffer(group, items)
    local invalids = {}
    if group == nil then
        return invalids
    end

    local seenRewardTypes = {}
    local seenBoonSources = {}
    for _, item in ipairs(items or EMPTY) do
        appendInvalid(invalids, validateItem(group, seenRewardTypes, seenBoonSources, item))
    end
    return invalids
end

return rewardOfferRules
