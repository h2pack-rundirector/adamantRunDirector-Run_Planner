local deps = ... or {}

local rewardDomain = deps.rewardDomain or {}

local rewardCandidates = {}

local EMPTY_LIST = {}
local MAJOR_REWARD_STORE = "RunProgress"
local MINOR_REWARD_STORE = "MetaProgress"

local function copyList(source)
    if source == nil then
        return nil
    end
    local copy = {}
    for index, value in ipairs(source) do
        copy[index] = value
    end
    return copy
end

local function lookupList(values)
    if values == nil then
        return nil
    end
    local lookup = {}
    for _, value in ipairs(values) do
        lookup[value] = true
    end
    return lookup
end

local function storeOptions(rewardStore, eligibleTypes, ineligibleTypes)
    local store = rewardDomain.rewardStores and rewardDomain.rewardStores[rewardStore] or nil
    local eligible = lookupList(eligibleTypes)
    local ineligible = lookupList(ineligibleTypes)
    local options = {}
    for _, rewardType in ipairs(store and store.options or EMPTY_LIST) do
        if (eligible == nil or eligible[rewardType])
            and (ineligible == nil or not ineligible[rewardType])
        then
            options[#options + 1] = rewardType
        end
    end
    return options
end

local function appendStoreCandidate(candidates, context)
    candidates[#candidates + 1] = {
        kind = "rewardType",
        address = context.address or "row",
        rewardStore = context.rewardStore,
        rewardTypes = storeOptions(
            context.rewardStore,
            context.eligibleRewardTypes,
            context.ineligibleRewardTypes
        ),
        eligibleRewardTypes = copyList(context.eligibleRewardTypes),
        ineligibleRewardTypes = copyList(context.ineligibleRewardTypes),
    }
end

local function appendMajorMinorCandidates(candidates, context)
    local majorRewardStore = context.majorRewardStore or MAJOR_REWARD_STORE
    local minorRewardStore = context.minorRewardStore or MINOR_REWARD_STORE
    local majorIneligible = copyList(context.majorIneligibleRewardTypes or context.ineligibleRewardTypes)
    if context.allowDevotion ~= true then
        majorIneligible = majorIneligible or {}
        majorIneligible[#majorIneligible + 1] = "Devotion"
    end
    candidates[#candidates + 1] = {
        kind = "rewardType",
        address = context.address or "row",
        rewardClass = "Major",
        rewardStore = majorRewardStore,
        rewardTypes = storeOptions(
            majorRewardStore,
            context.majorEligibleRewardTypes or context.eligibleRewardTypes,
            majorIneligible
        ),
        eligibleRewardTypes = copyList(context.majorEligibleRewardTypes or context.eligibleRewardTypes),
        ineligibleRewardTypes = majorIneligible,
    }
    candidates[#candidates + 1] = {
        kind = "rewardType",
        address = context.address or "row",
        rewardClass = "Minor",
        rewardStore = minorRewardStore,
        rewardTypes = storeOptions(
            minorRewardStore,
            context.minorEligibleRewardTypes,
            context.minorIneligibleRewardTypes
        ),
        eligibleRewardTypes = copyList(context.minorEligibleRewardTypes),
        ineligibleRewardTypes = copyList(context.minorIneligibleRewardTypes),
    }
end

local function appendPrebossCandidates(candidates, context)
    for _, offer in ipairs(context.offers or EMPTY_LIST) do
        if offer.kind == "roomStore" then
            appendStoreCandidate(candidates, offer)
        elseif offer.kind == "shop" then
            candidates[#candidates + 1] = {
                kind = "shop",
                address = offer.address,
                shopProfile = offer.shopProfile,
            }
        end
    end
end

function rewardCandidates.forContext(context, opts)
    opts = opts or {}
    local candidates = {}
    if context == nil or context.kind == nil or context.kind == "none" then
        return candidates
    elseif context.kind == "majorMinor" then
        appendMajorMinorCandidates(candidates, context)
    elseif context.kind == "roomStore" then
        appendStoreCandidate(candidates, context)
    elseif context.kind == "fieldsCages" then
        for index = 1, math.floor(tonumber(opts.sourceCount) or 0) do
            appendStoreCandidate(candidates, {
                address = "cage:" .. tostring(index),
                rewardStore = context.rewardStore,
                eligibleRewardTypes = context.eligibleRewardTypes,
                ineligibleRewardTypes = context.ineligibleRewardTypes,
            })
        end
    elseif context.kind == "preboss" then
        appendPrebossCandidates(candidates, context)
    elseif context.kind == "shop" then
        candidates[#candidates + 1] = {
            kind = "shop",
            address = context.address or "row",
            shopProfile = context.shopProfile,
        }
    elseif context.kind == "forcedReward" then
        candidates[#candidates + 1] = {
            kind = "fixedReward",
            address = context.address or "row",
            rewardStore = context.rewardStore,
            rewardTypes = { context.rewardType },
        }
    end
    return candidates
end

return rewardCandidates
