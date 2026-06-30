local deps = ...
local route = deps.route

local roomStructure = import("mods/controls/biome_helpers/room_structure.lua")
local roomTopology = import("mods/controls/biome_helpers/room_topology.lua", nil, {
    common = route.common,
    roomStructure = roomStructure,
    valueStates = route.valueStates,
    form = route.controlForm,
})

return {
    rewardRatio = import("mods/controls/biome_helpers/reward_ratio.lua"),
    roomStructure = roomStructure,
    roomTopology = roomTopology,
    valueStates = import("mods/controls/biome_helpers/value_states.lua", nil, {
        valueStates = route.valueStates,
    }),
    roomTopologyAdapter = import("mods/controls/biome_helpers/room_topology_adapter.lua", nil, {
        common = route.common,
        readCache = route.readCache,
        roomStructure = roomStructure,
        roomTopology = roomTopology,
        valueStates = route.valueStates,
        form = route.controlForm,
    }),
}
