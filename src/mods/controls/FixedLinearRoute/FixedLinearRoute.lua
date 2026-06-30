local deps = ...
local biomeHelpers = deps.biomeHelpers
local dataDeps = {}
for key, value in pairs(deps.route) do
    dataDeps[key] = value
end
dataDeps.common = deps.form.common
dataDeps.rowData = deps.form.rowData
dataDeps.valueStates = deps.form.valueStates
dataDeps.roomTopology = biomeHelpers.roomTopology
dataDeps.roomTopologyAdapter = biomeHelpers.roomTopologyAdapter
dataDeps.roomStructure = biomeHelpers.roomStructure
dataDeps.slotTimeline = deps.form.slots

local data = import("mods/controls/FixedLinearRoute/data/data.lua", nil, dataDeps)
local runtime = import("mods/controls/FixedLinearRoute/runtime.lua", nil, {
    data = data,
    common = deps.form.common,
    rewards = deps.rewards,
    roomStructure = biomeHelpers.roomStructure,
    rewardRatio = biomeHelpers.rewardRatio,
    form = deps.form,
})
local ui = import("mods/controls/FixedLinearRoute/ui/ui.lua", nil, {
    data = data,
    rewards = deps.rewards,
    runtime = runtime,
    rewardRatio = biomeHelpers.rewardRatio,
    valueStateHelpers = deps.form.feedback,
    decorations = deps.decorations,
    form = deps.form,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
