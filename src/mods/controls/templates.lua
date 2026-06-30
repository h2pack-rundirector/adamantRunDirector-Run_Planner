local deps = ... or {}
local route = deps.route
local rewards = deps.rewards or (route and route.rewards) or nil
local decorations = deps.decorations

local godData = deps.godData
local form = route.controlForm
local biomeHelpers = import("mods/controls/biome_helpers/biome_helpers.lua", nil, {
    route = route,
    form = form,
})

return {
    ClockworkGoalRoute = import("mods/controls/ClockworkGoalRoute/ClockworkGoalRoute.lua", nil, {
        route = route,
        rewards = rewards,
        biomeHelpers = biomeHelpers,
        decorations = decorations,
        form = form,
    }),
    FieldsCageRoute = import("mods/controls/FieldsCageRoute/FieldsCageRoute.lua", nil, {
        route = route,
        rewards = rewards,
        biomeHelpers = biomeHelpers,
        decorations = decorations,
        form = form,
    }),
    FixedLinearRoute = import("mods/controls/FixedLinearRoute/FixedLinearRoute.lua", nil, {
        route = route,
        rewards = rewards,
        biomeHelpers = biomeHelpers,
        decorations = decorations,
        form = form,
    }),
    HubPylonRoute = import("mods/controls/HubPylonRoute/HubPylonRoute.lua", nil, {
        route = route,
        rewards = rewards,
        biomeHelpers = biomeHelpers,
        decorations = decorations,
        form = form,
    }),
    MultiEncounterFixedRoute = import("mods/controls/MultiEncounterFixedRoute/MultiEncounterFixedRoute.lua", nil, {
        route = route,
        rewards = rewards,
        biomeHelpers = biomeHelpers,
        decorations = decorations,
        form = form,
    }),
    RouteGlobal = import("mods/controls/RouteGlobal/RouteGlobal.lua", nil, {
        gods = godData,
        decorations = decorations,
    }),
    RouteNpcs = import("mods/controls/RouteNpcs/RouteNpcs.lua", nil, {
        decorations = decorations,
    }),
}
