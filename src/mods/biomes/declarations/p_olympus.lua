local deps = ...
local layout = import("mods/biomes/declarations/p_olympus_layout.lua")
local topology = import("mods/biomes/declarations/p_olympus_topology.lua")({
    layout = layout,
})
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
        tagLabels = layout.tagLabels,
        roomTopology = topology,
        timeline = parser.standardTimeline("P", {
            bossRooms = {
                { key = "P_Boss01", label = "Boss" },
            },
            bossRoomHistoryCost = 1,
            postBossRoomHistoryCost = 1,
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
            routeRow = {
                biomeDepthCacheCost = 1,
                roomHistoryCost = 1,
            },
            depthRange = { min = 1, max = 9 },
            routeStartOrdinal = 1,
            routeEndOrdinal = 8,
            entry = {
                kind = "intro",
                isBiomeEntry = true,
                room = layout.introRoom,
                tags = layout.introRoom.tags,
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 0,
                roomHistoryCost = 1,
                locked = true,
            },
            special = {
                [9] = {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss",
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                    roomHistoryCost = 1,
                    reward = rewards.preboss("WorldShop", "RunProgress", {
                        ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
                    }),
                },
            },
        },
        roles = {
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.majorMinor(),
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 1,
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
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                biomeDepthCacheCost = 1,
                roomHistoryCost = 1,
                requiresConcreteOption = true,
                routeRules = routeRules.role("Miniboss"),
                reserve = true,
            },
        },
}
