return {
    RunProgressMajorMinor = {
        key = "RunProgressMajorMinor",
        label = "Run Progress / Meta Progress",
        kind = "storeChoice",
        stores = { "RunProgress", "MetaProgress" },
    },

    RunProgressBoonOnly = {
        key = "RunProgressBoonOnly",
        label = "Run Progress / Boon Only",
        kind = "storeChoice",
        stores = { "RunProgress" },
        eligibleRewards = { "Boon" },
    },

    WorldShop = {
        key = "WorldShop",
        label = "World Shop",
        kind = "shop",
        shopKey = "WorldShop",
    },

    PrebossShopOrFreeReward = {
        key = "PrebossShopOrFreeReward",
        label = "Preboss Shop / Free Reward",
        kind = "branch",
        branches = {
            {
                key = "shop",
                offerProfile = "WorldShop",
            },
            {
                key = "freeReward",
                stores = { "RunProgress", "MetaProgress" },
            },
        },
    },
}
