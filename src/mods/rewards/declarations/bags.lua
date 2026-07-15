local function entry(rewardType, requirementKey)
    return {
        rewardType = rewardType,
        requirementKey = requirementKey,
    }
end

return {
    RunProgress = {
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
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("Boon"), entry("Boon"), entry("Boon"), entry("Boon"), entry("Boon"),
            entry("HermesUpgrade"), entry("WeaponUpgrade"), entry("MaxHealthDropBig"),
            entry("MaxManaDropBig"), entry("SpellDrop"),
        },
    },
    SubRoomRewards = {
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
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("MaxHealthDrop"), entry("MaxHealthDrop"), entry("MaxManaDrop"), entry("MaxManaDrop"),
            entry("StackUpgrade"), entry("StackUpgrade"), entry("RoomMoneyDrop"), entry("RoomMoneyDrop"),
        },
    },
    TartarusRewards = {
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
        refill = "appendWhenNoEligibleEntry",
        entries = {
            entry("Boon"), entry("Boon"), entry("TalentBigDrop"), entry("StackUpgradeTriple"),
            entry("WeaponUpgrade", "HammerLootRequirements"),
            entry("WeaponUpgrade", "LateHammerLootRequirements"),
        },
    },
}
