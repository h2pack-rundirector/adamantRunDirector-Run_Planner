local deps = ...
local layout = import("mods/biomes/declarations/o_thessaly_layout.lua")()
local topology = import("mods/biomes/declarations/o_thessaly_topology.lua")(deps)
local parser = deps.parser
local rewards = deps.rewards
local routeRules = deps.routeRules

return {
        key = "O",
        label = "Thessaly",
        region = "Surface",
        adapter = "multiEncounterFixed",
        roomTopology = topology,
        rewardRatio = {
            targetMetaProgress = 0.30,
        },
        timeline = parser.standardTimeline("O", {
            bossRoomHistoryCost = 1,
            postBossRoomHistoryCost = 1,
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
            routeRow = {
                biomeDepthCacheCost = 1,
                roomHistoryCost = 1,
            },
            depthRange = { min = 1, max = 7 },
            routeStartOrdinal = 1,
            routeEndOrdinal = 6,
            entry = {
                kind = "intro",
                isBiomeEntry = true,
                room = layout.introRoom,
                biomeDepthCacheCost = 0,
                biomeEncounterDepthCost = 0,
                roomHistoryCost = 1,
                locked = true,
            },
            special = {
                [7] = {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss Shop",
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                    roomHistoryCost = 1,
                    reward = rewards.shop("WorldShop"),
                },
            },
        },
        roles = {
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.none(),
                encounterPolicy = "O_CombatData",
                biomeDepthCacheCost = 1,
                roomHistoryCost = 1,
                requiresConcreteOption = true,
            },
            {
                key = "Story",
                label = "Story",
                roomOptions = layout.storyRooms,
                reward = rewards.none(),
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 0,
                roomHistoryCost = 1,
                routeRules = routeRules.role("Story"),
                reserve = true,
            },
            {
                key = "Fountain",
                label = "Fountain",
                roomOptions = layout.fountainRooms,
                reward = rewards.majorMinor(),
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 0,
                roomHistoryCost = 1,
                routeRules = routeRules.role("Fountain"),
                reserve = true,
            },
            {
                key = "Midshop",
                label = "Shop",
                roomOptions = layout.shopRooms,
                reward = rewards.shop("WorldShop"),
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 0,
                roomHistoryCost = 1,
                routeRules = routeRules.role("Midshop"),
                reserve = true,
            },
            {
                key = "Devotion",
                label = "Trial",
                roomOptions = layout.devotionRooms,
                reward = rewards.devotion(),
                requiredLayer = "rewards",
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 1,
                roomHistoryCost = 1,
                routeRules = routeRules.role("Devotion"),
                reserve = true,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                requiresConcreteOption = true,
                biomeDepthCacheCost = 1,
                roomHistoryCost = 1,
                routeRules = routeRules.role("Miniboss"),
                reserve = true,
            },
        },
}
