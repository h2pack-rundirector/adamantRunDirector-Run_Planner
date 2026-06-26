return function(deps)
    local layout = import("mods/biomes/declarations/o_thessaly_layout.lua")(deps)
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules

    return {
        key = "O",
        label = "Thessaly",
        region = "Surface",
        adapter = "multiEncounterFixed",
        rewardRatio = {
            targetMetaProgress = 0.30,
        },
        timeline = parser.standardTimeline("O", {
            postBossFeatures = { surfaceShop = true },
        }),
        featurePolicies = {
            surfaceShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        biomeRules = {
            {
                key = "story_or_shop_deadline",
                type = "requireAnyRoomByCounter",
                counter = "biomeDepthCache",
                deadline = 5,
                roomKeys = { "O_Story01", "O_Shop01" },
                code = "thessaly_story_or_shop_deadline",
                message = "Thessaly requires Circe or Shop by depth 5",
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
                    reward = rewards.shop("WorldShop"),
                },
            },
        },
        combatEncounterPolicy = layout.combatEncounterPolicy,
        roles = {
            {
                key = "Vanilla",
                label = "Vanilla",
                reward = rewards.none(),
                biomeEncounterDepthCost = routeRules.encounterDepthCost(0, 2),
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.none(),
                encounterPolicy = "O_CombatData",
                biomeEncounterDepthCost = routeRules.encounterDepthCost(1, 2),
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
                key = "Devotion",
                label = "Trial",
                roomOptions = layout.devotionRooms,
                reward = rewards.devotion(),
                requiredLayer = "rewards",
                biomeEncounterDepthCost = 1,
                routeRules = routeRules.role("Devotion"),
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
