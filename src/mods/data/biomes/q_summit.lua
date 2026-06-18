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
        timeline = timeline.standard("Q"),
        slotLayout = {
            coordinate = "BiomeDepthCache",
            depthRange = { min = 1, max = 7 },
            routeStartDepth = 1,
            routeEndDepth = 6,
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
                [7] = {
                    kind = "preboss",
                    roomKey = layout.prebossRoom.key,
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
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.none(),
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("TyphonBossRewards"),
                routeRules = routeRules.role("Miniboss", { maxSelectionsPerBiome = 2 }),
                reserve = true,
            },
        },
    }
end
