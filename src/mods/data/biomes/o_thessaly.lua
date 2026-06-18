return function(importer)
    local layout = importer("mods/data/biomes/o_thessaly_layout.lua")(importer)
    local timeline = importer("mods/data/biomes/timeline.lua")
    local rewards = importer("mods/data/rewards.lua")(importer)
    local routeRules = importer("mods/data/route_rules.lua")

    return {
        key = "O",
        label = "Thessaly",
        region = "Surface",
        adapter = "multiEncounterFixed",
        timeline = timeline.standard("O"),
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
                            reward = rewards.shop("WorldShop"),
                        },
                    },
                },
            },
        },
        combatEncounterPolicy = layout.combatEncounterPolicy,
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
                reward = rewards.shipWheel(),
                encounterPolicy = "O_CombatData",
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
                reserve = true,
            },
            {
                key = "Trial",
                label = "Trial",
                roomOptions = layout.trialRooms,
                reward = rewards.devotion({
                    rewardStore = "RunProgress",
                    previousRoomExitCount = false,
                }),
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
