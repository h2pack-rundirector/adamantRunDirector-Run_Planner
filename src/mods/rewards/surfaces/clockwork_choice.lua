local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local constraints = deps.constraints or import("mods/rewards/declarations/constraints.lua")
local storage = common.storage

local clockworkChoice = {}

local function rewardOptions(definitions, context)
    local rewardStore = context.rewardStore or "TartarusRewards"
    local rewardTypes = common.optionsFor(definitions, rewardStore)
    local eligible = common.rewardTypeLookup(definitions, context.eligibleRewardTypes, context.eligibleRewardSet)
    local ineligible = common.rewardTypeLookup(definitions, context.ineligibleRewardTypes, context.ineligibleRewardSet)
    local values, labels = common.uniqueNames(rewardTypes, eligible, ineligible, function(name)
        return common.rewardOptionLabel(definitions, name)
    end)
    table.insert(values, 2, context.goalRewardType)
    labels[context.goalRewardType] = common.rewardOptionLabel(definitions, context.goalRewardType)
    return values, labels
end

function clockworkChoice.create(definitions, context)
    local rewardValues, rewardLabels = rewardOptions(definitions, context)
    local godValues, godLabels = common.godSourceOptions(definitions)
    return {
        kind = "roomStore",
        context = context,
        rewardStore = context.rewardStore or "TartarusRewards",
        rewardConstraints = constraints.devotionPair(),
        controls = {
            common.dropdown(storage.rewardAlias(1), "rewardType", "Reward", rewardValues, rewardLabels, {
                kind = "rewardType",
                controlWidth = 170,
            }),
            common.dropdown(storage.rewardAlias(3), "lootAName", "God A", godValues, godLabels, {
                kind = "boonSource",
                controlWidth = 170,
                visibleWhen = { alias = storage.rewardAlias(1), value = "Devotion" },
            }),
            common.dropdown(storage.rewardAlias(4), "lootBName", "God B", godValues, godLabels, {
                kind = "boonSource",
                controlWidth = 170,
                visibleWhen = { alias = storage.rewardAlias(1), value = "Devotion" },
            }),
        },
    }
end

return clockworkChoice
