local deps = ... or {}

local data = import("mods/controls/RouteNpcs/data.lua")
local runtime = import("mods/controls/RouteNpcs/runtime.lua", nil, {
    data = data,
})
local ui = import("mods/controls/RouteNpcs/ui.lua", nil, {
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
