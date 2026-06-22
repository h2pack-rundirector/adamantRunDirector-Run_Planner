local deps = ...
local data = import("mods/controls/FixedLinearRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/FixedLinearRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewards = deps.rewards,
    rewardItems = deps.route.rewardItems,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/FixedLinearRoute/ui.lua", nil, {
    data = data,
    rewards = deps.rewards,
    runtime = runtime,
    dropdownValues = deps.dropdownValues,
    tabStatus = deps.tabStatus,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
