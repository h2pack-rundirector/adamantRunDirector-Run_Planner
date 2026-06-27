local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local rewardConstraints = deps.constraints or import("mods/rewards/declarations/constraints.lua")
local storage = common.storage

local shopSurface = {}

local SHOP_BOON_SOURCE_VALUES = {
    RandomLoot = true,
    BoostedRandomLoot = true,
}

local function resolveRewardConstraints(context, sourceIndexBySlotKey)
    local constraints = {}
    for _, group in ipairs(rewardConstraints.shopProfile(context.shopProfile)) do
        local sourceIndices = {}
        for _, slotKey in ipairs(group.slots or {}) do
            local sourceIndex = sourceIndexBySlotKey[slotKey]
            if sourceIndex ~= nil then
                sourceIndices[#sourceIndices + 1] = sourceIndex
            end
        end
        if sourceIndices[2] ~= nil then
            constraints[#constraints + 1] = {
                kind = group.kind or "uniqueRewardTypes",
                sourceIndices = sourceIndices,
                allow = group.allow,
                code = group.code,
                message = group.message,
            }
        end
    end
    return constraints
end

function shopSurface.create(rewardDomain, context)
    local shop = rewardDomain.shops[context.shopProfile] or {}
    local controls = {}
    local godValues, godLabels = common.godSourceOptions(rewardDomain)
    local sourceIndexBySlotKey = {}

    for index, slot in ipairs(shop.slots or {}) do
        local rewardAlias = storage.rewardAlias(index)
        local lootAlias = storage.lootAlias(index)
        sourceIndexBySlotKey[slot.key] = index
        local options = slot.options or common.optionsFor(rewardDomain, slot.optionSet)
        local values, labels = common.uniqueNames(options, nil, nil, function(name)
            return common.rewardOptionLabel(rewardDomain, name)
        end)
        controls[#controls + 1] = common.dropdown(
            rewardAlias,
            slot.key,
            slot.label,
            values,
            labels,
            {
                kind = "shopOption",
                controlWidth = 170,
                labelWidth = 130,
                rowIndex = index,
            }
        )
        for _, itemName in ipairs(options) do
            if SHOP_BOON_SOURCE_VALUES[itemName] then
                controls[#controls + 1] = common.dropdown(
                    lootAlias,
                    slot.key .. "Loot",
                    "God",
                    godValues,
                    godLabels,
                    {
                        kind = "boonSource",
                        controlWidth = 170,
                        labelWidth = 45,
                        rowIndex = index,
                        visibleWhen = {
                            any = {
                                { alias = rewardAlias, value = "RandomLoot" },
                                { alias = rewardAlias, value = "BoostedRandomLoot" },
                            },
                        },
                    }
                )
                break
            end
        end
    end

    return {
        kind = "shop",
        context = context,
        shopProfile = context.shopProfile,
        rowHeader = "Reward",
        rewardConstraints = resolveRewardConstraints(context, sourceIndexBySlotKey),
        controls = controls,
    }
end

return shopSurface
