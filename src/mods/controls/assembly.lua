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

function assembly.prepare(catalog)
    local manifest = manifestBuilder.build(catalog)
    local enrichedCatalog = attachManifest(catalog, manifest)
    return {
        catalog = enrichedCatalog,
        manifest = manifest,
        templates = templateBuilder.build(enrichedCatalog),
    }
end

function assembly.createInstances(prepared, routeSupport)
    return instanceBuilder.build(prepared.catalog, routeSupport)
end

function assembly.create(catalog, opts)
    opts = opts or {}
    local prepared = assembly.prepare(catalog)
    prepared.instances = assembly.createInstances(prepared, opts.routeSupport)
    return prepared
end

return assembly
