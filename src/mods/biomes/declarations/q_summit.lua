local deps = ...
local layout = import("mods/biomes/declarations/q_summit_layout.lua")
local topology = import("mods/biomes/declarations/q_summit_topology.lua")({
    layout = layout,
})
local parser = deps.parser
local rewards = deps.rewards
local routeRules = deps.routeRules

return {
        key = "Q",
        label = "Summit",
        region = "Surface",
        adapter = "fixedLinear",
        roomTopology = topology,
        timeline = parser.standardTimeline("Q", {
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
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 1,
                roomHistoryCost = 1,
                requiresConcreteOption = true,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("TyphonBossRewards"),
                biomeDepthCacheCost = 1,
                roomHistoryCost = 1,
                requiresConcreteOption = true,
                routeRules = routeRules.role("Miniboss", { maxSelectionsPerBiome = 2 }),
                reserve = true,
            },
        },
}
