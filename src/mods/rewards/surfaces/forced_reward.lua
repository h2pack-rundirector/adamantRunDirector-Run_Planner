local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local constraints = deps.constraints or import("mods/rewards/declarations/constraints.lua")
local storage = common.storage

local forcedReward = {}

function forcedReward.create(rewardDomain, context)
    if context.rewardType == "Devotion" then
        local values, labels = common.godSourceOptions(rewardDomain)
        return {
            kind = "devotionPair",
            context = context,
            fixedRewardType = "Devotion",
            rewardConstraints = constraints.devotionPair(),
            controls = {
                common.dropdown(storage.rewardAlias(1), "lootAName", "God A", values, labels, {
                    kind = "boonSource",
                    controlWidth = 150,
                    rowIndex = 1,
                }),
                common.dropdown(storage.rewardAlias(2), "lootBName", "God B", values, labels, {
                    kind = "boonSource",
                    controlWidth = 150,
                    rowIndex = 2,
                }),
            },
        }
    end

    if context.rewardType == "Boon" then
        local values, labels = common.godSourceOptions(rewardDomain)
        return {
            kind = "boonSource",
            context = context,
            fixedRewardType = "Boon",
            controls = {
                common.dropdown(storage.rewardAlias(1), "boonSource", "", values, labels, {
                    kind = "boonSource",
                    controlWidth = 170,
                }),
            },
        }
    end

    return {
        kind = "fixedReward",
        context = context,
        fixedRewardType = context.rewardType,
        displayLabel = common.rewardOptionLabel(rewardDomain, context.rewardType),
        controls = {},
    }
end

return forcedReward
