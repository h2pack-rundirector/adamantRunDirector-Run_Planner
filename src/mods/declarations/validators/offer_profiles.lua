local guard = import("mods/declarations/guard.lua")

local offerProfilesValidator = {}

local KNOWN_PROFILE_KINDS = {
    branch = true,
    shop = true,
    storeChoice = true,
}

local function validateStores(stores, rewards, context)
    guard.expectNonEmptyArray(stores, context)
    for index, storeKey in ipairs(stores) do
        guard.expectString(storeKey, context .. "[" .. tostring(index) .. "]")
        if rewards.stores[storeKey] == nil then
            guard.fail(context .. "[" .. tostring(index) .. "]", "unknown reward store '" .. storeKey .. "'")
        end
    end
end

local function validateRewardFilter(rewardFilter, rewards, context)
    if rewardFilter == nil then
        return
    end
    guard.expectNonEmptyArray(rewardFilter, context)
    for index, rewardType in ipairs(rewardFilter) do
        guard.expectString(rewardType, context .. "[" .. tostring(index) .. "]")
        if rewards.primitives[rewardType] == nil then
            guard.fail(context .. "[" .. tostring(index) .. "]", "unknown reward type '" .. rewardType .. "'")
        end
    end
end

local function validateStoreChoiceFilters(profile, rewards, context)
    if profile.eligibleRewards ~= nil and profile.ineligibleRewards ~= nil then
        guard.fail(context, "storeChoice profile must not define both eligibleRewards and ineligibleRewards")
    end

    validateRewardFilter(profile.eligibleRewards, rewards, context .. ".eligibleRewards")
    validateRewardFilter(profile.ineligibleRewards, rewards, context .. ".ineligibleRewards")
end

local function validateBranch(branch, offerProfiles, rewards, context)
    guard.expectTable(branch, context)
    guard.expectString(branch.key, context .. ".key")
    if branch.offerProfile ~= nil then
        guard.expectString(branch.offerProfile, context .. ".offerProfile")
        if offerProfiles[branch.offerProfile] == nil then
            guard.fail(context .. ".offerProfile", "unknown offer profile '" .. branch.offerProfile .. "'")
        end
    end
    if branch.stores ~= nil then
        validateStores(branch.stores, rewards, context .. ".stores")
    end
    if branch.offerProfile == nil and branch.stores == nil then
        guard.fail(context, "branch must define offerProfile or stores")
    end
end

function offerProfilesValidator.validate(offerProfiles, rewards)
    guard.expectTable(offerProfiles, "offerProfiles")

    for key, profile in pairs(offerProfiles) do
        local context = "offerProfiles." .. key
        guard.expectTable(profile, context)
        guard.expectString(profile.key, context .. ".key")
        if profile.key ~= key then
            guard.fail(context .. ".key", "offer profile key must match map key")
        end
        guard.expectString(profile.label, context .. ".label")
        local kind = guard.expectString(profile.kind, context .. ".kind")
        if not KNOWN_PROFILE_KINDS[kind] then
            guard.fail(context .. ".kind", "unknown offer profile kind '" .. kind .. "'")
        end

        if kind == "storeChoice" then
            validateStores(profile.stores, rewards, context .. ".stores")
            validateStoreChoiceFilters(profile, rewards, context)
        elseif kind == "shop" then
            guard.expectString(profile.shopKey, context .. ".shopKey")
            if rewards.shops[profile.shopKey] == nil then
                guard.fail(context .. ".shopKey", "unknown shop profile '" .. profile.shopKey .. "'")
            end
        elseif kind == "branch" then
            guard.expectNonEmptyArray(profile.branches, context .. ".branches")
            for index, branch in ipairs(profile.branches) do
                validateBranch(branch, offerProfiles, rewards, context .. ".branches[" .. tostring(index) .. "]")
            end
        end
    end

    return offerProfiles
end

return offerProfilesValidator
