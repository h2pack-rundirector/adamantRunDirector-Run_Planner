local deps = ...
local biomeHelpers = deps.biomeHelpers
local data = import("mods/controls/MultiEncounterFixedRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/MultiEncounterFixedRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewards = deps.rewards,
    rewardItems = deps.route.rewardItems,
    roomStructure = biomeHelpers.roomStructure,
    rewardRatio = biomeHelpers.rewardRatio,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/MultiEncounterFixedRoute/ui/ui.lua", nil, {
    data = data,
    rewards = deps.rewards,
    runtime = runtime,
    rewardRatio = biomeHelpers.rewardRatio,
    roomOptionChanges = biomeHelpers.roomOptionChanges,
    decorations = deps.decorations,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
