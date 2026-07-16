local deps = ...

local templateBuilder = deps.templates
local manifestBuilder = deps.manifest or import("mods/controls/manifest.lua", nil, {
    templates = templateBuilder,
})
local instanceBuilder = deps.instances or import("mods/controls/instances.lua")

local assembly = {}

local function attachManifest(catalog, manifest)
    local result = {}
    for key, value in pairs(catalog) do
        result[key] = value
    end
    result.controlManifest = manifest
    return result
end

function assembly.create(catalog, opts)
    opts = opts or {}
    local manifest = manifestBuilder.build(catalog)
    local enrichedCatalog = attachManifest(catalog, manifest)
    return {
        catalog = enrichedCatalog,
        manifest = manifest,
        templates = templateBuilder.build(enrichedCatalog),
        instances = instanceBuilder.build(enrichedCatalog, opts.activePrefixEnds),
    }
end

return assembly
