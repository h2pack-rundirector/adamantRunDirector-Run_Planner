return function(importer)
local routeRules = importer("mods/biomes/declaration_rules.lua")
local rewards = {}

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

local function copyUniqueOfferGroups(context, groups)
    if groups == nil then
        return
    end
    local copiedGroups = {}
    for groupIndex, group in ipairs(groups) do
        copiedGroups[groupIndex] = {
            slots = copyList(group.slots),
            code = group.code,
            message = group.message,
        }
    end
    context.uniqueOfferGroups = copiedGroups
end

local function copyRewardGeneration(context, generation)
    if generation == nil then
        return
    end
    context.rewardGeneration = {
        effectTiming = generation.effectTiming,
    }
end

function rewards.shop(shopProfile, opts)
    opts = opts or {}
    local context = {
        kind = "shop",
        shopProfile = shopProfile,
    }
    copyUniqueOfferGroups(context, opts.uniqueOfferGroups)
    copyRewardGeneration(context, opts.rewardGeneration)
    return context
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

function rewards.fieldsBridge()
    return {
        kind = "fieldsBridge",
        storyReward = "Story",
        shopReward = "Shop",
        shopProfile = "WorldShop",
    }
end

function rewards.shipWheel(opts)
    opts = opts or {}
    local context = {
        kind = "shipWheel",
        storeSource = opts.storeSource or "ChooseNextRewardStore",
        defaultRewardStore = opts.defaultRewardStore or "RunProgress",
    }
    if opts.eligibleRewardTypes ~= nil then
        context.eligibleRewardTypes = copyList(opts.eligibleRewardTypes)
    end
    if opts.ineligibleRewardTypes ~= nil then
        context.ineligibleRewardTypes = copyList(opts.ineligibleRewardTypes)
    end
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
