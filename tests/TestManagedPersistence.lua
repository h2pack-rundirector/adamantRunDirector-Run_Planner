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

local function preparedInstance(instances, templates, name)
    local source = instances[name]
    local instance = {}
    for key, value in pairs(source) do
        instance[key] = value
    end
    instance.name = name
    local template = templates[instance.template]
    if template.prepare ~= nil then
        instance = template.prepare(instance)
    end
    return instance, template
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
        lu.assertEquals(#storage.moduleStorage, 27)

        local f = storage.biomes.lookup.Underworld_F
        lu.assertEquals(f.layoutKind, "LinearBiome")
        lu.assertEquals(f.batches.storage.maxRows, 10)
        lu.assertEquals(f.targets.storage.maxRows, 20)
        lu.assertNil(f.batches.columns.ruleKey)
        lu.assertEquals(f.selectedStart.values, {
            "", "Underworld_F_Opening01", "Underworld_F_Opening02", "Underworld_F_Opening03",
        })
        lu.assertEquals(#f.globals.ordered, 0)

        local hBiome = storage.biomes.lookup.Underworld_H
        lu.assertEquals(hBiome.batches.columns.cageRoll, "CageRoll")
        lu.assertNil(hBiome.targets.columns.visitOrder)

        local iBiome = storage.biomes.lookup.Underworld_I
        lu.assertEquals(iBiome.globals.lookup.maxNonGoalRewards.storage.default, 0)
        lu.assertEquals(iBiome.globals.lookup.maxNonGoalRewards.values, { 3, 4, 5, 6 })
        lu.assertEquals(iBiome.companionTargets.storage.maxRows, 1)

        local nBiome = storage.biomes.lookup.Surface_N
        lu.assertEquals(nBiome.layoutKind, "HubBiome")
        lu.assertEquals(nBiome.globals.lookup.hubDoorCount.storage.default, 0)
        lu.assertEquals(nBiome.hubTargets.columns.visitOrder, "VisitOrder")
        lu.assertNil(nBiome.hubTargets.columns.picked)
        lu.assertNil(nBiome.targets)
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

        lu.assertEquals(#captured.storage, 27)
        lu.assertEquals(countKeys(captured.templates), 18)
        lu.assertEquals(countKeys(captured.instances), 211)
        lu.assertIs(captured.storage, installed.storage.moduleStorage)
    end)
end

function TestManagedPersistence.testSystemsComposesInjectedSubsystemsInOrder()
    local rawRewards = { key = "raw rewards" }
    local rawCatalog = { key = "raw", rewards = rawRewards }
    local enrichedCatalog = { key = "enriched" }
    local rewardServices = { key = "reward services" }
    local controls = {
        catalog = enrichedCatalog,
        manifest = { key = "control manifest" },
        templates = {},
        instances = {},
    }
    local biomeSupport = { key = "biome support" }
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
        rewardAssembly = {
            create = function(rewards)
                calls[#calls + 1] = { name = "rewards", value = rewards }
                return rewardServices
            end,
        },
        controlsAssembly = {
            create = function(catalog, opts)
                calls[#calls + 1] = { name = "controls", catalog = catalog, opts = opts }
                return controls
            end,
        },
        biomeSupportAssembly = {
            create = function(catalog, manifest, evidence)
                calls[#calls + 1] = {
                    name = "biomeSupport",
                    catalog = catalog,
                    manifest = manifest,
                    evidence = evidence,
                }
                return biomeSupport
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
        biomeCapabilityEvidence = { topology = {} },
        managedState = managedState,
    })

    lu.assertIs(result.catalog, enrichedCatalog)
    lu.assertIs(result.rewards, rewardServices)
    lu.assertIs(result.controls, controls)
    lu.assertIs(result.biomeSupport, biomeSupport)
    lu.assertIs(result.route, route)
    lu.assertIs(result.managedState, managedState)
    lu.assertEquals(calls[1], { name = "catalog", value = catalogOverrides })
    lu.assertEquals(calls[2], { name = "rewards", value = rawRewards })
    lu.assertIs(calls[3].catalog, rawCatalog)
    lu.assertEquals(calls[3].opts.activePrefixEnds, { Underworld = "Underworld_G" })
    lu.assertIs(calls[4].catalog, enrichedCatalog)
    lu.assertEquals(calls[5], {
        name = "biomeSupport",
        catalog = enrichedCatalog,
        manifest = controls.manifest,
        evidence = { topology = {} },
    })
end

function TestManagedPersistence.testControlAssemblyDoesNotMutateValidatedCatalog()
    h.withImport(function()
        local catalogAssembly = h.testImport("mods/catalog/assembly.lua")
        local catalog = catalogAssembly.create()

        local controls = h.testImport("mods/systems.lua").create({ catalog = catalog }).controls

        lu.assertNil(catalog.controlManifest)
        lu.assertNotNil(controls.catalog.controlManifest)
        lu.assertFalse(rawequal(catalog, controls.catalog))
        lu.assertIs(catalog.routes, controls.catalog.routes)
    end)
end

function TestManagedPersistence.testRoomSchemasCoverEveryBoundedRewardBinding()
    h.withImport(function()
        local catalog, _, instances, templates = load()

        local standardCombat = preparedInstance(
            instances,
            templates,
            "Underworld_F_Combat04"
        )
        local f = storageLookup(templates.StandardCombat.storage(standardCombat))
        lu.assertNotNil(f.RewardStoreKey)
        lu.assertNotNil(f.RewardType)
        lu.assertNotNil(f.RewardPayload1)
        lu.assertNotNil(f.RewardPayload2)
        lu.assertNil(standardCombat.state)
        lu.assertNotNil(standardCombat.generatedReward)

        local fCombat01Instance = preparedInstance(
            instances,
            templates,
            "Underworld_F_Combat01"
        )
        local fCombat01 = storageLookup(
            templates.StandardCombat.storage(fCombat01Instance)
        )
        lu.assertNil(fCombat01.RewardStoreKey)
        lu.assertNotNil(fCombat01.RewardPayload1)
        lu.assertNil(fCombat01.RewardPayload2)

        local gCombat04Instance = preparedInstance(
            instances,
            templates,
            "Underworld_G_Combat04"
        )
        local gCombat04 = storageLookup(
            templates.StandardCombat.storage(gCombat04Instance)
        )
        lu.assertNotNil(gCombat04.RewardStoreKey)
        lu.assertNotNil(gCombat04.RewardPayload1)
        lu.assertNil(gCombat04.RewardPayload2)

        local fields = storageLookup(
            catalog.controlManifest.rooms.lookup.Underworld_H_Combat01.prepared.state.storage
        )
        lu.assertNotNil(fields.Cage1RewardType)
        lu.assertNotNil(fields.Cage3RewardPayload1)
        lu.assertNil(fields.Cage3RewardPayload2)

        local clockwork = storageLookup(
            catalog.controlManifest.rooms.lookup.Underworld_I_Combat01.prepared.state.storage
        )
        lu.assertNotNil(clockwork.RewardIncomingKind)
        lu.assertNotNil(clockwork.RewardNonGoalType)

        local ephyra = storageLookup(
            catalog.controlManifest.rooms.lookup.Surface_N_Combat02.prepared.state.storage
        )
        lu.assertNotNil(ephyra.SideDoor1Generated)
        lu.assertNotNil(ephyra.SideDoor1EnteredOrder)
        lu.assertNotNil(ephyra.SideDoor1RewardType)

        local ship = storageLookup(
            catalog.controlManifest.rooms.lookup.Surface_O_Combat01.prepared.state.storage
        )
        lu.assertNotNil(ship.Combat2Present)
        lu.assertNotNil(ship.Wheel1OfferCount)
        lu.assertNotNil(ship.Wheel1Offer1Type)
        lu.assertNotNil(ship.Wheel2Offer2Payload2)

        local devotion = storageLookup(
            catalog.controlManifest.rooms.lookup.Surface_O_Devotion01.prepared.state.storage
        )
        lu.assertNotNil(devotion.RewardPayload1)
        lu.assertNotNil(devotion.RewardPayload2)
        lu.assertNil(devotion.RewardType)

        local shopInstance = preparedInstance(
            instances,
            templates,
            "Underworld_F_Shop01"
        )
        local shop = storageLookup(templates.Shop.storage(shopInstance))
        lu.assertNotNil(shop.ShopBoonType)
        lu.assertNotNil(shop.ShopBoonPurchased)
        lu.assertNotNil(shop.ShopMinorPurchased)
    end)
end

function TestManagedPersistence.testStandardCombatUsesTypedRewardInterface()
    h.withImport(function()
        local _, _, instances, templates = load()
        local name = "Underworld_F_Combat04"
        local instance, template = preparedInstance(instances, templates, name)
        local fields = fieldsFor(template.storage(instance))
        local runtime = template.createRuntime(fields, instance)
        local ui = template.createUi(fields, instance)

        lu.assertEquals(runtime:read(), {
            kind = "StandardCombat",
            generatedReward = {},
        })
        lu.assertFalse(runtime:isComplete())
        lu.assertNil(runtime.write)
        lu.assertNil(runtime.setGeneratedReward)
        lu.assertNil(runtime.field)
        lu.assertNil(ui.write)

        ui:setGeneratedReward({
            storeKey = "RunProgress",
            rewardType = "Boon",
        })
        lu.assertEquals(runtime:read().generatedReward, {
            storeKey = "RunProgress",
            rewardType = "Boon",
        })
        lu.assertFalse(runtime:isComplete())

        ui:setGeneratedReward({
            storeKey = "RunProgress",
            rewardType = "Boon",
            payload = { source = "ApolloUpgrade" },
        })
        lu.assertEquals(runtime:read(), {
            kind = "StandardCombat",
            generatedReward = {
                storeKey = "RunProgress",
                rewardType = "Boon",
                payload = { source = "ApolloUpgrade" },
            },
        })
        lu.assertTrue(runtime:isComplete())

        ui:setGeneratedReward({
            storeKey = "RunProgress",
            rewardType = "Devotion",
            payload = { sources = { "ApolloUpgrade", "ZeusUpgrade" } },
        })
        lu.assertEquals(runtime:read().generatedReward, {
            storeKey = "RunProgress",
            rewardType = "Devotion",
            payload = { sources = { "ApolloUpgrade", "ZeusUpgrade" } },
        })
        lu.assertTrue(runtime:isComplete())

        lu.assertErrorMsgContains("is not available from store 'MetaProgress'", function()
            ui:setGeneratedReward({
                storeKey = "MetaProgress",
                rewardType = "Devotion",
            })
        end)
        lu.assertErrorMsgContains("unknown source 'MissingUpgrade'", function()
            ui:setGeneratedReward({
                storeKey = "RunProgress",
                rewardType = "Boon",
                payload = { source = "MissingUpgrade" },
            })
        end)
        lu.assertErrorMsgContains("sources must be distinct", function()
            ui:setGeneratedReward({
                storeKey = "RunProgress",
                rewardType = "Devotion",
                payload = { sources = { "ApolloUpgrade", "ApolloUpgrade" } },
            })
        end)
        lu.assertEquals(runtime:read().generatedReward, {
            storeKey = "RunProgress",
            rewardType = "Devotion",
            payload = { sources = { "ApolloUpgrade", "ZeusUpgrade" } },
        })

        ui:setGeneratedReward({})
        lu.assertEquals(runtime:read(), {
            kind = "StandardCombat",
            generatedReward = {},
        })
        lu.assertFalse(runtime:isComplete())

        fields.RewardStoreKey:write("MetaProgress")
        fields.RewardType:write("Boon")
        lu.assertErrorMsgContains("is not available from store 'MetaProgress'", function()
            runtime:read()
        end)
    end)
end

function TestManagedPersistence.testFocusedInstancesRemainLightweightUntilTemplatePreparation()
    h.withImport(function()
        local catalog, _, instances, templates = load()
        local count = 0
        for _, room in ipairs(catalog.controlManifest.rooms.ordered) do
            if room.templateKey == "StandardCombat" then
                count = count + 1
                lu.assertNil(room.prepared.state, room.key)
                lu.assertNil(room.prepared.generatedReward, room.key)
                lu.assertNil(instances[room.key].state, room.key)
                lu.assertNil(instances[room.key].generatedReward, room.key)

                local prepared = preparedInstance(instances, templates, room.key)
                lu.assertNotNil(prepared.generatedReward, room.key)
                lu.assertNotNil(prepared.generatedReward.view, room.key)
            end
        end
        lu.assertEquals(count, 56)
    end)
end

function TestManagedPersistence.testInstanceDeclarationsRejectPreparedCollaboratorFields()
    local builder = h.testImport("mods/controls/instances.lua")
    local catalog = {
        controlManifest = {
            routes = { ordered = {} },
            rooms = {
                ordered = {
                    {
                        key = "Underworld_F_Combat01",
                        templateKey = "StandardCombat",
                        routeKey = "Underworld",
                        biomeStepKey = "Underworld_F",
                        gameRoomKey = "F_Combat01",
                        incomingReward = {},
                        prepared = { generatedReward = {} },
                    },
                },
            },
        },
    }

    lu.assertErrorMsgContains("cannot enter Lib declaration field 'generatedReward'", function()
        builder.build(catalog)
    end)
end

function TestManagedPersistence.testTemplateRegistryRejectsImplicitFallbacks()
    local transitional = { template = {}, prepare = function() return {} end }
    local specialized = { template = {}, prepare = function() return {} end }
    local registry = h.testImport("mods/controls/templates.lua", nil, {
        route = {},
        transitionalRoom = transitional,
        standardCombat = specialized,
    })
    local catalog = {
        roomTemplates = {
            ordered = { { key = "UnknownTemplate" } },
        },
    }

    lu.assertErrorMsgContains("no control implementation registered", function()
        registry.build(catalog)
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
        local catalog, storage, instances, templates, systems = load()
        local values = {
            Underworld_I_MaxNonGoalRewards = 4,
            Surface_N_HubDoorCount = 9,
        }
        local tables = {}
        for _, descriptor in ipairs(storage.moduleStorage) do
            if descriptor.type == "table" then
                tables[descriptor.alias] = {}
            elseif values[descriptor.alias] == nil then
                values[descriptor.alias] = descriptor.default
            end
        end
        tables.Underworld_F_Batches[1] = {
            ParentRoomControlKey = "Underworld_F_Opening01",
        }
        tables.Underworld_I_TerminalCompanionTargets[1] = {
            ExitIndex = 2,
            RoomControlKey = "Underworld_I_Combat17",
        }
        tables.Surface_N_HubTargets[1] = {
            DoorIndex = 1,
            RoomControlKey = "Surface_N_Combat01",
            VisitOrder = 3,
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
        local routeInstance = namedInstance(instances.Underworld, "Underworld")
        local routeFields = fieldsFor(templates.Route.storage(routeInstance))
        local roomName = "Underworld_F_Combat04"
        local roomInstance, roomTemplate = preparedInstance(instances, templates, roomName)
        local roomFields = fieldsFor(roomTemplate.storage(roomInstance))
        local runtimeRefs = {
            Underworld = templates.Route.createRuntime(routeFields, routeInstance),
            [roomName] = roomTemplate.createRuntime(roomFields, roomInstance),
        }
        local uiRefs = {
            Underworld = templates.Route.createUi(routeFields, routeInstance),
            [roomName] = roomTemplate.createUi(roomFields, roomInstance),
        }
        local function controls(refs)
            return {
                get = function(name)
                    return refs[name]
                end,
                read = function(name, ...)
                    return refs[name]:read(...)
                end,
            }
        end
        local runtime = systems.route.stateAccess.createRuntime({
            controls = controls(runtimeRefs),
            data = data,
        }, catalog, storage)
        local ui = systems.route.stateAccess.createUi({
            controls = controls(uiRefs),
            data = data,
            resetAll = function() end,
        }, catalog, storage)

        lu.assertNil(runtime.writeRoute)
        lu.assertNil(runtime.writeRoom)
        lu.assertNil(runtime.writeBiomeGlobal)
        lu.assertEquals(runtime:readRoute("Underworld"), "")
        lu.assertEquals(runtime:readRoom(roomName), {
            kind = "StandardCombat",
            generatedReward = {},
        })
        lu.assertIs(runtime:getRoom(roomName), runtimeRefs[roomName])
        lu.assertNil(runtime:getRoom(roomName).setGeneratedReward)
        lu.assertIs(ui:getRoom(roomName), uiRefs[roomName])
        lu.assertNil(ui.writeRoom)
        ui:getRoom(roomName):setGeneratedReward({
            storeKey = "RunProgress",
            rewardType = "MaxHealthDrop",
        })
        lu.assertEquals(runtime:readRoom(roomName).generatedReward, {
            storeKey = "RunProgress",
            rewardType = "MaxHealthDrop",
        })
        lu.assertEquals(runtime:readBiome("Underworld_F").batches[1], {
            parentRoomControlKey = "Underworld_F_Opening01",
        })
        lu.assertEquals(runtime:readBiome("Underworld_F").layoutKind, "LinearBiome")
        lu.assertEquals(runtime:readBiome("Underworld_F").selectedStartRoomControlKey, "")
        lu.assertEquals(runtime:readBiome("Underworld_F").terminalTransition, {
            parentRoomControlKey = "",
        })
        lu.assertEquals(runtime:readBiome("Underworld_I").maxNonGoalRewards, 4)
        lu.assertEquals(runtime:readBiome("Underworld_I").terminalTransition.companionTargets, {
            { exitIndex = 2, roomControlKey = "Underworld_I_Combat17" },
        })
        lu.assertEquals(runtime:readBiome("Surface_N").layoutKind, "HubBiome")
        lu.assertEquals(runtime:readBiome("Surface_N").hubTargets, {
            { doorIndex = 1, roomControlKey = "Surface_N_Combat01", visitOrder = 3 },
        })
        lu.assertFalse(runtime:readBiome("Surface_N").terminalTransition)

        values.Underworld_F_SelectedStartRoomControlKey = "Underworld_F_Combat01"
        lu.assertErrorMsgContains("selected start does not allow value", function()
            runtime:readBiome("Underworld_F")
        end)
        values.Underworld_F_SelectedStartRoomControlKey = ""

        values.Underworld_I_MaxNonGoalRewards = 2
        lu.assertErrorMsgContains("does not allow value '2'", function()
            runtime:readBiome("Underworld_I")
        end)
    end)
end
