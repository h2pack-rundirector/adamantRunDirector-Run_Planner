return function(deps)
    local layout = import("mods/biomes/declarations/q_summit_layout.lua")
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
                room = layout.introRoom,
                biomeEncounterDepthCost = 0,
                locked = true,
            },
            special = {
                [7] = {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss Shop",
                    biomeEncounterDepthCost = 0,
                    reward = rewards.shop("Q_WorldShop"),
                },
            },
        },
        roles = {
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
