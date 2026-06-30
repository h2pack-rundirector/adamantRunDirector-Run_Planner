local deps = ...
local form = deps.form

local roomStructure = import("mods/controls/biome_helpers/room_structure.lua")
local roomTopology = import("mods/controls/biome_helpers/room_topology.lua", nil, {
    common = form.common,
    roomStructure = roomStructure,
    valueStates = form.valueStates,
    form = form,
})

return {
    rewardRatio = import("mods/controls/biome_helpers/reward_ratio.lua"),
    roomStructure = roomStructure,
    roomTopology = roomTopology,
    slotTimeline = import("mods/controls/biome_helpers/slot_timeline.lua"),
    valueStates = import("mods/controls/biome_helpers/value_states.lua", nil, {
        valueStates = form.valueStates,
    }),
    roomTopologyAdapter = import("mods/controls/biome_helpers/room_topology_adapter.lua", nil, {
        common = form.common,
        readCache = form.readCache,
        roomStructure = roomStructure,
        roomTopology = roomTopology,
        valueStates = form.valueStates,
        form = form,
    }),
}
