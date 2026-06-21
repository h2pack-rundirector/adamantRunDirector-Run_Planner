local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local storage = common.storage

local forcedReward = {}

function forcedReward.create(definitions, context)
    if context.rewardType == "Devotion" then
        local values, labels = common.godSourceOptions(definitions)
        return {
            kind = "devotionPair",
            context = context,
            fixedRewardType = "Devotion",
            uniqueValueGroups = {
                {
                    aliases = {
                        storage.rewardAlias(1),
                        storage.rewardAlias(2),
                    },
                    code = "duplicate_devotion_god",
                    message = "Trial gods must be different",
                },
            },
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
        local values, labels = common.godSourceOptions(definitions)
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
        controls = {},
    }
end

return forcedReward
