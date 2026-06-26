return function(deps)
deps = deps or {}
local godData = deps.godData
local definitions = {}

definitions.primitives = {
    AphroditeUpgrade = { label = "Aphrodite" },
    ApolloUpgrade = { label = "Apollo" },
    AresUpgrade = { label = "Ares" },
    DemeterUpgrade = { label = "Demeter" },
    HephaestusUpgrade = { label = "Hephaestus" },
    HeraUpgrade = { label = "Hera" },
    HermesUpgrade = { label = "Hermes" },
    HestiaUpgrade = { label = "Hestia" },
    PoseidonUpgrade = { label = "Poseidon" },
    ZeusUpgrade = { label = "Zeus" },

    Boon = { label = "Boon" },
    Devotion = { label = "Trial" },
    RandomLoot = { label = "Boon" },
    BoostedRandomLoot = { label = "Boosted Boon" },
    BlindBoxLoot = { label = "Mystery Boon" },
    ShopHermesUpgrade = { label = "Hermes Boon" },

    WeaponUpgrade = { label = "Hammer" },
    WeaponUpgradeDrop = { label = "Hammer" },
    ChaosWeaponUpgrade = { label = "Anvil" },

    MaxHealthDrop = { label = "Max Health" },
    MaxHealthDropSmall = { label = "Tiny Max Health" },
    MaxHealthDropBig = { label = "Big Max Health" },
    EmptyMaxHealthSmallDrop = { label = "Empty Max Health" },

    MaxManaDrop = { label = "Max Magick" },
    MaxManaDropSmall = { label = "Tiny Max Magick" },
    MaxManaDropBig = { label = "Big Max Magick" },

    StackUpgrade = { label = "Pom of Power" },
    StackUpgradeBig = { label = "Double Pom" },
    StackUpgradeTriple = { label = "Triple Pom" },
    StoreRewardRandomStack = { label = "Pom Slice" },

    RoomMoneyDrop = { label = "Gold" },
    RoomMoneyTinyDrop = { label = "Tiny Gold" },
    RoomMoneyTripleDrop = { label = "Triple Gold" },

    TalentDrop = { label = "Path of Stars" },
    MinorTalentDrop = { label = "Tiny Path" },
    TalentBigDrop = { label = "Big Path" },
    SpellDrop = { label = "Selene's Gift" },

    GiftDrop = { label = "Nectar" },
    MetaCurrencyDrop = { label = "Bones" },
    MetaCurrencyBigDrop = { label = "Big Bones" },
    MetaCardPointsCommonDrop = { label = "Ashes" },
    MetaCardPointsCommonBigDrop = { label = "Big Ashes" },

    RoomRewardHealDrop = { label = "Heal" },
    HealBigDrop = { label = "Big Heal" },
    ArmorBoost = { label = "Armor" },
    ArmorBigBoost = { label = "Big Armor" },
    LastStandDrop = { label = "Kiss of Styx" },

    WeaponPointsRareDrop = { label = "Nightmare" },
    CardUpgradePointsDrop = { label = "Moon Dust" },
    CharonPointsDrop = { label = "Obol Points" },

    AirBoost = { label = "Air" },
    EarthBoost = { label = "Earth" },
    FireBoost = { label = "Fire" },
    WaterBoost = { label = "Water" },
    ElementalBoost = { label = "Element" },
}

definitions.godLoot = godData.godLootNames()

definitions.rewardSets = {
    OpeningRoomBans = {
        "Devotion",
        "RoomMoneyDrop",
        "MaxHealthDrop",
        "MaxManaDrop",
    },
    HubCombatRoomEasyBans = {
        "Devotion",
        "WeaponUpgrade",
        "HermesUpgrade",
    },
    SubroomEasyBans = {
        "MaxHealthDrop",
        "MaxManaDrop",
        "StackUpgrade",
        "RoomMoneyDrop",
        "TalentDrop",
    },
    SubroomHardBans = {
        "MaxManaDropSmall",
        "MaxHealthDropSmall",
        "EmptyMaxHealthSmallDrop",
        "RoomMoneyTinyDrop",
        "GiftDrop",
        "MetaCurrencyDrop",
        "MetaCardPointsCommonDrop",
        "MemPointsCommonDrop",
        "AirBoost",
        "FireBoost",
        "WaterBoost",
        "EarthBoost",
    },
}

definitions.rewardStores = {
    RunProgress = {
        label = "Major",
        options = {
            "Boon",
            "HermesUpgrade",
            "Devotion",
            "WeaponUpgrade",
            "MaxHealthDrop",
            "MaxManaDrop",
            "RoomMoneyDrop",
            "StackUpgrade",
            "SpellDrop",
            "TalentDrop",
        },
    },
    MetaProgress = {
        label = "Minor",
        options = {
            "GiftDrop",
            "MetaCurrencyDrop",
            "MetaCurrencyBigDrop",
            "MetaCardPointsCommonDrop",
            "MetaCardPointsCommonBigDrop",
        },
    },
    HubRewards = {
        options = {
            "Boon",
            "HermesUpgrade",
            "WeaponUpgrade",
            "MaxHealthDropBig",
            "MaxManaDropBig",
            "SpellDrop",
        },
    },
    SubRoomRewards = {
        options = {
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
            "MetaCardPointsCommonDrop",
            "MaxHealthDrop",
            "MaxManaDrop",
            "StackUpgrade",
            "RoomMoneyDrop",
            "MinorTalentDrop",
        },
    },
    SubRoomRewardsHard = {
        options = {
            "MaxHealthDrop",
            "MaxManaDrop",
            "StackUpgrade",
            "RoomMoneyDrop",
        },
    },
    TartarusRewards = {
        options = {
            "Boon",
            "WeaponUpgrade",
            "Devotion",
            "StackUpgradeTriple",
            "TalentBigDrop",
            "RoomMoneyTripleDrop",
        },
    },
    TyphonBossRewards = {
        options = {
            "Boon",
            "TalentBigDrop",
            "StackUpgradeTriple",
            "WeaponUpgrade",
        },
    },
}

definitions.shopOptionSets = {
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

definitions.shops = {
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

return definitions
end
