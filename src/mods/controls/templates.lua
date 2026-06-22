local deps = ... or {}
local route = deps.route
local rewards = deps.rewards or (route and route.rewards) or nil

local godData = deps.godData or import("mods/data/gods.lua")

return {
    ClockworkGoalRoute = import("mods/controls/ClockworkGoalRoute/ClockworkGoalRoute.lua", nil, {
        route = route,
        rewards = rewards,
        dropdownValues = deps.dropdownValues,
    }),
    FieldsCageRoute = import("mods/controls/FieldsCageRoute/FieldsCageRoute.lua", nil, {
        route = route,
        rewards = rewards,
        dropdownValues = deps.dropdownValues,
    }),
    FixedLinearRoute = import("mods/controls/FixedLinearRoute/FixedLinearRoute.lua", nil, {
        route = route,
        rewards = rewards,
        dropdownValues = deps.dropdownValues,
    }),
    HubPylonRoute = import("mods/controls/HubPylonRoute/HubPylonRoute.lua", nil, {
        route = route,
        rewards = rewards,
        dropdownValues = deps.dropdownValues,
    }),
    MultiEncounterFixedRoute = import("mods/controls/MultiEncounterFixedRoute/MultiEncounterFixedRoute.lua", nil, {
        route = route,
        rewards = rewards,
        dropdownValues = deps.dropdownValues,
    }),
    RouteNpcs = import("mods/controls/RouteNpcs/RouteNpcs.lua", nil, {
        route = route,
    }),
    RouteFeatures = import("mods/controls/RouteFeatures/RouteFeatures.lua", nil, {
        route = route,
    }),
    RouteGlobal = import("mods/controls/RouteGlobal/RouteGlobal.lua", nil, {
        gods = godData,
    }),
}
