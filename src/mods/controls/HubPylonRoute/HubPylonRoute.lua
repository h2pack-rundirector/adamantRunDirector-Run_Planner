local deps = ...
local biomeHelpers = deps.biomeHelpers
local sideRoomProbability = import("mods/controls/HubPylonRoute/side_room_probability.lua")
local data = import("mods/controls/HubPylonRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/HubPylonRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
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
    valueStateHelpers = biomeHelpers.valueStates,
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
