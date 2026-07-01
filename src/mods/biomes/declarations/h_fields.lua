local deps = ...
local layout = import("mods/biomes/declarations/h_fields_layout.lua")()
local topology = import("mods/biomes/declarations/h_fields_topology.lua")({
    layout = layout,
})
local parser = deps.parser
local rewards = deps.rewards
local routeRules = deps.routeRules

return {
        key = "H",
        label = "Fields",
        region = "Underworld",
        adapter = "fieldsCageRoute",
        timeline = parser.standardTimeline("H", {
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
            routeRowLabelPrefix = "Pick",
            biomeDepthCacheStart = 1,
            routeRow = {
                biomeDepthCacheCost = 1,
                roomHistoryCost = 1,
            },
            routeStartOrdinal = 1,
            routeEndOrdinal = 4,
            fixedBeforeRoute = {
                {
                    key = "Intro",
                    label = "Intro",
                    isBiomeEntry = true,
                    room = layout.introRoom,
                    reward = rewards.none(),
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                    roomHistoryCost = 1,
                    locked = true,
                },
            },
            fixedAfterRoute = {
                {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss",
                    reward = rewards.preboss("WorldShop", "RunProgress", {
                        ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
                    }),
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                    roomHistoryCost = 1,
                },
            },
        },
        fields = {
            routeCount = {
                counter = "RoomsEntered",
                requiredBeforePreboss = 4,
                countedRooms = "CombatMinibossBridge",
            },
            combatRooms = layout.combatRooms,
            combatRoomsByKey = layout.combatRoomsByKey,
            minibossRooms = layout.minibossRooms,
            minibossRoomsByKey = layout.minibossRoomsByKey,
            cageRewardPolicy = layout.cageRewardPolicy,
            roomTopology = topology,
        },
        roles = {
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.fieldsCages({
                    rewardStore = "RunProgress",
                    ineligibleRewardTypes = { "Devotion" },
                }),
                cageRewardPolicy = "H_FieldsCageRewards",
                requiresConcreteOption = true,
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 1,
                roomHistoryCost = 1,
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
            {
                key = "Bridge",
                label = "Echo",
                roomOptions = { layout.bridgeRoom },
                reward = rewards.none(),
                biomeDepthCacheCost = 1,
                biomeEncounterDepthCost = 0,
                roomHistoryCost = 1,
                reserve = true,
            },
        },
}
