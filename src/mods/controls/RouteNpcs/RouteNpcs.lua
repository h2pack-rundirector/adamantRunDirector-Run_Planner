local deps = ...
local data = import("mods/controls/RouteNpcs/data.lua")
local runtime = import("mods/controls/RouteNpcs/runtime.lua", nil, {
    data = data,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/RouteNpcs/ui.lua", nil, {
    data = data,
    runtime = runtime,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
