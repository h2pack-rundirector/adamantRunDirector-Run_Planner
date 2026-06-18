local deps = ...
local data = import("mods/controls/MultiEncounterFixedRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/MultiEncounterFixedRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewardRuntime = deps.rewards.runtime,
})
local ui = import("mods/controls/MultiEncounterFixedRoute/ui.lua", nil, {
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
