local deps = ...
local data = import("mods/controls/FieldsCageRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/FieldsCageRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewards = deps.rewards,
    rewardItems = deps.route.rewardItems,
    roomStructure = deps.roomStructure,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/FieldsCageRoute/ui.lua", nil, {
    data = data,
    rewards = deps.rewards,
    runtime = runtime,
    decorations = deps.decorations,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
