local deps = ... or {}
local roomStore = deps.roomStore or import("mods/rewards/surfaces/room_store.lua", nil, {
    common = deps.common,
    constraints = deps.constraints,
})
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local constraints = deps.constraints or import("mods/rewards/declarations/constraints.lua")
local storage = common.storage

local fieldsCages = {}

function fieldsCages.create(rewardDomain, context)
    local sameExitRewardCount = math.floor(tonumber(context.sameExitRewardCount) or 0)
    if sameExitRewardCount <= 1 then
        return roomStore.create(rewardDomain, context)
    end

    local rewardStore = context.rewardStore or "RunProgress"
    local rewardTypes = common.optionsFor(rewardDomain, rewardStore)
    local eligible = common.rewardTypeLookup(context.eligibleRewardTypes)
    local ineligible = common.rewardTypeLookup(context.ineligibleRewardTypes)
    local rewardValues, rewardLabels = common.uniqueNames(rewardTypes, eligible, ineligible, function(name)
        return common.rewardOptionLabel(rewardDomain, name)
    end)
    local godValues, godLabels = common.godSourceOptions(rewardDomain)
    local controls = {}

    for sameExitRewardIndex = 1, sameExitRewardCount do
        controls[#controls + 1] = common.dropdown(
            storage.rewardAlias(sameExitRewardIndex),
            "Cage" .. tostring(sameExitRewardIndex),
            "Cage " .. tostring(sameExitRewardIndex),
            rewardValues,
            rewardLabels,
            {
                kind = "rewardType",
                controlWidth = 170,
                rowIndex = sameExitRewardIndex,
                sameExitRewardIndex = sameExitRewardIndex,
            }
        )
        controls[#controls + 1] = common.dropdown(
            storage.lootAlias(sameExitRewardIndex),
            "Cage" .. tostring(sameExitRewardIndex) .. "Loot",
            "God",
            godValues,
            godLabels,
            {
                kind = "boonSource",
                controlWidth = 170,
                rowIndex = sameExitRewardIndex,
                sameExitRewardIndex = sameExitRewardIndex,
                visibleWhen = {
                    alias = storage.rewardAlias(sameExitRewardIndex),
                    value = "Boon",
                },
            }
        )
    end

    return {
        kind = "fieldsCages",
        context = context,
        rewardStore = rewardStore,
        sameExitRewardCount = sameExitRewardCount,
        rewardConstraints = constraints.fieldsCages(sameExitRewardCount),
        controls = controls,
    }
end

return fieldsCages
