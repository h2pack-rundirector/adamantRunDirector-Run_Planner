local deps = ... or {}

local catalogAssembly = deps.catalogAssembly or import("mods/catalog/assembly.lua")
local rewardAssembly = deps.rewardAssembly or import("mods/rewards/assembly.lua")
local routeAssembly = deps.routeAssembly or import("mods/route/assembly.lua")
local biomeSupportAssembly = deps.biomeSupportAssembly or import("mods/composition/biome_support.lua")

local systems = {}

local function createControlTemplates(opts, rewardServices)
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
        standardCombat = import("mods/controls/templates/standard_combat.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
        })
    end
    local fixedOpening = opts.fixedOpening or deps.fixedOpening
    if fixedOpening == nil then
        fixedOpening = import("mods/controls/templates/fixed_opening.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
        })
    end
    local fixedIntro = opts.fixedIntro or deps.fixedIntro
    if fixedIntro == nil then
        fixedIntro = import("mods/controls/templates/fixed_intro.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
            none = rewardServices.none,
        })
    end
    local miniboss = opts.miniboss or deps.miniboss
    if miniboss == nil then
        miniboss = import("mods/controls/templates/miniboss.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
        })
    end
    local fountain = opts.fountain or deps.fountain
    if fountain == nil then
        fountain = import("mods/controls/templates/fountain.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
        })
    end
    local story = opts.story or deps.story
    if story == nil then
        story = import("mods/controls/templates/story.lua", nil, {
            fixed = rewardServices.fixed,
            primitives = rewardServices.primitives,
        })
    end
    local shopRoom = opts.shopRoom or deps.shopRoom
    if shopRoom == nil then
        shopRoom = import("mods/controls/templates/shop.lua", nil, {
            shop = rewardServices.shop,
            shops = rewardServices.shops,
        })
    end
    local forkedPreboss = opts.forkedPreboss or deps.forkedPreboss
    if forkedPreboss == nil then
        forkedPreboss = import("mods/controls/templates/forked_preboss.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
            shop = rewardServices.shop,
            shops = rewardServices.shops,
        })
    end
    return import("mods/controls/templates.lua", nil, {
        route = routeControlTemplate,
        transitionalRoom = transitionalRoom,
        fixedOpening = fixedOpening,
        fixedIntro = fixedIntro,
        standardCombat = standardCombat,
        miniboss = miniboss,
        story = story,
        fountain = fountain,
        shopRoom = shopRoom,
        forkedPreboss = forkedPreboss,
    })
end

local function createControlsAssembly(opts, rewardServices)
    local templates = opts.controlTemplates
        or deps.controlTemplates
        or createControlTemplates(opts, rewardServices)
    return import("mods/controls/assembly.lua", nil, {
        templates = templates,
    })
end

function systems.create(opts)
    opts = opts or {}
    local catalog = opts.catalog or catalogAssembly.create(opts.catalogOverrides)
    local rewardServices = opts.rewardServices or rewardAssembly.create(catalog.rewards)
    local controls = opts.controls
    if controls == nil then
        local controlsAssembly = opts.controlsAssembly
            or deps.controlsAssembly
            or createControlsAssembly(opts, rewardServices)
        controls = controlsAssembly.create(catalog, {
            activePrefixEnds = opts.activePrefixEnds,
        })
    end
    local enrichedCatalog = controls.catalog
    local biomeSupport = opts.biomeSupport or biomeSupportAssembly.create(
        enrichedCatalog,
        controls.manifest,
        opts.biomeCapabilityEvidence
    )
    local route = opts.route or routeAssembly.create(enrichedCatalog)
    local managedState = opts.managedState or import("mods/composition/managed_state.lua", nil, {
        storage = route.storage,
        templates = controls.templates,
        instances = controls.instances,
    })

    return {
        catalog = enrichedCatalog,
        rewards = rewardServices,
        controls = controls,
        biomeSupport = biomeSupport,
        route = route,
        managedState = managedState,
    }
end

return systems
