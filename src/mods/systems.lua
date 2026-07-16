local deps = ... or {}

local catalogAssembly = deps.catalogAssembly or import("mods/catalog/assembly.lua")
local routeAssembly = deps.routeAssembly or import("mods/route/assembly.lua")

local systems = {}

local function createControlTemplates(opts)
    local routeControlTemplate = opts.routeControlTemplate
        or deps.routeControlTemplate
        or import("mods/controls/templates/route.lua")
    local transitionalRoom = opts.transitionalRoom or deps.transitionalRoom
    if transitionalRoom == nil then
        local stateManifest = opts.stateManifest
            or deps.stateManifest
            or import("mods/controls/state_manifest.lua")
        transitionalRoom = import("mods/controls/templates/transitional_room.lua", nil, {
            stateManifest = stateManifest,
        })
    end
    local standardCombat = opts.standardCombat or deps.standardCombat
    if standardCombat == nil then
        local storeChoice = opts.storeChoice
            or deps.storeChoice
            or import("mods/rewards/components/store_choice.lua")
        standardCombat = import("mods/controls/templates/standard_combat.lua", nil, {
            storeChoice = storeChoice,
        })
    end
    return import("mods/controls/templates.lua", nil, {
        route = routeControlTemplate,
        transitionalRoom = transitionalRoom,
        standardCombat = standardCombat,
    })
end

local function createControlsAssembly(opts)
    local templates = opts.controlTemplates
        or deps.controlTemplates
        or createControlTemplates(opts)
    return import("mods/controls/assembly.lua", nil, {
        templates = templates,
    })
end

function systems.create(opts)
    opts = opts or {}
    local catalog = opts.catalog or catalogAssembly.create(opts.catalogOverrides)
    local controls = opts.controls
    if controls == nil then
        local controlsAssembly = opts.controlsAssembly
            or deps.controlsAssembly
            or createControlsAssembly(opts)
        controls = controlsAssembly.create(catalog, {
            activePrefixEnds = opts.activePrefixEnds,
        })
    end
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
