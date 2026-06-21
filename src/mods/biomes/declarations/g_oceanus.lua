return function(importer, deps)
    local layout = importer("mods/biomes/declarations/g_oceanus_layout.lua")
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules
    local combatRooms = parser.withReward(
        layout.combatRooms,
        layout.devotionCombatRooms,
        rewards.majorMinor({ allowDevotion = true })
    )

    return {
        key = "G",
        label = "Oceanus",
        region = "Underworld",
        adapter = "fixedLinear",
        timeline = parser.standardTimeline("G", {
            postBossFeatures = { wellShop = true },
        }),
        featurePolicies = {
            wellShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            routeRowLabelPrefix = "Depth",
            biomeDepthCacheStart = 1,
            defaultFixedBiomeDepthCacheCost = 0,
            routeBiomeDepthCacheCost = 1,
            depthRange = { min = 1, max = 8 },
            routeStartOrdinal = 1,
            routeEndOrdinal = 7,
            entry = {
                kind = "intro",
                isBiomeEntry = true,
                roomKey = layout.introRoom.key,
                features = layout.chaosFeatures,
                biomeEncounterDepthCost = 0,
                locked = true,
            },
            special = {
                [8] = {
                    kind = "preboss",
                    roomKey = layout.prebossRoom.key,
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
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = combatRooms,
                reward = rewards.majorMinor(),
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
                routeRequirements = routeRules.midshopRequirements(),
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
