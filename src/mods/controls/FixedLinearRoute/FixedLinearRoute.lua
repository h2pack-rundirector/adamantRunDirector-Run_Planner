local deps = ...
local data = import("mods/controls/FixedLinearRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/FixedLinearRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewardRuntime = deps.rewards.runtime,
    rewardItems = deps.route.rewardItems,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/FixedLinearRoute/ui.lua", nil, {
    data = data,
    rewardRuntime = deps.rewards.runtime,
    rewardUi = deps.rewards.ui,
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
