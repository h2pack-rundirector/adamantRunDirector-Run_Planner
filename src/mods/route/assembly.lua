local deps = ... or {}

local storageManifest = deps.storageManifest or import("mods/route/storage_manifest.lua")
local stateAccess = deps.stateAccess or import("mods/route/state_access.lua")
local standardBatch = deps.standardBatch or import("mods/route/batches/standard.lua")
local prebossEntry = deps.prebossEntry or import("mods/route/transitions/preboss_entry.lua")
local linearBiomeCommands = deps.linearBiomeCommands
    or import("mods/route/topology/linear_biome_commands.lua")
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
        commandImplementation = linearBiomeCommands,
        terminalTransitions = terminalTransitions,
    }),
}
local topologyCapabilityBiomeSteps = deps.topologyCapabilityBiomeSteps or {
    "Underworld_F",
    "Underworld_G",
}

local assembly = {}

local function topologyCapabilityEvidence(plans, storage)
    local evidence = {}
    local requiredOperations = {
        "readTopology",
        "checkStructure",
        "traverse",
        "semanticAddress",
        "apply",
        "clearTopology",
    }
    for _, biomeStepKey in ipairs(topologyCapabilityBiomeSteps) do
        local plan = plans.lookup[biomeStepKey]
        if plan == nil then
            error("topology capability biome '" .. biomeStepKey .. "' has no Biome Plan", 0)
        end
        local descriptor = storage.biomes.lookup[biomeStepKey]
        if descriptor == nil or descriptor.layoutKind ~= plan.layoutKind then
            error(
                "topology capability biome '" .. biomeStepKey
                    .. "' has no matching storage descriptor",
                0
            )
        end
        for _, operation in ipairs(requiredOperations) do
            if type(plan[operation]) ~= "function" then
                error(
                    "topology capability biome '" .. biomeStepKey
                        .. "' is missing operation '" .. operation .. "'",
                    0
                )
            end
        end
        evidence[biomeStepKey] = true
    end
    return evidence
end

function assembly.create(catalog)
    local storage = storageManifest.build(catalog)
    local plans = biomePlans.build(catalog, storage, topologyLayouts)
    return {
        storage = storage,
        stateAccess = stateAccess,
        batchImplementations = batchImplementations,
        terminalTransitions = terminalTransitions,
        topologyLayouts = topologyLayouts,
        biomePlans = plans,
        capabilityEvidence = {
            topology = topologyCapabilityEvidence(plans, storage),
        },
    }
end

return assembly
