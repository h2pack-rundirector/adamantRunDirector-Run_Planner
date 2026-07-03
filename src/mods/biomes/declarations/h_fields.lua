local deps = ...
local rooms = import("mods/biomes/declarations/h_fields_rooms.lua")()
local layout = import("mods/biomes/declarations/h_fields_layout.lua")({
    rooms = rooms,
})
local topology = import("mods/biomes/declarations/h_fields_topology.lua")({
    rooms = rooms,
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
            routeRowLabelPrefix = layout.routeRowLabelPrefix,
            biomeDepthCacheStart = layout.biomeDepthCacheStart,
            routeRow = layout.routeRow,
            routeStartOrdinal = layout.routeStartOrdinal,
            routeEndOrdinal = layout.routeEndOrdinal,
            fixedBeforeRoute = layout.fixedBeforeRoute(rewards),
            fixedAfterRoute = layout.fixedAfterRoute(rewards),
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
        roles = rooms.roles(rewards, routeRules),
}
