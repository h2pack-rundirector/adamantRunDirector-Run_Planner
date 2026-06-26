local deps = ...
local biomeHelpers = deps.biomeHelpers
local dataDeps = {}
for key, value in pairs(deps.route) do
    dataDeps[key] = value
end
dataDeps.roomTopology = biomeHelpers.roomTopology
dataDeps.roomTopologyAdapter = biomeHelpers.roomTopologyAdapter
dataDeps.roomStructure = biomeHelpers.roomStructure

local data = import("mods/controls/ClockworkGoalRoute/data/data.lua", nil, dataDeps)
local runtime = import("mods/controls/ClockworkGoalRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewards = deps.rewards,
    rewardItems = deps.route.rewardItems,
    roomStructure = biomeHelpers.roomStructure,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/ClockworkGoalRoute/ui/ui.lua", nil, {
    data = data,
    rewards = deps.rewards,
    runtime = runtime,
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
