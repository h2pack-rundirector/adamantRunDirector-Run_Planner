local surfaces = {}

surfaces.godLoot = {
    "AphroditeUpgrade",
    "ApolloUpgrade",
    "AresUpgrade",
    "DemeterUpgrade",
    "HephaestusUpgrade",
    "HestiaUpgrade",
    "HeraUpgrade",
    "PoseidonUpgrade",
    "ZeusUpgrade",
}

surfaces.rewardStores = {
    RunProgress = {
        "Boon",
        "HermesUpgrade",
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxManaDrop",
        "RoomMoneyDrop",
        "StackUpgrade",
        "TalentDrop",
    },
    HubRewards = {
        "Boon",
        "HermesUpgrade",
        "WeaponUpgrade",
        "MaxHealthDropBig",
        "MaxManaDropBig",
        "SpellDrop",
    },
    TartarusRewards = {
        "Boon",
        "WeaponUpgrade",
        "StackUpgradeTriple",
        "TalentBigDrop",
        "RoomMoneyTripleDrop",
    },
    TyphonBossRewards = {
        "Boon",
        "TalentBigDrop",
        "StackUpgradeTriple",
        "WeaponUpgrade",
    },
}

surfaces.shops = {
    WorldShop = {
        slots = {
            {
                key = "Boon",
                label = "Boon",
                options = {
                    "RandomLoot",
                    "BlindBoxLoot",
                    "ShopHermesUpgrade",
                },
            },
            {
                key = "MajorNonBoon",
                label = "Major Non-Boon",
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
            {
                key = "Minor",
                label = "Minor",
                options = {
                    "MaxManaDrop",
                    "StackUpgrade",
                    "StoreRewardRandomStack",
                    "SpellDrop",
                },
            },
        },
    },
    I_WorldShop = {
        slots = {
            {
                key = "Group1Offer1",
                label = "Priority Power",
                options = {
                    "RandomLoot",
                    "BoostedRandomLoot",
                    "StackUpgradeBig",
                },
            },
            {
                key = "Group2Offer1",
                label = "Mixed Reward",
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
            {
                key = "Group3Offer1",
                label = "Survival",
                options = {
                    "RoomRewardHealDrop",
                    "ArmorBoost",
                    "HealBigDrop",
                    "ArmorBigBoost",
                    "LastStandDrop",
                },
            },
            {
                key = "Group4Offer1",
                label = "Major Power",
                options = {
                    "WeaponUpgradeDrop",
                    "RandomLoot",
                    "BlindBoxLoot",
                    "ShopHermesUpgrade",
                },
            },
            {
                key = "Group5Offer1",
                label = "Resource",
                options = {
                    "MetaCardPointsCommonDrop",
                    "MetaCurrencyDrop",
                    "GiftDrop",
                },
            },
        },
    },
    Q_WorldShop = {
        slots = {
            {
                key = "Group1Offer1",
                label = "Primary Power A",
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
            {
                key = "Group1Offer2",
                label = "Primary Power B",
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
            {
                key = "Group2Offer1",
                label = "Secondary Reward",
                options = {
                    "RandomLoot",
                    "HealBigDrop",
                    "ArmorBigBoost",
                },
            },
            {
                key = "Group3Offer1",
                label = "Survival",
                options = {
                    "RoomRewardHealDrop",
                    "ArmorBoost",
                    "HealBigDrop",
                    "ArmorBigBoost",
                    "LastStandDrop",
                },
            },
            {
                key = "Group4Offer1",
                label = "Major Power",
                options = {
                    "WeaponUpgradeDrop",
                    "RandomLoot",
                    "ShopHermesUpgrade",
                },
            },
            {
                key = "Group5Offer1",
                label = "Resource",
                options = {
                    "MetaCardPointsCommonDrop",
                    "MetaCurrencyDrop",
                    "GiftDrop",
                },
            },
        },
    },
}

return surfaces
