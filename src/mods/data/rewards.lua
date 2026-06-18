return function(importer)
local routeRules = importer("mods/data/route_rules.lua")
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
    return {
        kind = "majorMinor",
        majorRewardStore = opts.majorRewardStore or "RunProgress",
        minorRewardStore = opts.minorRewardStore or "MetaProgress",
    }
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

function rewards.devotion(opts)
    opts = opts or {}
    local context = rewards.forcedReward("Devotion", opts)
    context.pick = routeRules.devotionPick()
    context.routeRequirements = routeRules.devotionRequirements(opts)
    return context
end

function rewards.shop(shopProfile)
    return {
        kind = "shop",
        shopProfile = shopProfile,
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
            routeRequirements = routeRules.devotionRequirements(),
        },
    }

    return {
        ordered = ordered,
        lookup = indexByKey(ordered),
    }
end

return rewards
end
