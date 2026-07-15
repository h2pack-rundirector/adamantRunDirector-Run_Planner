local deps = ... or {}

local storageManifest = deps.storageManifest or import("mods/route/storage_manifest.lua")
local stateAccess = deps.stateAccess or import("mods/route/state_access.lua")

local assembly = {}

function assembly.create(catalog)
    return {
        storage = storageManifest.build(catalog),
        stateAccess = stateAccess,
    }
end

return assembly
