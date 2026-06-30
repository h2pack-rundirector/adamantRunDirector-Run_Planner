local deps = ...
local layout = import("mods/biomes/declarations/f_erebus_layout.lua")
local topology = import("mods/biomes/declarations/f_erebus_topology.lua")({
    layout = layout,
})
local parser = deps.parser
local rewards = deps.rewards
local routeRules = deps.routeRules
local combatRooms = parser.withReward(
    layout.combatRooms,
    layout.devotionCombatRooms,
    rewards.majorMinor({ allowDevotion = true })
)

return {
        key = "F",
        label = "Erebus",
        region = "Underworld",
        adapter = "fixedLinear",
        rewardRatio = {
            targetMetaProgress = 0.315,
        },
        roomTopology = topology,
        timeline = parser.standardTimeline("F", {
            bossRoomHistoryCost = 1,
            postBossRoomHistoryCost = 1,
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
            routeRow = {
                biomeDepthCacheCost = 1,
                roomHistoryCost = 1,
            },
            depthRange = { min = 0, max = 11 },
            routeStartOrdinal = 1,
            routeEndOrdinal = 10,
            special = {
                [0] = {
                    kind = "opening",
                    isBiomeEntry = true,
                    key = "Opening",
                    label = "Opening",
                    roomOptions = layout.openingRooms,
                    reward = rewards.roomStore("RunProgress", {
                        ineligibleRewardTypes = {
                            "Devotion",
                            "RoomMoneyDrop",
                            "MaxHealthDrop",
                            "MaxManaDrop",
                        },
                    }),
                    biomeDepthCacheCost = 0,
                    biomeEncounterDepthCost = 1,
                    roomHistoryCost = 1,
                    locked = true,
                },
                [11] = {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss",
                    biomeDepthCache = 10,
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
                mapOptions = combatRooms,
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
                routeRequirements = routeRules.midshopRequirements(),
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
