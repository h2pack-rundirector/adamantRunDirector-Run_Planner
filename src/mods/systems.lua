local deps = ... or {}

local catalogAssembly = deps.catalogAssembly or import("mods/catalog/assembly.lua")
local rewardAssembly = deps.rewardAssembly or import("mods/rewards/assembly.lua")
local routeAssembly = deps.routeAssembly or import("mods/route/assembly.lua")
local biomeSupportAssembly = deps.biomeSupportAssembly or import("mods/composition/biome_support.lua")
local uiAssembly = deps.uiAssembly or import("mods/ui/assembly.lua")

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
            rewardUi = rewardServices.ui,
        })
    end
    local fixedOpening = opts.fixedOpening or deps.fixedOpening
    if fixedOpening == nil then
        fixedOpening = import("mods/controls/templates/fixed_opening.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
            rewardUi = rewardServices.ui,
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
            rewardUi = rewardServices.ui,
        })
    end
    local fountain = opts.fountain or deps.fountain
    if fountain == nil then
        fountain = import("mods/controls/templates/fountain.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
            rewardUi = rewardServices.ui,
        })
    end
    local story = opts.story or deps.story
    if story == nil then
        story = import("mods/controls/templates/story.lua", nil, {
            fixed = rewardServices.fixed,
            primitives = rewardServices.primitives,
            rewardUi = rewardServices.ui,
        })
    end
    local shopRoom = opts.shopRoom or deps.shopRoom
    if shopRoom == nil then
        shopRoom = import("mods/controls/templates/shop.lua", nil, {
            shop = rewardServices.shop,
            shops = rewardServices.shops,
            rewardUi = rewardServices.ui,
        })
    end
    local forkedPreboss = opts.forkedPreboss or deps.forkedPreboss
    if forkedPreboss == nil then
        forkedPreboss = import("mods/controls/templates/forked_preboss.lua", nil, {
            countedBindings = rewardServices.countedBindings,
            countedChoice = rewardServices.countedChoice,
            shop = rewardServices.shop,
            shops = rewardServices.shops,
            rewardUi = rewardServices.ui,
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

local function capabilityEvidence(assembled, supplied)
    assembled = assembled or {}
    supplied = supplied or {}
    return {
        topology = supplied.topology or assembled.topology,
        authoredEditor = supplied.authoredEditor or assembled.authoredEditor,
        materialization = supplied.materialization or assembled.materialization,
        headlessPipeline = supplied.headlessPipeline or assembled.headlessPipeline,
        plannerActive = supplied.plannerActive or assembled.plannerActive,
    }
end

local function mergeCapabilityEvidence(...)
    local result = {}
    for index = 1, select("#", ...) do
        local source = select(index, ...)
        for capability, evidence in pairs(source or {}) do
            result[capability] = result[capability] or {}
            for biomeStepKey, value in pairs(evidence) do
                result[capability][biomeStepKey] = value
            end
        end
    end
    return result
end

local function combinedStorage(routeStorage, uiStorage)
    local moduleStorage = {}
    for _, descriptor in ipairs(routeStorage.moduleStorage) do
        moduleStorage[#moduleStorage + 1] = descriptor
    end
    for _, descriptor in ipairs(uiStorage or {}) do
        moduleStorage[#moduleStorage + 1] = descriptor
    end
    return {
        moduleStorage = moduleStorage,
        biomes = routeStorage.biomes,
    }
end

local function withInstances(controls, instances)
    local result = {}
    for key, value in pairs(controls) do
        result[key] = value
    end
    result.instances = instances
    return result
end

function systems.create(opts)
    opts = opts or {}
    local catalog = opts.catalog or catalogAssembly.create(opts.catalogOverrides)
    local rewardServices = opts.rewardServices or rewardAssembly.create(catalog.rewards)
    local controls = opts.controls
    local controlsAssembly
    if controls == nil then
        controlsAssembly = opts.controlsAssembly
            or deps.controlsAssembly
            or createControlsAssembly(opts, rewardServices)
        controls = controlsAssembly.prepare(catalog)
    end
    local enrichedCatalog = controls.catalog
    local route = opts.route or routeAssembly.create(enrichedCatalog)
    local ui = opts.ui or uiAssembly.create(enrichedCatalog, route)
    local assembledEvidence = mergeCapabilityEvidence(
        route.capabilityEvidence,
        ui.capabilityEvidence
    )
    local biomeSupport = opts.biomeSupport or biomeSupportAssembly.create(
        enrichedCatalog,
        controls.manifest,
        capabilityEvidence(assembledEvidence, opts.biomeCapabilityEvidence)
    )
    if controls.instances == nil then
        if controlsAssembly == nil then
            error("injected controls must include instances", 0)
        end
        controls = withInstances(
            controls,
            controlsAssembly.createInstances(controls, biomeSupport.routes)
        )
    end
    local storage = combinedStorage(route.storage, ui.storage)
    local managedState = opts.managedState or import("mods/composition/managed_state.lua", nil, {
        storage = storage,
        templates = controls.templates,
        instances = controls.instances,
    })

    return {
        catalog = enrichedCatalog,
        rewards = rewardServices,
        controls = controls,
        biomeSupport = biomeSupport,
        route = route,
        ui = ui,
        managedState = managedState,
    }
end

return systems
