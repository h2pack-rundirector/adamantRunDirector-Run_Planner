local lu = require("luaunit")
local h = require("tests.support.control_harness")
local loadCatalog = h.loadCatalog
local loadFixedLinearTemplate = h.loadFixedLinearTemplate
local loadRouteGlobalTemplate = h.loadRouteGlobalTemplate
local loadRunContext = h.loadRunContext
local routeDefinitions = h.routeDefinitions
local hasValue = h.hasValue
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw
local createUiControl = h.createUiControl

-- luacheck: globals TestRunPlannerRouteGlobal
TestRunPlannerRouteGlobal = {}

function TestRunPlannerRouteGlobal.testRouteGlobalTemplateStoresConfigurationAndGodPool()
    local catalog = loadCatalog()
    local template = loadRouteGlobalTemplate()
    local instance = template.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
        features = catalog.features,
        biomeLookup = catalog.lookup,
    })
    local storage = template.storage(instance)
    local control = template.createUi(routeUiFields(storage), instance)

    lu.assertEquals(storage[1], {
        key = "ConfigureRewards",
        type = "bool",
        default = true,
    })
    lu.assertEquals(storage[2], {
        key = "ConfigureNpcs",
        type = "bool",
        default = false,
    })
    lu.assertEquals(storage[3], {
        key = "ConfiguredBiomeCount",
        type = "string",
        default = "4",
        maxLen = 2,
    })
    lu.assertEquals(storage[4].key, "GodPool")
    lu.assertEquals(storage[4].type, "packedInt")
    lu.assertEquals(storage[4].width, 9)
    lu.assertEquals(#storage[4].bits, 9)
    lu.assertEquals(storage[4].bits[1], {
        key = "AphroditeUpgrade",
        label = "Aphrodite",
        type = "bool",
        offset = 0,
        width = 1,
        default = true,
    })
    lu.assertEquals(control:configuredBiomeCount(), 4)
    lu.assertEquals(control:configuredBiomeCountOpts().displayValues["2"], "2 - Oceanus")
    control:writeConfiguredBiomeCount("2")
    lu.assertEquals(control:configuredBiomeCount(), 2)
    lu.assertTrue(control:isGodEnabled("AphroditeUpgrade"))
    lu.assertEquals(control:enabledGods(), {
        "AphroditeUpgrade",
        "ApolloUpgrade",
        "AresUpgrade",
        "DemeterUpgrade",
        "HephaestusUpgrade",
        "HestiaUpgrade",
        "HeraUpgrade",
        "PoseidonUpgrade",
        "ZeusUpgrade",
    })
end

function TestRunPlannerRouteGlobal.testRouteGlobalConfigurationScopesActiveSystems()
    local catalog = loadCatalog()
    local template = loadRouteGlobalTemplate()
    local instance = template.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
        features = catalog.features,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)

    lu.assertTrue(control:isLayerConfigured("rewards"))
    lu.assertFalse(control:isLayerConfigured("npcs"))

    fields.ConfigureRewards:write(false)
    fields.ConfigureNpcs:write(true)

    lu.assertFalse(control:isLayerConfigured("rewards"))
    lu.assertTrue(control:isLayerConfigured("npcs"))
end

function TestRunPlannerRouteGlobal.testRouteGlobalDrawShowsRewardsDisabledNote()
    local catalog = loadCatalog()
    local template = loadRouteGlobalTemplate()
    local instance = template.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.ConfigureRewards:write(false)
    local control = template.createUi(fields, instance)

    local draw = noOpDraw()
    local noteWasRendered = false
    draw.imgui.TextWrapped = function(text)
        if text == "Disabling rewards invalidates Trial rewards." then
            noteWasRendered = true
        end
    end

    template.views.planner(draw, control, instance)

    lu.assertTrue(noteWasRendered)
end

function TestRunPlannerRouteGlobal.testRouteGlobalProvidesStableGodSourceDropdownOptions()
    local catalog = loadCatalog()
    local template = loadRouteGlobalTemplate()
    local instance = template.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local control = template.createUi(routeUiFields(template.storage(instance)), instance)
    local baseOpts = {
        label = "God",
        controlWidth = 170,
    }

    local opts = control:godSourceDrawOpts(baseOpts, "")
    lu.assertEquals(opts.label, "God")
    lu.assertEquals(opts.values, {
        "",
        "AphroditeUpgrade",
        "ApolloUpgrade",
        "AresUpgrade",
        "DemeterUpgrade",
        "HephaestusUpgrade",
        "HestiaUpgrade",
        "HeraUpgrade",
        "PoseidonUpgrade",
        "ZeusUpgrade",
    })
    lu.assertEquals(opts.displayValues.AphroditeUpgrade, "Aphrodite")
    lu.assertNil(opts.valueColors)

    control:godPoolField():writeAlias("AphroditeUpgrade", false)
    control:invalidateGodSource()

    local updatedOpts = control:godSourceDrawOpts(baseOpts, "")
    lu.assertIs(updatedOpts, opts)
    lu.assertFalse(hasValue(updatedOpts.values, "AphroditeUpgrade"))

    local currentValueOpts = control:godSourceDrawOpts(baseOpts, "AphroditeUpgrade")
    lu.assertIs(currentValueOpts, opts)
    lu.assertTrue(hasValue(currentValueOpts.values, "AphroditeUpgrade"))
end

function TestRunPlannerRouteGlobal.testRouteContextSuppliesRouteGlobalGodSource()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local fixedTemplate = loadFixedLinearTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local globalControl = globalTemplate.createUi(routeUiFields(globalTemplate.storage(globalInstance)), globalInstance)
    local routeControl = createUiControl(fixedTemplate, catalog.lookup.F, "RouteF")
    local controlsByName = {
        RouteGlobalUnderworld = globalControl,
        RouteF = routeControl,
    }
    local context = loadRunContext().create({
        routes = routeDefinitions({ catalog.routes.lookup.Underworld }),
        controls = {
            get = function(controlName)
                return controlsByName[controlName]
            end,
        },
    })

    context:bindControl(routeControl, "Underworld")
    local rewardOpts = routeControl:rewardDrawOpts({
        hideGenericRewardLabel = true,
    })

    lu.assertIs(rewardOpts.godSource, globalControl)
    lu.assertTrue(rewardOpts.hideGenericRewardLabel)
end
