local deps = ...
local data = import("mods/controls/FixedLinearRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/FixedLinearRoute/runtime.lua", nil, {
    data = data,
    rewardRuntime = deps.rewards.runtime,
})
local ui = import("mods/controls/FixedLinearRoute/ui.lua", nil, {
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
