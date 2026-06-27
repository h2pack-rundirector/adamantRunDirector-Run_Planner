local function entryRewardType(entry)
    if type(entry) == "table" then
        return entry.rewardType
    end
    return entry
end

local function storeFromBag(bag)
    local seen = {}
    local options = {}
    for _, item in ipairs(bag or {}) do
        local rewardType = entryRewardType(item)
        if rewardType ~= nil and not seen[rewardType] then
            seen[rewardType] = true
            options[#options + 1] = rewardType
        end
    end
    return {
        label = bag.label,
        options = options,
    }
end

local function storesFromBags(rewardBags)
    local stores = {}
    for storeKey, bag in pairs(rewardBags) do
        stores[storeKey] = storeFromBag(bag)
    end
    return stores
end

local rewardBags = {
    RunProgress = {
        label = "Major",
        refill = "appendWhenNoEligibleEntry",
        "Boon",
        "Boon",
        "Boon",
        "Boon",
        "HermesUpgrade",
        "Devotion",
        "WeaponUpgrade",
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxHealthDrop",
        "MaxManaDrop",
        "MaxManaDrop",
        "RoomMoneyDrop",
        "RoomMoneyDrop",
        "StackUpgrade",
        "StackUpgrade",
        "SpellDrop",
        "TalentDrop",
    },
    MetaProgress = {
        label = "Minor",
        refill = "appendWhenNoEligibleEntry",
        "GiftDrop",
        "MetaCurrencyDrop",
        "MetaCurrencyDrop",
        "MetaCurrencyDrop",
        "MetaCurrencyDrop",
        "MetaCurrencyBigDrop",
        "MetaCurrencyBigDrop",
        "MetaCurrencyBigDrop",
        "MetaCurrencyBigDrop",
        "MetaCardPointsCommonDrop",
        "MetaCardPointsCommonDrop",
        "MetaCardPointsCommonBigDrop",
        "MetaCardPointsCommonBigDrop",
    },
    HubRewards = {
        refill = "appendWhenNoEligibleEntry",
        "Boon",
        "Boon",
        "Boon",
        "Boon",
        "Boon",
        "HermesUpgrade",
        "WeaponUpgrade",
        "MaxHealthDropBig",
        "MaxManaDropBig",
        "SpellDrop",
    },
    SubRoomRewards = {
        refill = "appendWhenNoEligibleEntry",
        "MaxManaDropSmall",
        "MaxHealthDropSmall",
        "EmptyMaxHealthSmallDrop",
        "RoomMoneyTinyDrop",
        "AirBoost",
        "EarthBoost",
        "FireBoost",
        "WaterBoost",
        "GiftDrop",
        "MetaCurrencyDrop",
        "MetaCurrencyDrop",
        "MetaCardPointsCommonDrop",
        "MetaCardPointsCommonDrop",
        "MaxHealthDrop",
        "MaxHealthDrop",
        "MaxManaDrop",
        "MaxManaDrop",
        "StackUpgrade",
        "StackUpgrade",
        "RoomMoneyDrop",
        "RoomMoneyDrop",
        "MinorTalentDrop",
        "MinorTalentDrop",
    },
    SubRoomRewardsHard = {
        refill = "appendWhenNoEligibleEntry",
        "MaxHealthDrop",
        "MaxHealthDrop",
        "MaxManaDrop",
        "MaxManaDrop",
        "StackUpgrade",
        "StackUpgrade",
        "RoomMoneyDrop",
        "RoomMoneyDrop",
    },
    TartarusRewards = {
        refill = "appendWhenNoEligibleEntry",
        "Boon",
        "Boon",
        "Boon",
        "WeaponUpgrade",
        "WeaponUpgrade",
        "Devotion",
        "StackUpgradeTriple",
        "TalentBigDrop",
        "RoomMoneyTripleDrop",
    },
    TyphonBossRewards = {
        refill = "appendWhenNoEligibleEntry",
        "Boon",
        "Boon",
        "TalentBigDrop",
        "StackUpgradeTriple",
        "WeaponUpgrade",
        "WeaponUpgrade",
    },
}

return {
    rewardBags = rewardBags,
    rewardStores = storesFromBags(rewardBags),
}
