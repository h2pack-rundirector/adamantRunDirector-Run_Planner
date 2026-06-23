return function(importer)
local routeRules = importer("mods/biomes/declaration_rules.lua")
local rewardConstraints = importer("mods/rewards/declarations/constraints.lua")
local rewards = {}

local DEFAULT_SHOP_REWARD_GENERATION = {
    effectTiming = "afterNextRow",
}

local function prebossChoiceGroup()
    return {
        key = "prebossChoice",
        effectTiming = "sameChoiceUnion",
    }
end

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
    if opts.eligibleRewardTypes ~= nil then
        context.eligibleRewardTypes = copyList(opts.eligibleRewardTypes)
    end
    if opts.ineligibleRewardTypes ~= nil then
        context.ineligibleRewardTypes = copyList(opts.ineligibleRewardTypes)
    end
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
    if opts.majorEligibleRewardTypes ~= nil then
        context.majorEligibleRewardTypes = copyList(opts.majorEligibleRewardTypes)
    end
    if opts.majorIneligibleRewardTypes ~= nil then
        context.majorIneligibleRewardTypes = copyList(opts.majorIneligibleRewardTypes)
    end
    if opts.minorEligibleRewardTypes ~= nil then
        context.minorEligibleRewardTypes = copyList(opts.minorEligibleRewardTypes)
    end
    if opts.minorIneligibleRewardTypes ~= nil then
        context.minorIneligibleRewardTypes = copyList(opts.minorIneligibleRewardTypes)
    end
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
        rewardChoiceGroup = prebossChoiceGroup(),
    }
    if opts.eligibleRewardTypes ~= nil then
        roomOffer.eligibleRewardTypes = copyList(opts.eligibleRewardTypes)
    end
    if opts.ineligibleRewardTypes ~= nil then
        roomOffer.ineligibleRewardTypes = copyList(opts.ineligibleRewardTypes)
    end

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
                rewardGeneration = DEFAULT_SHOP_REWARD_GENERATION,
                rewardChoiceGroup = prebossChoiceGroup(),
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
    if opts.eligibleRewardTypes ~= nil then
        context.eligibleRewardTypes = copyList(opts.eligibleRewardTypes)
    end
    if opts.ineligibleRewardTypes ~= nil then
        context.ineligibleRewardTypes = copyList(opts.ineligibleRewardTypes)
    end
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
