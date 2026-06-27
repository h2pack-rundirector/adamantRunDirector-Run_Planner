local deps = ...
local route = deps.route

local roomStructure = import("mods/controls/biome_helpers/room_structure.lua")
local roomTopology = import("mods/controls/biome_helpers/room_topology.lua", nil, {
    common = route.common,
    availability = route.availability,
    valueStates = route.valueStates,
})

return {
    rewardRatio = import("mods/controls/biome_helpers/reward_ratio.lua"),
    roomOptionChanges = import("mods/controls/biome_helpers/room_option_changes.lua"),
    roomStructure = roomStructure,
    roomTopology = roomTopology,
    roomTopologyAdapter = import("mods/controls/biome_helpers/room_topology_adapter.lua", nil, {
        common = route.common,
        readCache = route.readCache,
        roomStructure = roomStructure,
        roomTopology = roomTopology,
        valueStates = route.valueStates,
    }),
}
