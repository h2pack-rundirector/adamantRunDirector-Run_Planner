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
    local sourceCount = math.floor(tonumber(context.sourceCount) or 0)
    if sourceCount <= 1 then
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

    for sourceIndex = 1, sourceCount do
        controls[#controls + 1] = common.dropdown(
            storage.rewardAlias(sourceIndex),
            "Cage" .. tostring(sourceIndex),
            "Cage " .. tostring(sourceIndex),
            rewardValues,
            rewardLabels,
            {
                kind = "rewardType",
                controlWidth = 170,
                rowIndex = sourceIndex,
                sourceIndex = sourceIndex,
            }
        )
        controls[#controls + 1] = common.dropdown(
            storage.lootAlias(sourceIndex),
            "Cage" .. tostring(sourceIndex) .. "Loot",
            "God",
            godValues,
            godLabels,
            {
                kind = "boonSource",
                controlWidth = 170,
                rowIndex = sourceIndex,
                sourceIndex = sourceIndex,
                visibleWhen = {
                    alias = storage.rewardAlias(sourceIndex),
                    value = "Boon",
                },
            }
        )
    end

    return {
        kind = "fieldsCages",
        context = context,
        rewardStore = rewardStore,
        sourceCount = sourceCount,
        rewardConstraints = constraints.fieldsCages(sourceCount),
        controls = controls,
    }
end

return fieldsCages
