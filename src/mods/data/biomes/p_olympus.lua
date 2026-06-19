return function(importer)
    local layout = importer("mods/data/biomes/p_olympus_layout.lua")
    local timeline = importer("mods/data/biomes/timeline.lua")
    local rewards = importer("mods/data/rewards.lua")(importer)
    local routeRules = importer("mods/data/route_rules.lua")

    return {
        key = "P",
        label = "Olympus",
        region = "Surface",
        adapter = "fixedLinear",
        timeline = timeline.standard("P", {
            bossRooms = {
                { key = "P_Boss01", label = "Boss" },
            },
            postBossFeatures = { surfaceShop = true },
        }),
        featurePolicies = {
            chaos = {
                roomHistoryDepth = { max = 5 },
            },
            surfaceShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            coordinate = "BiomeDepthCache",
            depthRange = { min = 1, max = 9 },
            routeStartDepth = 1,
            routeEndDepth = 8,
            entry = {
                kind = "intro",
                roomKey = layout.introRoom.key,
                tags = layout.introRoom.tags,
                features = layout.chaosFeatures,
                biomeEncounterDepthCost = 0,
                locked = true,
            },
            default = {
                kind = "route",
                alternate = "VanillaSafe",
                biomeEncounterDepthCost = 1,
            },
            special = {
                [9] = {
                    kind = "preboss",
                    roomKey = layout.prebossRoom.key,
                    tags = layout.prebossRoom.tags,
                    biomeEncounterDepthCost = 0,
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
                biomeEncounterDepthCost = 1,
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.majorMinor(),
                biomeEncounterDepthCost = 1,
            },
            {
                key = "Story",
                label = "Story",
                roomOptions = layout.storyRooms,
                reward = rewards.none(),
                biomeEncounterDepthCost = 0,
                routeRules = routeRules.role("Story"),
                reserve = true,
            },
            {
                key = "Fountain",
                label = "Fountain",
                roomOptions = layout.fountainRooms,
                reward = rewards.majorMinor(),
                biomeEncounterDepthCost = 0,
                routeRules = routeRules.role("Fountain"),
                reserve = true,
            },
            {
                key = "Midshop",
                label = "Shop",
                roomOptions = layout.shopRooms,
                reward = rewards.shop("WorldShop"),
                biomeEncounterDepthCost = 0,
                routeRules = routeRules.role("Midshop"),
                reserve = true,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                requiresConcreteOption = true,
                routeRules = routeRules.role("Miniboss"),
                reserve = true,
            },
        },
    }
end
