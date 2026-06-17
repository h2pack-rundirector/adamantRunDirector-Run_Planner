return function(importer)
    local layout = importer("mods/data/biomes/g_oceanus_layout.lua")
    local rewards = importer("mods/data/rewards.lua")(importer)
    local routeRules = importer("mods/data/route_rules.lua")

    return {
        key = "G",
        label = "Oceanus",
        region = "Underworld",
        adapter = "fixedLinear",
        slotLayout = {
            coordinate = "BiomeDepthCache",
            depthRange = { min = 1, max = 8 },
            routeStartDepth = 1,
            routeEndDepth = 7,
            entry = {
                kind = "intro",
                roomKey = layout.introRoom.key,
                locked = true,
            },
            default = {
                kind = "route",
                alternate = "VanillaSafe",
            },
            special = {
                [8] = {
                    kind = "preboss",
                    roomKey = layout.prebossRoom.key,
                    branches = {
                        {
                            key = "Shop",
                            label = "Shop",
                            reward = rewards.shop("WorldShop"),
                        },
                        {
                            key = "MajorReward",
                            label = "Major Reward",
                            reward = rewards.roomStore("RunProgress", {
                                ineligibleRewardTypes = rewards.rewardSet("PreBossRoomBans"),
                            }),
                        },
                    },
                },
            },
        },
        roles = {
            {
                key = "Vanilla",
                label = "Vanilla",
                reward = rewards.none(),
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.roomStore("RunProgress"),
            },
            {
                key = "Story",
                label = "Story",
                roomOptions = layout.storyRooms,
                reward = rewards.none(),
                routeRules = routeRules.role("Story"),
                reserve = true,
            },
            {
                key = "Fountain",
                label = "Fountain",
                roomOptions = layout.fountainRooms,
                reward = rewards.roomStore("RunProgress"),
                routeRules = routeRules.role("Fountain"),
                reserve = true,
            },
            {
                key = "Midshop",
                label = "Shop",
                roomOptions = layout.shopRooms,
                reward = rewards.shop("WorldShop"),
                routeRules = routeRules.role("Midshop"),
                routeRequirements = routeRules.midshopRequirements(),
                reserve = true,
            },
            {
                key = "Trial",
                label = "Trial",
                mapOptions = layout.trialCombatRooms,
                reward = rewards.devotion({ rewardStore = "RunProgress" }),
                routeRules = routeRules.role("Trial"),
                reserve = true,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                routeRules = routeRules.role("Miniboss"),
                reserve = true,
            },
        },
    }
end
