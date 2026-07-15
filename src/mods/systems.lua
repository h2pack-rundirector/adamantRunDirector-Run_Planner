local deps = ... or {}

local catalogAssembly = deps.catalogAssembly or import("mods/catalog/assembly.lua")
local controlsAssembly = deps.controlsAssembly or import("mods/controls/assembly.lua")
local routeAssembly = deps.routeAssembly or import("mods/route/assembly.lua")

local systems = {}

function systems.create(opts)
    opts = opts or {}
    local catalog = opts.catalog or catalogAssembly.create(opts.catalogOverrides)
    local controls = opts.controls or controlsAssembly.create(catalog, {
        activePrefixEnds = opts.activePrefixEnds,
    })
    local enrichedCatalog = controls.catalog
    local route = opts.route or routeAssembly.create(enrichedCatalog)
    local managedState = opts.managedState or import("mods/composition/managed_state.lua", nil, {
        storage = route.storage,
        templates = controls.templates,
        instances = controls.instances,
    })

    return {
        catalog = enrichedCatalog,
        controls = controls,
        route = route,
        managedState = managedState,
    }
end

return systems
