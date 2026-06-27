local shopOptionSets = {
    WorldShopBoon = {
        options = {
            "RandomLoot",
            "BlindBoxLoot",
            "ShopHermesUpgrade",
        },
    },
    WorldShopNonBoon = {
        options = {
            "WeaponUpgradeDrop",
            "RoomRewardHealDrop",
            "MaxHealthDrop",
            "ArmorBoost",
            "MetaCardPointsCommonDrop",
            "MetaCurrencyDrop",
            "GiftDrop",
        },
    },
    WorldShopMinor = {
        options = {
            "MaxManaDrop",
            "StackUpgrade",
            "StoreRewardRandomStack",
            "SpellDrop",
            "TalentDrop",
        },
    },
    TartarusShopPriorityPower = {
        options = {
            "RandomLoot",
            "BoostedRandomLoot",
            "StackUpgradeBig",
        },
    },
    TartarusShopMixedReward = {
        options = {
            "RandomLoot",
            "BlindBoxLoot",
            "MaxHealthDrop",
            "MaxManaDrop",
            "StackUpgrade",
            "TalentDrop",
            "SpellDrop",
        },
    },
    TartarusShopSurvival = {
        options = {
            "RoomRewardHealDrop",
            "ArmorBoost",
            "HealBigDrop",
            "ArmorBigBoost",
            "LastStandDrop",
        },
    },
    TartarusShopMajorPower = {
        options = {
            "WeaponUpgradeDrop",
            "RandomLoot",
            "BlindBoxLoot",
            "ShopHermesUpgrade",
            "ChaosWeaponUpgrade",
            "BoostedRandomLoot",
            "MaxHealthDropBig",
            "MaxManaDropBig",
        },
    },
    EndShopPrimaryPower = {
        options = {
            "RandomLoot",
            "BlindBoxLoot",
            "StackUpgrade",
            "BoostedRandomLoot",
            "StackUpgradeBig",
            "MaxHealthDrop",
            "MaxManaDrop",
            "TalentDrop",
            "SpellDrop",
        },
    },
    EndShopSecondaryReward = {
        options = {
            "RandomLoot",
            "HealBigDrop",
            "ArmorBigBoost",
        },
    },
    EndShopMajorPower = {
        options = {
            "WeaponUpgradeDrop",
            "RandomLoot",
            "ShopHermesUpgrade",
            "ChaosWeaponUpgrade",
            "BoostedRandomLoot",
            "MaxHealthDropBig",
            "MaxManaDropBig",
        },
    },
    EndShopResource = {
        options = {
            "WeaponPointsRareDrop",
            "CardUpgradePointsDrop",
            "CharonPointsDrop",
        },
    },
}

local shops = {
    WorldShop = {
        slots = {
            { key = "Boon", label = "Offer 1", optionSet = "WorldShopBoon" },
            { key = "MajorNonBoon", label = "Offer 2", optionSet = "WorldShopNonBoon" },
            { key = "Minor", label = "Offer 3", optionSet = "WorldShopMinor" },
        },
    },
    I_WorldShop = {
        slots = {
            { key = "Group1Offer1", label = "Offer 1", optionSet = "TartarusShopPriorityPower" },
            { key = "Group2Offer1", label = "Offer 2", optionSet = "TartarusShopMixedReward" },
            { key = "Group3Offer1", label = "Offer 3", optionSet = "TartarusShopSurvival" },
            { key = "Group4Offer1", label = "Offer 4", optionSet = "TartarusShopMajorPower" },
            { key = "Group5Offer1", label = "Offer 5", optionSet = "EndShopResource" },
        },
    },
    Q_WorldShop = {
        slots = {
            { key = "Group1Offer1", label = "Offer 1", optionSet = "EndShopPrimaryPower" },
            { key = "Group1Offer2", label = "Offer 2", optionSet = "EndShopPrimaryPower" },
            { key = "Group2Offer1", label = "Offer 3", optionSet = "EndShopSecondaryReward" },
            { key = "Group3Offer1", label = "Offer 4", optionSet = "TartarusShopSurvival" },
            { key = "Group4Offer1", label = "Offer 5", optionSet = "EndShopMajorPower" },
            { key = "Group5Offer1", label = "Offer 6", optionSet = "EndShopResource" },
        },
    },
}

return {
    shopOptionSets = shopOptionSets,
    shops = shops,
}
