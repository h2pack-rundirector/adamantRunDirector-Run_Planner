return function(importer)
    local layout = importer("mods/data/biomes/f_erebus_layout.lua")
    local timeline = importer("mods/data/biomes/timeline.lua")
    local rewards = importer("mods/data/rewards.lua")(importer)
    local routeRules = importer("mods/data/route_rules.lua")

    return {
        key = "F",
        label = "Erebus",
        region = "Underworld",
        adapter = "fixedLinear",
        timeline = timeline.standard("F", {
            postBossFeatures = { wellShop = true },
        }),
        featurePolicies = {
            wellShop = {
                biomeDepth = { min = 3 },
            },
        },
        slotLayout = {
            coordinate = "BiomeDepthCache",
            depthRange = { min = 0, max = 10 },
            routeStartDepth = 1,
            routeEndDepth = 9,
            default = {
                kind = "route",
                alternate = "VanillaSafe",
            },
            special = {
                [0] = {
                    kind = "opening",
                    key = "Opening",
                    label = "Opening",
                    roomOptions = layout.openingRooms,
                    reward = rewards.roomStore("OpeningRunProgress"),
                    locked = true,
                },
                [10] = {
                    kind = "preboss",
                    roomKey = layout.prebossRoom.key,
                    branches = {
                        {
                            key = "Shop",
                            label = "Preboss Shop",
                            reward = rewards.shop("WorldShop"),
                        },
                        {
                            key = "MajorReward",
                            label = "Preboss Room",
                            reward = rewards.roomStore("PreBossRunProgress"),
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
                reward = rewards.majorMinor(),
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
                reward = rewards.majorMinor(),
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
