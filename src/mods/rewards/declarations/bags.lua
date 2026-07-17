local function entry(rewardType, requirementKey)
    return {
        rewardType = rewardType,
        requirementKey = requirementKey,
    }
end

return {
    RunProgress = {
        defaultRewardType = "Boon",
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("Boon"), entry("Boon"), entry("Boon"), entry("Boon"),
            entry("HermesUpgrade"),
            entry("Devotion", "DevotionLootRequirements"),
            entry("WeaponUpgrade", "HammerLootRequirements"),
            entry("WeaponUpgrade", "LateHammerLootRequirements"),
            entry("MaxHealthDrop"), entry("MaxHealthDrop"),
            entry("MaxManaDrop"), entry("MaxManaDrop"),
            entry("RoomMoneyDrop"), entry("RoomMoneyDrop"),
            entry("StackUpgrade"), entry("StackUpgrade"),
            entry("SpellDrop"), entry("TalentDrop"),
        },
    },
    MetaProgress = {
        defaultRewardType = "GiftDrop",
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("GiftDrop"),
            entry("MetaCurrencyDrop"), entry("MetaCurrencyDrop"), entry("MetaCurrencyDrop"), entry("MetaCurrencyDrop"),
            entry("MetaCurrencyBigDrop"), entry("MetaCurrencyBigDrop"), entry("MetaCurrencyBigDrop"), entry("MetaCurrencyBigDrop"),
            entry("MetaCardPointsCommonDrop"), entry("MetaCardPointsCommonDrop"),
            entry("MetaCardPointsCommonBigDrop"), entry("MetaCardPointsCommonBigDrop"),
        },
    },
    HubRewards = {
        defaultRewardType = "Boon",
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("Boon"), entry("Boon"), entry("Boon"), entry("Boon"), entry("Boon"),
            entry("HermesUpgrade"), entry("WeaponUpgrade"), entry("MaxHealthDropBig"),
            entry("MaxManaDropBig"), entry("SpellDrop"),
        },
    },
    SubRoomRewards = {
        defaultRewardType = "MaxManaDropSmall",
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("MaxManaDropSmall"), entry("MaxHealthDropSmall"), entry("EmptyMaxHealthSmallDrop"),
            entry("RoomMoneyTinyDrop"), entry("AirBoost"), entry("EarthBoost"), entry("FireBoost"), entry("WaterBoost"),
            entry("GiftDrop"), entry("MetaCurrencyDrop"), entry("MetaCurrencyDrop"),
            entry("MetaCardPointsCommonDrop"), entry("MetaCardPointsCommonDrop"),
            entry("MaxHealthDrop"), entry("MaxHealthDrop"), entry("MaxManaDrop"), entry("MaxManaDrop"),
            entry("StackUpgrade"), entry("StackUpgrade"), entry("RoomMoneyDrop"), entry("RoomMoneyDrop"),
            entry("MinorTalentDrop"), entry("MinorTalentDrop"),
        },
    },
    SubRoomRewardsHard = {
        defaultRewardType = "MaxHealthDrop",
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("MaxHealthDrop"), entry("MaxHealthDrop"), entry("MaxManaDrop"), entry("MaxManaDrop"),
            entry("StackUpgrade"), entry("StackUpgrade"), entry("RoomMoneyDrop"), entry("RoomMoneyDrop"),
        },
    },
    TartarusRewards = {
        defaultRewardType = "Boon",
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("Boon"), entry("Boon"), entry("Boon"),
            entry("WeaponUpgrade", "HammerLootRequirements"),
            entry("WeaponUpgrade", "LateHammerLootRequirements"),
            entry("Devotion", "DevotionLootRequirements"),
            entry("StackUpgradeTriple"), entry("TalentBigDrop"), entry("RoomMoneyTripleDrop"),
        },
    },
    TyphonBossRewards = {
        defaultRewardType = "Boon",
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("Boon"), entry("Boon"), entry("TalentBigDrop"), entry("StackUpgradeTriple"),
            entry("WeaponUpgrade", "HammerLootRequirements"),
            entry("WeaponUpgrade", "LateHammerLootRequirements"),
        },
    },
}
