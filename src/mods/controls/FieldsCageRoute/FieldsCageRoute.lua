local deps = ...
local biomeHelpers = deps.biomeHelpers
local dataDeps = {}
for key, value in pairs(deps.route) do
    dataDeps[key] = value
end
dataDeps.roomTopology = biomeHelpers.roomTopology
dataDeps.roomStructure = biomeHelpers.roomStructure

local data = import("mods/controls/FieldsCageRoute/data/data.lua", nil, dataDeps)
local runtime = import("mods/controls/FieldsCageRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewards = deps.rewards,
    rewardItems = deps.route.rewardItems,
    roomStructure = biomeHelpers.roomStructure,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/FieldsCageRoute/ui/ui.lua", nil, {
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
