local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local constraints = deps.constraints or import("mods/rewards/declarations/constraints.lua")
local storage = common.storage

local majorMinor = {}

function majorMinor.create(rewardDomain, context)
    local majorRewardStore = context.majorRewardStore or "RunProgress"
    local minorRewardStore = context.minorRewardStore or "MetaProgress"
    local majorEligible = common.rewardTypeLookup(
        context.majorEligibleRewardTypes or context.eligibleRewardTypes
    )
    local majorIneligible = common.rewardTypeLookup(
        context.majorIneligibleRewardTypes or context.ineligibleRewardTypes
    )
    if context.allowDevotion ~= true then
        majorIneligible = majorIneligible or {}
        majorIneligible.Devotion = true
    end
    local minorEligible = common.rewardTypeLookup(
        context.minorEligibleRewardTypes
    )
    local minorIneligible = common.rewardTypeLookup(
        context.minorIneligibleRewardTypes
    )
    local majorValues, majorLabels = common.uniqueNames(
        common.optionsFor(rewardDomain, majorRewardStore),
        majorEligible,
        majorIneligible,
        function(name)
            return common.rewardOptionLabel(rewardDomain, name)
        end
    )
    local minorValues, minorLabels = common.uniqueNames(
        common.optionsFor(rewardDomain, minorRewardStore),
        minorEligible,
        minorIneligible,
        function(name)
            return common.rewardOptionLabel(rewardDomain, name)
        end
    )
    local godValues, godLabels = common.godSourceOptions(rewardDomain)
    local rewardClassValues = { common.MAJOR_VALUE, common.MINOR_VALUE }
    local rewardClassLabels = {
        [common.MAJOR_VALUE] = common.optionsLabel(rewardDomain, majorRewardStore, common.MAJOR_VALUE),
        [common.MINOR_VALUE] = common.optionsLabel(rewardDomain, minorRewardStore, common.MINOR_VALUE),
    }

    return {
        kind = "majorMinor",
        context = context,
        majorRewardStore = majorRewardStore,
        minorRewardStore = minorRewardStore,
        rewardConstraints = constraints.devotionPair(),
        controls = {
            common.dropdown(storage.rewardAlias(1), "rewardClass", "Reward", rewardClassValues, rewardClassLabels, {
                kind = "rewardClass",
                controlWidth = 110,
            }),
            common.dropdown(storage.rewardAlias(2), "rewardType", "", majorValues, majorLabels, {
                kind = "rewardType",
                controlWidth = 170,
                rewardStore = majorRewardStore,
                visibleWhen = { alias = storage.rewardAlias(1), value = common.MAJOR_VALUE },
            }),
            common.dropdown(storage.rewardAlias(3), "boonSource", "God", godValues, godLabels, {
                kind = "boonSource",
                controlWidth = 170,
                visibleWhen = {
                    all = {
                        { alias = storage.rewardAlias(1), value = common.MAJOR_VALUE },
                        { alias = storage.rewardAlias(2), value = "Boon" },
                    },
                },
            }),
            common.dropdown(storage.rewardAlias(4), "rewardType", "", minorValues, minorLabels, {
                kind = "rewardType",
                controlWidth = 170,
                rewardStore = minorRewardStore,
                visibleWhen = { alias = storage.rewardAlias(1), value = common.MINOR_VALUE },
            }),
            common.dropdown(storage.rewardAlias(5), "lootAName", "God A", godValues, godLabels, {
                kind = "boonSource",
                controlWidth = 170,
                visibleWhen = {
                    all = {
                        { alias = storage.rewardAlias(1), value = common.MAJOR_VALUE },
                        { alias = storage.rewardAlias(2), value = "Devotion" },
                    },
                },
            }),
            common.dropdown(storage.rewardAlias(6), "lootBName", "God B", godValues, godLabels, {
                kind = "boonSource",
                controlWidth = 170,
                visibleWhen = {
                    all = {
                        { alias = storage.rewardAlias(1), value = common.MAJOR_VALUE },
                        { alias = storage.rewardAlias(2), value = "Devotion" },
                    },
                },
            }),
        },
    }
end

return majorMinor
