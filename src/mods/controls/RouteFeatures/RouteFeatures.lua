local deps = ...
local data = import("mods/controls/RouteFeatures/data.lua")
local runtime = import("mods/controls/RouteFeatures/runtime.lua", nil, {
    data = data,
    invalidLocations = deps.route.invalidLocations,
    targetMarkers = deps.route.targetMarkers,
    controlRequirements = deps.route.controlRequirements,
})
local ui = import("mods/controls/RouteFeatures/ui.lua", nil, {
    data = data,
    decorations = deps.decorations,
    runtime = runtime,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
