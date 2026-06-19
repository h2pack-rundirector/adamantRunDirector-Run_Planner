return function(importer)
    local layout = importer("mods/data/biomes/q_summit_layout.lua")
    local timeline = importer("mods/data/biomes/timeline.lua")
    local rewards = importer("mods/data/rewards.lua")(importer)
    local routeRules = importer("mods/data/route_rules.lua")

    return {
        key = "Q",
        label = "Summit",
        region = "Surface",
        adapter = "scriptedFixedLinear",
        timeline = timeline.standard("Q", {
            postBossFeatures = { surfaceShop = true },
        }),
        featurePolicies = {
            surfaceShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            coordinate = "BiomeDepthCache",
            depthRange = { min = 1, max = 7 },
            routeStartDepth = 1,
            routeEndDepth = 6,
            entry = {
                kind = "intro",
                roomKey = layout.introRoom.key,
                biomeEncounterDepthCost = 0,
                locked = true,
            },
            default = {
                kind = "route",
                alternate = "VanillaSafe",
                biomeEncounterDepthCost = 1,
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
                            reward = rewards.shop("Q_WorldShop"),
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
                biomeEncounterDepthCost = 1,
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
