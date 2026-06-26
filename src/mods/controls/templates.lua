local deps = ... or {}
local route = deps.route
local rewards = deps.rewards or (route and route.rewards) or nil
local decorations = deps.decorations

local godData = deps.godData
local rewardRatio = import("mods/controls/reward_ratio.lua")
local sideRoomProbability = import("mods/controls/side_room_probability.lua")
local roomStructure = import("mods/controls/room_structure.lua")
local roomTopology = import("mods/controls/room_topology.lua", nil, {
    common = route.common,
    availability = route.availability,
    valueStates = route.valueStates,
})

return {
    ClockworkGoalRoute = import("mods/controls/ClockworkGoalRoute/ClockworkGoalRoute.lua", nil, {
        route = route,
        rewards = rewards,
        roomStructure = roomStructure,
        decorations = decorations,
    }),
    FieldsCageRoute = import("mods/controls/FieldsCageRoute/FieldsCageRoute.lua", nil, {
        route = route,
        rewards = rewards,
        roomStructure = roomStructure,
        roomTopology = roomTopology,
        decorations = decorations,
    }),
    FixedLinearRoute = import("mods/controls/FixedLinearRoute/FixedLinearRoute.lua", nil, {
        route = route,
        rewards = rewards,
        roomStructure = roomStructure,
        roomTopology = roomTopology,
        rewardRatio = rewardRatio,
        decorations = decorations,
    }),
    HubPylonRoute = import("mods/controls/HubPylonRoute/HubPylonRoute.lua", nil, {
        route = route,
        rewards = rewards,
        roomStructure = roomStructure,
        sideRoomProbability = sideRoomProbability,
        decorations = decorations,
    }),
    MultiEncounterFixedRoute = import("mods/controls/MultiEncounterFixedRoute/MultiEncounterFixedRoute.lua", nil, {
        route = route,
        rewards = rewards,
        roomStructure = roomStructure,
        rewardRatio = rewardRatio,
        decorations = decorations,
    }),
    RouteNpcs = import("mods/controls/RouteNpcs/RouteNpcs.lua", nil, {
        route = route,
        decorations = decorations,
    }),
    RouteFeatures = import("mods/controls/RouteFeatures/RouteFeatures.lua", nil, {
        route = route,
        decorations = decorations,
    }),
    RouteGlobal = import("mods/controls/RouteGlobal/RouteGlobal.lua", nil, {
        gods = godData,
        decorations = decorations,
    }),
}
