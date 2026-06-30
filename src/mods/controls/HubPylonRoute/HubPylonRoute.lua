local deps = ...
local biomeHelpers = deps.biomeHelpers
local sideRoomProbability = import("mods/controls/HubPylonRoute/side_room_probability.lua")
local dataDeps = {}
for key, value in pairs(deps.route) do
    dataDeps[key] = value
end
dataDeps.common = deps.form.common
dataDeps.rowData = deps.form.rowData
dataDeps.valueStates = deps.form.valueStates
dataDeps.slotTimeline = biomeHelpers.slotTimeline
local data = import("mods/controls/HubPylonRoute/data.lua", nil, dataDeps)
local runtime = import("mods/controls/HubPylonRoute/runtime.lua", nil, {
    data = data,
    common = deps.form.common,
    rewards = deps.rewards,
    roomStructure = biomeHelpers.roomStructure,
    sideRoomProbability = sideRoomProbability,
    invalidLocations = deps.route.invalidLocations,
    form = deps.form,
})
local ui = import("mods/controls/HubPylonRoute/ui/ui.lua", nil, {
    data = data,
    rewards = deps.rewards,
    runtime = runtime,
    sideRoomProbability = sideRoomProbability,
    valueStateHelpers = biomeHelpers.valueStateHelpers,
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
