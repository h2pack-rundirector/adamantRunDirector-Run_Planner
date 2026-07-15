local managedState = {}

function managedState.install(module, catalog, opts)
    opts = opts or {}
    local storage = import("mods/route/storage_manifest.lua").build(catalog)
    local templates = import("mods/controls/templates.lua").build(catalog)
    local instances = import("mods/controls/instances.lua").build(catalog, opts.activePrefixEnds)

    module.data.define(storage.moduleStorage)
    module.controls.defineTemplates(templates)
    module.controls.define(instances)

    return {
        storage = storage,
    }
end

return managedState
