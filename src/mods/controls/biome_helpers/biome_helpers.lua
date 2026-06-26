local deps = ...
local route = deps.route

return {
    rewardRatio = import("mods/controls/biome_helpers/reward_ratio.lua"),
    roomOptionChanges = import("mods/controls/biome_helpers/room_option_changes.lua"),
    roomStructure = import("mods/controls/biome_helpers/room_structure.lua"),
    roomTopology = import("mods/controls/biome_helpers/room_topology.lua", nil, {
        common = route.common,
        availability = route.availability,
        valueStates = route.valueStates,
    }),
}
