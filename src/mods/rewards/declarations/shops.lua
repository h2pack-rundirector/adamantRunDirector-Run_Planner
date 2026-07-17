local optionSets = {
    WorldShopBoon = { "RandomLoot", "BlindBoxLoot", "ShopHermesUpgrade" },
    WorldShopNonBoon = {
        "WeaponUpgradeDrop", "RoomRewardHealDrop", "MaxHealthDrop", "ArmorBoost",
        "MetaCardPointsCommonDrop", "MetaCurrencyDrop", "GiftDrop",
    },
    WorldShopMinor = { "MaxManaDrop", "StackUpgrade", "StoreRewardRandomStack", "SpellDrop", "TalentDrop" },
    TartarusShopPriorityPower = { "RandomLoot", "BoostedRandomLoot", "StackUpgradeBig" },
    TartarusShopMixedReward = {
        "RandomLoot", "BlindBoxLoot", "MaxHealthDrop", "MaxManaDrop", "StackUpgrade", "TalentDrop", "SpellDrop",
    },
    TartarusShopSurvival = { "RoomRewardHealDrop", "ArmorBoost", "HealBigDrop", "ArmorBigBoost", "LastStandDrop" },
    TartarusShopMajorPower = {
        "WeaponUpgradeDrop", "RandomLoot", "BlindBoxLoot", "ShopHermesUpgrade", "ChaosWeaponUpgrade",
        "BoostedRandomLoot", "MaxHealthDropBig", "MaxManaDropBig",
    },
    EndShopPrimaryPower = {
        "RandomLoot", "BlindBoxLoot", "StackUpgrade", "BoostedRandomLoot", "StackUpgradeBig",
        "MaxHealthDrop", "MaxManaDrop", "TalentDrop", "SpellDrop",
    },
    EndShopSecondaryReward = { "RandomLoot", "HealBigDrop", "ArmorBigBoost" },
    EndShopMajorPower = {
        "WeaponUpgradeDrop", "RandomLoot", "ShopHermesUpgrade", "ChaosWeaponUpgrade", "BoostedRandomLoot",
        "MaxHealthDropBig", "MaxManaDropBig",
    },
    EndShopResource = { "WeaponPointsRareDrop", "CardUpgradePointsDrop", "CharonPointsDrop" },
}

return {
    optionSets = optionSets,
    profiles = {
        WorldShop = {
            slots = {
                { key = "Boon", label = "Offer 1", optionSetKey = "WorldShopBoon" },
                { key = "MajorNonBoon", label = "Offer 2", optionSetKey = "WorldShopNonBoon" },
                { key = "Minor", label = "Offer 3", optionSetKey = "WorldShopMinor" },
            },
        },
        I_WorldShop = {
            slots = {
                { key = "Group1Offer1", label = "Offer 1", optionSetKey = "TartarusShopPriorityPower" },
                { key = "Group2Offer1", label = "Offer 2", optionSetKey = "TartarusShopMixedReward" },
                { key = "Group3Offer1", label = "Offer 3", optionSetKey = "TartarusShopSurvival" },
                { key = "Group4Offer1", label = "Offer 4", optionSetKey = "TartarusShopMajorPower" },
                { key = "Group5Offer1", label = "Offer 5", optionSetKey = "EndShopResource" },
            },
        },
        Q_WorldShop = {
            constraintKeys = { "QWorldShopPrimaryUnique" },
            slots = {
                { key = "Group1Offer1", label = "Offer 1", optionSetKey = "EndShopPrimaryPower", uniqueGroup = "Primary" },
                { key = "Group1Offer2", label = "Offer 2", optionSetKey = "EndShopPrimaryPower", uniqueGroup = "Primary" },
                { key = "Group2Offer1", label = "Offer 3", optionSetKey = "EndShopSecondaryReward" },
                { key = "Group3Offer1", label = "Offer 4", optionSetKey = "TartarusShopSurvival" },
                { key = "Group4Offer1", label = "Offer 5", optionSetKey = "EndShopMajorPower" },
                { key = "Group5Offer1", label = "Offer 6", optionSetKey = "EndShopResource" },
            },
        },
    },
}
