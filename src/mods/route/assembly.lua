local deps = ... or {}

local storageManifest = deps.storageManifest or import("mods/route/storage_manifest.lua")
local stateAccess = deps.stateAccess or import("mods/route/state_access.lua")
local standardBatch = deps.standardBatch or import("mods/route/batches/standard.lua")
local prebossEntry = deps.prebossEntry or import("mods/route/transitions/preboss_entry.lua")
local biomePlan = deps.biomePlan or import("mods/route/biome_plan.lua")
local biomePlans = deps.biomePlans or import("mods/route/biome_plans.lua", nil, {
    biomePlan = biomePlan,
})
local batchImplementations = deps.batchImplementations or {
    Standard = standardBatch,
}
local terminalTransitions = deps.terminalTransitions or {
    PrebossEntry = prebossEntry,
}
local topologyLayouts = deps.topologyLayouts or {
    LinearBiome = import("mods/route/topology/linear_biome.lua", nil, {
        batchImplementations = batchImplementations,
        terminalTransitions = terminalTransitions,
    }),
}

local assembly = {}

function assembly.create(catalog)
    local storage = storageManifest.build(catalog)
    return {
        storage = storage,
        stateAccess = stateAccess,
        batchImplementations = batchImplementations,
        terminalTransitions = terminalTransitions,
        topologyLayouts = topologyLayouts,
        biomePlans = biomePlans.build(catalog, storage, topologyLayouts),
    }
end

return assembly
