local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local storage = common.storage

local shopSurface = {}

local SHOP_BOON_SOURCE_VALUES = {
    RandomLoot = true,
    BoostedRandomLoot = true,
}

local function uniqueValueGroups(shop, aliasBySlotKey)
    local groups = {}
    for _, group in ipairs(shop.uniqueOfferGroups or {}) do
        local aliases = {}
        for _, slotKey in ipairs(group.slots or {}) do
            local alias = aliasBySlotKey[slotKey]
            if alias ~= nil then
                aliases[#aliases + 1] = alias
            end
        end
        if aliases[2] ~= nil then
            groups[#groups + 1] = {
                aliases = aliases,
                code = group.code,
                message = group.message,
            }
        end
    end
    return groups
end

function shopSurface.create(definitions, context)
    local shop = definitions.shops[context.shopProfile] or {}
    local controls = {}
    local godValues, godLabels = common.godSourceOptions(definitions)
    local aliasBySlotKey = {}

    for index, slot in ipairs(shop.slots or {}) do
        local rewardAlias = storage.rewardAlias(index)
        local lootAlias = storage.lootAlias(index)
        aliasBySlotKey[slot.key] = rewardAlias
        local options = slot.options or common.bundleOptions(definitions, slot.bundle)
        local values, labels = common.uniqueNames(options, nil, nil, function(name)
            return common.rewardOptionLabel(definitions, name)
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
        uniqueValueGroups = uniqueValueGroups(shop, aliasBySlotKey),
        controls = controls,
    }
end

return shopSurface
