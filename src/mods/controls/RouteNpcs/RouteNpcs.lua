local deps = ...
local data = import("mods/controls/RouteNpcs/data.lua")
local runtime = import("mods/controls/RouteNpcs/runtime.lua", nil, {
    data = data,
})
local ui = import("mods/controls/RouteNpcs/ui.lua", nil, {
    data = data,
    routeStatusUi = deps.routeStatusUi,
    runtime = runtime,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
