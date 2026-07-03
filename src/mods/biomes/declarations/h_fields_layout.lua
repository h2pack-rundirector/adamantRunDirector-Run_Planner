return function(deps)
local rooms = deps and deps.rooms or import("mods/biomes/declarations/h_fields_rooms.lua")()

return {
    routeRowLabelPrefix = "Pick",
    biomeDepthCacheStart = 1,
    routeStartOrdinal = 1,
    routeEndOrdinal = 4,
    routeRow = {
        biomeDepthCacheCost = 1,
        roomHistoryCost = 1,
    },
    fixedBeforeRoute = rooms.fixedBeforeRoute,
    fixedAfterRoute = rooms.fixedAfterRoute,

    -- Compatibility exports while H migrates to the room-catalog contract.
    wellShopFeatures = rooms.wellShopFeatures,
    introRoom = rooms.introRoom,
    bridgeRoom = rooms.bridgeRoom,
    cageRewardPolicy = rooms.cageRewardPolicy,
    combatRooms = rooms.combatRooms,
    combatRoomsByKey = rooms.combatRoomsByKey,
    minibossRooms = rooms.minibossRooms,
    minibossRoomsByKey = rooms.minibossRoomsByKey,
}
end
