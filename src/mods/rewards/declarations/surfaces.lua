return function(deps)
local routeRules = deps.routeRules
local rewardConstraints = deps.rewardConstraints
local rewards = {}

local DEFAULT_SHOP_REWARD_GENERATION = {
    effectTiming = "afterNextRow",
}

local function copyList(items)
    local copy = {}
    for index, item in ipairs(items or {}) do
        copy[index] = item
    end
    return copy
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

local function copyRewardGeneration(context, generation)
    if generation == nil then
        return
    end
    context.rewardGeneration = {
        effectTiming = generation.effectTiming,
    }
end

local function prefixedKey(prefix, key)
    if prefix == "" then
        return key
    end
    return prefix .. string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
end

local function copyRewardFilters(context, opts, sourcePrefix, targetPrefix)
    local sourceEligibleTypes = prefixedKey(sourcePrefix, "eligibleRewardTypes")
    local sourceIneligibleTypes = prefixedKey(sourcePrefix, "ineligibleRewardTypes")
    local targetEligibleTypes = prefixedKey(targetPrefix, "eligibleRewardTypes")
    local targetIneligibleTypes = prefixedKey(targetPrefix, "ineligibleRewardTypes")

    if opts[sourceEligibleTypes] ~= nil then
        context[targetEligibleTypes] = copyList(opts[sourceEligibleTypes])
    end
    if opts[sourceIneligibleTypes] ~= nil then
        context[targetIneligibleTypes] = copyList(opts[sourceIneligibleTypes])
    end
end

function rewards.none()
    return {
        kind = "none",
    }
end

function rewards.roomStore(rewardStore, opts)
    opts = opts or {}
    local context = {
        kind = "roomStore",
        rewardStore = rewardStore,
    }
    copyRewardFilters(context, opts, "", "")
    return context
end

function rewards.majorMinor(opts)
    opts = opts or {}
    local context = {
        kind = "majorMinor",
        majorRewardStore = opts.majorRewardStore or "RunProgress",
        minorRewardStore = opts.minorRewardStore or "MetaProgress",
    }
    if opts.allowDevotion == true then
        context.allowDevotion = true
    end
    copyRewardFilters(context, opts, "major", "major")
    copyRewardFilters(context, opts, "minor", "minor")
    copyRewardFilters(context, opts, "", "")
    return context
end

function rewards.forcedReward(rewardType, opts)
    opts = opts or {}
    local context = {
        kind = "forcedReward",
        rewardType = rewardType,
    }
    if opts.rewardStore ~= nil then
        context.rewardStore = opts.rewardStore
    end
    return context
end

function rewards.devotion()
    local context = rewards.forcedReward("Devotion")
    context.pick = routeRules.devotionPick()
    return context
end

function rewards.shop(shopProfile, opts)
    opts = opts or {}
    local context = {
        kind = "shop",
        shopProfile = shopProfile,
    }
    copyRewardGeneration(context, opts.rewardGeneration or DEFAULT_SHOP_REWARD_GENERATION)
    return context
end

function rewards.preboss(shopProfile, rewardStore, opts)
    opts = opts or {}
    local roomOffer = {
        address = "prebossReward",
        label = "Free Reward",
        kind = "roomStore",
        rewardStore = rewardStore,
        rewardAliasStart = 4,
        rewardAliasCount = 2,
        requiredBranchValue = "FreeReward",
    }
    copyRewardFilters(roomOffer, opts, "", "")

    return {
        kind = "preboss",
        offers = {
            {
                address = "prebossShop",
                label = "Shop",
                kind = "shop",
                shopProfile = shopProfile,
                rewardAliasStart = 1,
                rewardAliasCount = 3,
                rewardGeneration = {
                    effectTiming = "afterBatch",
                },
                requiredBranchValue = "Shop",
            },
            roomOffer,
        },
    }
end

function rewards.rewardRowGroup(groupKey, opts)
    opts = opts or {}
    return {
        key = groupKey,
        effectTiming = opts.effectTiming,
        constraints = rewardConstraints.rewardRowGroup(groupKey),
    }
end

function rewards.fieldsCages(opts)
    opts = opts or {}
    local context = {
        kind = "fieldsCages",
        rewardStore = opts.rewardStore or "RunProgress",
    }
    copyRewardFilters(context, opts, "", "")
    copyRewardGeneration(context, opts.rewardGeneration)
    return context
end

function rewards.rewardTypeMetadata()
    local ordered = {
        {
            key = "Boon",
            label = "Boon",
            kind = "boon",
            pick = routeRules.boonSourcePick(),
        },
        {
            key = "HermesUpgrade",
            label = "Hermes",
            kind = "standaloneLoot",
        },
        {
            key = "Devotion",
            label = "Trial",
            kind = "devotion",
            pick = routeRules.devotionPick(),
        },
    }

    return {
        ordered = ordered,
        lookup = indexByKey(ordered),
    }
end

return rewards
end
