local deps = ...
local biomeHelpers = deps.biomeHelpers
local dataDeps = {}
for key, value in pairs(deps.route) do
    dataDeps[key] = value
end
dataDeps.roomTopology = biomeHelpers.roomTopology
dataDeps.roomStructure = biomeHelpers.roomStructure

local data = import("mods/controls/FixedLinearRoute/data/data.lua", nil, dataDeps)
local runtime = import("mods/controls/FixedLinearRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewards = deps.rewards,
    rewardItems = deps.route.rewardItems,
    roomStructure = biomeHelpers.roomStructure,
    rewardRatio = biomeHelpers.rewardRatio,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/FixedLinearRoute/ui/ui.lua", nil, {
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
