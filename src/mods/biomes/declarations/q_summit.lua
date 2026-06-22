return function(importer, deps)
    local layout = importer("mods/biomes/declarations/q_summit_layout.lua")
    local rewardLayout = importer("mods/biomes/declarations/q_summit_rewards.lua")(importer, deps)
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules

    return {
        key = "Q",
        label = "Summit",
        region = "Surface",
        adapter = "scriptedFixedLinear",
        timeline = parser.standardTimeline("Q", {
            postBossFeatures = { surfaceShop = true },
        }),
        featurePolicies = {
            surfaceShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            routeRowLabelPrefix = "Depth",
            biomeDepthCacheStart = 1,
            defaultFixedBiomeDepthCacheCost = 0,
            routeBiomeDepthCacheCost = 1,
            depthRange = { min = 1, max = 7 },
            routeStartOrdinal = 1,
            routeEndOrdinal = 6,
            entry = {
                kind = "intro",
                isBiomeEntry = true,
                roomKey = layout.introRoom.key,
                biomeEncounterDepthCost = 0,
                locked = true,
            },
            special = {
                [7] = {
                    kind = "preboss",
                    roomKey = layout.prebossRoom.key,
                    biomeEncounterDepthCost = 0,
                    branches = {
                        {
                            key = "Shop",
                            label = "Preboss Shop",
                            reward = rewardLayout.prebossShop,
                        },
                    },
                },
            },
        },
        vanillaDepthHints = layout.vanillaDepthHints,
        forcedDepthOptions = layout.forcedDepthOptions,
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
                reward = rewards.none(),
                biomeEncounterDepthCost = 1,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("TyphonBossRewards"),
                requiresConcreteOption = true,
                routeRules = routeRules.role("Miniboss", { maxSelectionsPerBiome = 2 }),
                reserve = true,
            },
        },
    }
end
