local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local rewardConstraints = deps.constraints or import("mods/rewards/declarations/constraints.lua")
local storage = common.storage

local prebossSurface = {}

local SHOP_BOON_SOURCE_VALUES = {
    RandomLoot = true,
    BoostedRandomLoot = true,
}
local PREBOSS_BRANCH_VALUES = { "Shop", "FreeReward" }
local PREBOSS_BRANCH_LABELS = {
    Shop = "Shop",
    FreeReward = "Free Reward",
}

local function branchVisibleWhen(offer)
    return {
        alias = storage.PREBOSS_BRANCH_ALIAS,
        value = offer.requiredBranchValue,
    }
end

local function rewardAliasForOffer(offer, offset)
    return storage.rewardAlias(offer.rewardAliasStart + offset - 1)
end

local function stateAliasForOffer(offer, offset)
    return storage.stateAlias(offer.rewardAliasStart + offset - 1)
end

local function lootAliasForOffer(offer, offset)
    return storage.lootAlias(offer.rewardAliasStart + offset - 1)
end

local function offerByKind(context, kind)
    for _, offer in ipairs(context.offers) do
        if offer.kind == kind then
            return offer
        end
    end
    return nil
end

local function resolveRewardConstraints(shopOffer, sourceIndexBySlotKey)
    local constraints = {}
    for _, group in ipairs(rewardConstraints.shopProfile(shopOffer.shopProfile)) do
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

local function appendShopControls(rewardDomain, offer, controls, godValues, godLabels)
    local shop = rewardDomain.shops[offer.shopProfile] or {}
    local sourceIndexBySlotKey = {}
    local visibleWhen = branchVisibleWhen(offer)

    for index, slot in ipairs(shop.slots or {}) do
        local rewardAlias = rewardAliasForOffer(offer, index)
        local lootAlias = lootAliasForOffer(offer, index)
        local stateAlias = stateAliasForOffer(offer, index)
        sourceIndexBySlotKey[slot.key] = index
        local options = slot.options or common.optionsFor(rewardDomain, slot.optionSet)
        local values, labels = common.uniqueNames(options, nil, nil, function(name)
            return common.rewardOptionLabel(rewardDomain, name)
        end)
        controls[#controls + 1] = common.shopPurchaseCheckbox(stateAlias, index, {
            prefixLabel = slot.label,
            rowIndex = index,
            rewardAddress = offer.address,
            visibleWhen = visibleWhen,
        })
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
                drawLabel = "",
                rowIndex = index,
                rewardAddress = offer.address,
                visibleWhen = visibleWhen,
            }
        )
        for _, itemName in ipairs(options) do
            if SHOP_BOON_SOURCE_VALUES[itemName] then
                local lootVisibleWhen = {
                    all = {
                        visibleWhen,
                        {
                            any = {
                                { alias = rewardAlias, value = "RandomLoot" },
                                { alias = rewardAlias, value = "BoostedRandomLoot" },
                            },
                        },
                    },
                }
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
                        rewardAddress = offer.address,
                        visibleWhen = lootVisibleWhen,
                    }
                )
                break
            end
        end
    end

    return sourceIndexBySlotKey
end

local function appendPrebossRewardControls(rewardDomain, offer, controls, godValues, godLabels)
    local rewardAlias = rewardAliasForOffer(offer, 1)
    local lootAlias = rewardAliasForOffer(offer, 2)
    local visibleWhen = branchVisibleWhen(offer)
    local rewardTypes = common.optionsFor(rewardDomain, offer.rewardStore)
    local eligible = common.rewardTypeLookup(offer.eligibleRewardTypes)
    local ineligible = common.rewardTypeLookup(offer.ineligibleRewardTypes)
    local rewardValues, rewardLabels = common.uniqueNames(rewardTypes, eligible, ineligible, function(name)
        return common.rewardOptionLabel(rewardDomain, name)
    end)

    controls[#controls + 1] = common.dropdown(
        rewardAlias,
        "rewardType",
        "Free Reward",
        rewardValues,
        rewardLabels,
        {
            kind = "rewardType",
            controlWidth = 170,
            labelWidth = 130,
            rowIndex = offer.rewardAliasStart,
            rewardAddress = offer.address,
            visibleWhen = visibleWhen,
        }
    )
    controls[#controls + 1] = common.dropdown(
        lootAlias,
        "boonSource",
        "God",
        godValues,
        godLabels,
        {
            kind = "boonSource",
            controlWidth = 170,
            labelWidth = 45,
            rowIndex = offer.rewardAliasStart,
            rewardAddress = offer.address,
            visibleWhen = {
                all = {
                    visibleWhen,
                    {
                        alias = rewardAlias,
                        value = "Boon",
                    },
                },
            },
        }
    )
end

local function appendBranchControls(controls)
    controls[#controls + 1] = common.dropdown(
        storage.PREBOSS_BRANCH_ALIAS,
        "prebossBranch",
        "Branch",
        PREBOSS_BRANCH_VALUES,
        PREBOSS_BRANCH_LABELS,
        {
            kind = "prebossBranch",
            controlWidth = 140,
            labelWidth = 130,
            rowIndex = 0,
            rewardAddress = "prebossBranch",
        }
    )
end

function prebossSurface.create(rewardDomain, context)
    local controls = {}
    local godValues, godLabels = common.godSourceOptions(rewardDomain)
    local shopOffer = offerByKind(context, "shop")
    local rewardOffer = offerByKind(context, "roomStore")
    appendBranchControls(controls)
    local sourceIndexBySlotKey = appendShopControls(rewardDomain, shopOffer, controls, godValues, godLabels)
    appendPrebossRewardControls(rewardDomain, rewardOffer, controls, godValues, godLabels)

    return {
        kind = "preboss",
        context = context,
        offers = context.offers,
        rewardStore = rewardOffer.rewardStore,
        rowHeader = "Reward",
        rewardConstraints = resolveRewardConstraints(shopOffer, sourceIndexBySlotKey),
        controls = controls,
    }
end

return prebossSurface
