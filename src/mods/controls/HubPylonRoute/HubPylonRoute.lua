local deps = ...
local biomeHelpers = deps.biomeHelpers
local sideRoomProbability = import("mods/controls/HubPylonRoute/side_room_probability.lua")
local data = import("mods/controls/HubPylonRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/HubPylonRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewards = deps.rewards,
    rewardItems = deps.route.rewardItems,
    roomStructure = biomeHelpers.roomStructure,
    sideRoomProbability = sideRoomProbability,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/HubPylonRoute/ui/ui.lua", nil, {
    data = data,
    rewards = deps.rewards,
    runtime = runtime,
    sideRoomProbability = sideRoomProbability,
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
