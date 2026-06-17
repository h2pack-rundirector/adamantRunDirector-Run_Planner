local deps = ...
local data = import("mods/controls/FieldsCageRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/FieldsCageRoute/runtime.lua", nil, {
    data = data,
    rewardRuntime = deps.rewards.runtime,
})
local ui = import("mods/controls/FieldsCageRoute/ui.lua", nil, {
    data = data,
    rewardRuntime = deps.rewards.runtime,
    rewardUi = deps.rewards.ui,
    runtime = runtime,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
