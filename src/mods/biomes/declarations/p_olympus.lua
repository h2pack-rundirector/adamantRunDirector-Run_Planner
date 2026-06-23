return function(importer, deps)
    local layout = importer("mods/biomes/declarations/p_olympus_layout.lua")
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules

    return {
        key = "P",
        label = "Olympus",
        region = "Surface",
        adapter = "fixedLinear",
        rewardRatio = {
            targetMetaProgress = 0.20,
        },
        timeline = parser.standardTimeline("P", {
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
            routeRowLabelPrefix = "Depth",
            biomeDepthCacheStart = 1,
            defaultFixedBiomeDepthCacheCost = 0,
            routeBiomeDepthCacheCost = 1,
            depthRange = { min = 1, max = 9 },
            routeStartOrdinal = 1,
            routeEndOrdinal = 8,
            entry = {
                kind = "intro",
                isBiomeEntry = true,
                roomKey = layout.introRoom.key,
                tags = layout.introRoom.tags,
                features = layout.chaosFeatures,
                biomeEncounterDepthCost = 0,
                locked = true,
            },
            special = {
                [9] = {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss",
                    roomKey = layout.prebossRoom.key,
                    tags = layout.prebossRoom.tags,
                    biomeEncounterDepthCost = 0,
                    reward = rewards.preboss("WorldShop", "RunProgress", {
                        ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
                    }),
                },
            },
        },
        roles = {
            {
                key = "Vanilla",
                label = "Vanilla",
                reward = rewards.none(),
                biomeEncounterDepthCost = routeRules.encounterDepthCost(0, 1),
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
