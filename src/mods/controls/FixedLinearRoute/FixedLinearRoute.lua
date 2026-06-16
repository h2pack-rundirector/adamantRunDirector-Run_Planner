local data = import("mods/controls/FixedLinearRoute/data.lua")
local runtime = import("mods/controls/FixedLinearRoute/runtime.lua", nil, {
    data = data,
})
local ui = import("mods/controls/FixedLinearRoute/ui.lua", nil, {
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
