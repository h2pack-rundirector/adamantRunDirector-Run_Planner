local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local storage = common.storage

local roomStore = {}

function roomStore.create(definitions, context)
    local rewardStore = context.rewardStore or "RunProgress"
    local rewardTypes = common.bundleOptions(definitions, rewardStore)
    local eligible = common.lookupList(context.eligibleRewardTypes)
    local ineligible = common.lookupList(context.ineligibleRewardTypes)

    if common.isOnlyEligible(context.eligibleRewardTypes, "Boon")
        and (ineligible == nil or not ineligible.Boon)
    then
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

    local rewardValues, rewardLabels = common.uniqueNames(rewardTypes, eligible, ineligible, function(name)
        return common.rewardOptionLabel(definitions, name)
    end)
    local godValues, godLabels = common.godSourceOptions(definitions)
    return {
        kind = "roomStore",
        context = context,
        rewardStore = rewardStore,
        controls = {
            common.dropdown(storage.rewardAlias(1), "rewardType", "Reward", rewardValues, rewardLabels, {
                kind = "rewardType",
                controlWidth = 170,
            }),
            common.dropdown(storage.rewardAlias(2), "boonSource", "God", godValues, godLabels, {
                kind = "boonSource",
                controlWidth = 170,
                visibleWhen = { alias = storage.rewardAlias(1), value = "Boon" },
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

return roomStore
