local deps = ...
local form = deps.form

local roomStructure = import("mods/controls/biome_helpers/room_structure.lua")
local roomTopology = import("mods/controls/biome_helpers/room_topology.lua", nil, {
    common = form.common,
    roomStructure = roomStructure,
    valueStates = form.valueStates,
    form = form,
})
local roomTopologyAdapter = import("mods/controls/biome_helpers/room_topology_adapter.lua", nil, {
    common = form.common,
    readCache = form.readCache,
    roomStructure = roomStructure,
    roomTopology = roomTopology,
    valueStates = form.valueStates,
    form = form,
})

return {
    nextChoiceView = import("mods/controls/biome_helpers/next_choice_view.lua"),
    topologyControls = import("mods/controls/biome_helpers/topology_controls.lua", nil, {
        roomTopologyAdapter = roomTopologyAdapter,
    }),
    rewardRatio = import("mods/controls/biome_helpers/reward_ratio.lua"),
    roomStructure = roomStructure,
    roomTopology = roomTopology,
    roomTopologyAdapter = roomTopologyAdapter,
}
