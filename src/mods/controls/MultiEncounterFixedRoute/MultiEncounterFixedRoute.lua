local deps = ...
local biomeHelpers = deps.biomeHelpers
local data = import("mods/controls/MultiEncounterFixedRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/MultiEncounterFixedRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewards = deps.rewards,
    roomStructure = biomeHelpers.roomStructure,
    rewardRatio = biomeHelpers.rewardRatio,
    invalidLocations = deps.route.invalidLocations,
    controlRequirements = deps.route.controlRequirements,
})
local ui = import("mods/controls/MultiEncounterFixedRoute/ui/ui.lua", nil, {
    data = data,
    rewards = deps.rewards,
    runtime = runtime,
    rewardRatio = biomeHelpers.rewardRatio,
    roomOptionChanges = biomeHelpers.roomOptionChanges,
    valueStateHelpers = biomeHelpers.valueStates,
    decorations = deps.decorations,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
