-- luacheck: globals TestManagedPersistence

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestManagedPersistence = {}

local function load(activePrefixEnds)
    local systems = h.testImport("mods/systems.lua").create({
        activePrefixEnds = activePrefixEnds,
    })
    return systems.catalog, systems.route.storage, systems.controls.instances, systems.controls.templates, systems
end

local function storageLookup(storage)
    local lookup = {}
    for _, descriptor in ipairs(storage) do
        lookup[descriptor.key or descriptor.alias] = descriptor
    end
    return lookup
end

local function field(default)
    local value = default
    return {
        read = function()
            return value
        end,
        write = function(_, nextValue)
            value = nextValue
        end,
    }
end

local function fieldsFor(storage)
    local fields = {}
    for _, descriptor in ipairs(storage) do
        fields[descriptor.key] = field(descriptor.default)
    end
    return fields
end

local function namedInstance(instance, name)
    instance.name = name
    return instance
end

local function countKeys(values)
    local count = 0
    for _ in pairs(values) do
        count = count + 1
    end
    return count
end

function TestManagedPersistence.testBuildsFiniteModuleStorageForEveryBiomePlan()
    h.withImport(function()
        local _, storage = load()
        lu.assertEquals(#storage.biomes.ordered, 8)
        lu.assertEquals(#storage.moduleStorage, 18)

        local f = storage.biomes.lookup.Underworld_F
        lu.assertEquals(f.batches.storage.maxRows, 10)
        lu.assertEquals(f.targets.storage.maxRows, 20)
        lu.assertEquals(#f.globals.ordered, 0)

        local hBiome = storage.biomes.lookup.Underworld_H
        lu.assertEquals(hBiome.batches.columns.cageRoll, "CageRoll")
        lu.assertNil(hBiome.targets.columns.visitOrder)

        local iBiome = storage.biomes.lookup.Underworld_I
        lu.assertEquals(iBiome.globals.lookup.maxNonGoalRewards.storage.default, 0)
        lu.assertEquals(iBiome.globals.lookup.maxNonGoalRewards.values, { 3, 4, 5, 6 })

        local nBiome = storage.biomes.lookup.Surface_N
        lu.assertEquals(nBiome.globals.lookup.hubDoorCount.storage.default, 0)
        lu.assertEquals(nBiome.targets.columns.visitOrder, "VisitOrder")
        lu.assertNil(nBiome.targets.columns.picked)
    end)
end

function TestManagedPersistence.testBuildsStaticControlTaxonomyAndInstances()
    h.withImport(function()
        local catalog, _, instances, templates = load()
        local count = 0
        for name in pairs(instances) do
            count = count + 1
            lu.assertStrMatches(name, "^[A-Za-z][A-Za-z0-9_]*$")
        end
        lu.assertEquals(count, 211)
        lu.assertNotNil(templates.Route)
        for _, declaration in ipairs(catalog.roomTemplates.ordered) do
            lu.assertNotNil(templates[declaration.key], declaration.key)
        end
        lu.assertEquals(catalog.controlManifest.routes.lookup.Underworld.configuredPrefixValues, {
            "", "Underworld_F", "Underworld_G", "Underworld_H", "Underworld_I",
        })
        lu.assertEquals(instances.Underworld.configuredPrefixValues, { "" })
        lu.assertEquals(instances.Surface_Q_PreBoss01.template, "DirectPreboss")
        lu.assertEquals(instances.Underworld_F_PreBoss01.template, "ForkedPreboss")
        lu.assertEquals(instances.Underworld_F_PreBoss01.entryOfferPolicy.maxFreeRewards, 1)
        lu.assertEquals(instances.Underworld_G_PreBoss01.entryOfferPolicy.maxFreeRewards, 2)
    end)
end

function TestManagedPersistence.testManagedStateInstallsCompleteDeclarations()
    h.withImport(function()
        local _, _, _, _, systems = load()
        local captured = {}
        local module = {
            data = {
                define = function(storage)
                    captured.storage = storage
                end,
            },
            controls = {
                defineTemplates = function(templates)
                    captured.templates = templates
                end,
                define = function(instances)
                    captured.instances = instances
                end,
            },
        }

        local installed = systems.managedState.install(module)

        lu.assertEquals(#captured.storage, 18)
        lu.assertEquals(countKeys(captured.templates), 18)
        lu.assertEquals(countKeys(captured.instances), 211)
        lu.assertIs(captured.storage, installed.storage.moduleStorage)
    end)
end

function TestManagedPersistence.testSystemsComposesInjectedSubsystemsInOrder()
    local rawCatalog = { key = "raw" }
    local enrichedCatalog = { key = "enriched" }
    local controls = {
        catalog = enrichedCatalog,
        templates = {},
        instances = {},
    }
    local route = { storage = {}, stateAccess = {} }
    local managedState = { install = function() end }
    local calls = {}
    local systemFactory = h.testImport("mods/systems.lua", nil, {
        catalogAssembly = {
            create = function(overrides)
                calls[#calls + 1] = { name = "catalog", value = overrides }
                return rawCatalog
            end,
        },
        controlsAssembly = {
            create = function(catalog, opts)
                calls[#calls + 1] = { name = "controls", catalog = catalog, opts = opts }
                return controls
            end,
        },
        routeAssembly = {
            create = function(catalog)
                calls[#calls + 1] = { name = "route", catalog = catalog }
                return route
            end,
        },
    })
    local catalogOverrides = { routes = {} }

    local result = systemFactory.create({
        catalogOverrides = catalogOverrides,
        activePrefixEnds = { Underworld = "Underworld_G" },
        managedState = managedState,
    })

    lu.assertIs(result.catalog, enrichedCatalog)
    lu.assertIs(result.controls, controls)
    lu.assertIs(result.route, route)
    lu.assertIs(result.managedState, managedState)
    lu.assertEquals(calls[1], { name = "catalog", value = catalogOverrides })
    lu.assertIs(calls[2].catalog, rawCatalog)
    lu.assertEquals(calls[2].opts.activePrefixEnds, { Underworld = "Underworld_G" })
    lu.assertIs(calls[3].catalog, enrichedCatalog)
end

function TestManagedPersistence.testControlAssemblyDoesNotMutateValidatedCatalog()
    h.withImport(function()
        local catalogAssembly = h.testImport("mods/catalog/assembly.lua")
        local controlsAssembly = h.testImport("mods/controls/assembly.lua")
        local catalog = catalogAssembly.create()

        local controls = controlsAssembly.create(catalog)

        lu.assertNil(catalog.controlManifest)
        lu.assertNotNil(controls.catalog.controlManifest)
        lu.assertFalse(rawequal(catalog, controls.catalog))
        lu.assertIs(catalog.routes, controls.catalog.routes)
    end)
end

function TestManagedPersistence.testRoomSchemasCoverEveryBoundedSpecialSurface()
    h.withImport(function()
        local catalog = load()

        local f = storageLookup(catalog.controlManifest.rooms.lookup.Underworld_F_Combat04.state.storage)
        lu.assertNotNil(f.RewardStoreKey)
        lu.assertNotNil(f.RewardType)
        lu.assertNotNil(f.RewardPayload1)
        lu.assertNotNil(f.RewardPayload2)

        local fields = storageLookup(catalog.controlManifest.rooms.lookup.Underworld_H_Combat01.state.storage)
        lu.assertNotNil(fields.Cage1RewardType)
        lu.assertNotNil(fields.Cage3RewardPayload2)

        local clockwork = storageLookup(catalog.controlManifest.rooms.lookup.Underworld_I_Combat01.state.storage)
        lu.assertNotNil(clockwork.RewardIncomingKind)
        lu.assertNotNil(clockwork.RewardNonGoalType)

        local ephyra = storageLookup(catalog.controlManifest.rooms.lookup.Surface_N_Combat02.state.storage)
        lu.assertNotNil(ephyra.SideDoor1Generated)
        lu.assertNotNil(ephyra.SideDoor1EnteredOrder)
        lu.assertNotNil(ephyra.SideDoor1RewardType)

        local ship = storageLookup(catalog.controlManifest.rooms.lookup.Surface_O_Combat01.state.storage)
        lu.assertNotNil(ship.Combat2Present)
        lu.assertNotNil(ship.Wheel1OfferCount)
        lu.assertNotNil(ship.Wheel1Offer1Type)
        lu.assertNotNil(ship.Wheel2Offer2Payload2)

        local devotion = storageLookup(catalog.controlManifest.rooms.lookup.Surface_O_Devotion01.state.storage)
        lu.assertNotNil(devotion.RewardPayload1)
        lu.assertNotNil(devotion.RewardPayload2)
        lu.assertNil(devotion.RewardType)

        local shop = storageLookup(catalog.controlManifest.rooms.lookup.Underworld_F_Shop01.state.storage)
        lu.assertNotNil(shop.RewardBoonType)
        lu.assertNotNil(shop.RewardBoonPurchased)
        lu.assertNotNil(shop.RewardMinorPurchased)
    end)
end

function TestManagedPersistence.testRouteRefsShareReadsButOnlyUiCanWrite()
    h.withImport(function()
        local _, _, instances, templates = load({
            Underworld = "Underworld_G",
        })
        local instance = namedInstance(instances.Underworld, "Underworld")
        local fields = fieldsFor(templates.Route.storage(instance))
        local runtime = templates.Route.createRuntime(fields, instance)
        local ui = templates.Route.createUi(fields, instance)

        lu.assertEquals(runtime:read(), "")
        lu.assertEquals(ui:read(), "")
        lu.assertNil(runtime.write)
        ui:write("Underworld_G")
        lu.assertEquals(runtime:read(), "Underworld_G")
        lu.assertErrorMsgContains("does not allow value", function()
            ui:write("Surface_Q")
        end)
    end)
end

function TestManagedPersistence.testRoomRefsTranslateSemanticAddressesWithoutExposingFields()
    h.withImport(function()
        local _, _, instances, templates = load()
        local name = "Surface_O_Combat01"
        local instance = namedInstance(instances[name], name)
        local template = templates[instance.template]
        local fields = fieldsFor(template.storage(instance))
        local runtime = template.createRuntime(fields, instance)
        local ui = template.createUi(fields, instance)

        lu.assertNil(runtime.write)
        lu.assertNil(runtime.field)
        ui:write("phase.Combat2.present", true)
        ui:write("offer.wheel1.count", 2)
        ui:write("offer.wheel1.1", {
            storeKey = "RunProgress",
            rewardType = "Boon",
            payloadValues = { "ApolloUpgrade", "" },
        })

        lu.assertTrue(runtime:read("phase.Combat2.present"))
        lu.assertEquals(runtime:read("offer.wheel1.count"), 2)
        lu.assertEquals(runtime:read("offer.wheel1.1"), {
            storeKey = "RunProgress",
            rewardType = "Boon",
            payloadValues = { "ApolloUpgrade", "" },
        })
        lu.assertErrorMsgContains("expects an integer", function()
            ui:write("offer.wheel1.count", "2")
        end)
        lu.assertErrorMsgContains("payloadValues expects a table", function()
            ui:write("offer.wheel1.1", { payloadValues = "ApolloUpgrade" })
        end)
    end)
end

function TestManagedPersistence.testStateAccessKeepsRuntimeReadOnlyAndValidatesAuthoredGlobals()
    h.withImport(function()
        local catalog, storage, _, _, systems = load()
        local values = {
            Underworld_I_MaxNonGoalRewards = 4,
            Surface_N_HubDoorCount = 9,
        }
        local tables = {}
        for _, biome in ipairs(storage.biomes.ordered) do
            tables[biome.batches.alias] = {}
            tables[biome.targets.alias] = {}
        end
        tables.Underworld_F_Batches[1] = {
            ParentRoomControlKey = "Underworld_F_Opening01",
            RuleKey = "Standard",
        }

        local data = {}
        function data.read(alias)
            return values[alias]
        end
        function data.get(alias)
            local rows = tables[alias]
            if rows ~= nil then
                return {
                    count = function()
                        return #rows
                    end,
                    read = function(_, rowIndex, column)
                        return rows[rowIndex][column]
                    end,
                }
            end
            return field(values[alias])
        end
        local controls = {
            read = function(name, address)
                return name .. ":" .. tostring(address)
            end,
        }
        local runtime = systems.route.stateAccess.createRuntime({
            controls = controls,
            data = data,
        }, catalog, storage)

        lu.assertNil(runtime.writeRoute)
        lu.assertNil(runtime.writeRoom)
        lu.assertNil(runtime.writeBiomeGlobal)
        lu.assertEquals(runtime:readRoute("Underworld"), "Underworld:nil")
        lu.assertEquals(runtime:readRoom("Underworld_F_Combat04", "reward"),
            "Underworld_F_Combat04:reward")
        lu.assertEquals(runtime:readBiome("Underworld_F").batches[1], {
            parentRoomControlKey = "Underworld_F_Opening01",
            ruleKey = "Standard",
        })
        lu.assertEquals(runtime:readBiome("Underworld_I").globals.maxNonGoalRewards, 4)

        values.Underworld_I_MaxNonGoalRewards = 2
        lu.assertErrorMsgContains("does not allow value '2'", function()
            runtime:readBiome("Underworld_I")
        end)
    end)
end

function TestManagedPersistence.testConfigurationRevisionNormalizesCommitAndReloadWithoutDuplicates()
    h.withImport(function()
        local callbacks = {}
        local module = {
            onActivate = function(callback)
                callbacks.activate = callback
            end,
            onCommit = function(callback)
                callbacks.commit = callback
            end,
            onReload = function(callback)
                callbacks.reload = callback
            end,
        }
        local observed = {}
        local service = h.testImport("mods/composition/configuration_revision.lua").install(module, {
            onAdvance = function(_, _, event)
                observed[#observed + 1] = event.revision
            end,
        })

        callbacks.activate({}, {})
        callbacks.commit({}, {}, { hadConfigChanges = function() return false end })
        callbacks.commit({}, {}, { hadConfigChanges = function() return true end })
        callbacks.reload({}, {}, { hadSettingChanges = function() return false end })
        callbacks.reload({}, {}, { hadSettingChanges = function() return true end })

        lu.assertEquals(observed, { 1, 2, 3 })
        lu.assertEquals(service.current(), 3)
    end)
end
