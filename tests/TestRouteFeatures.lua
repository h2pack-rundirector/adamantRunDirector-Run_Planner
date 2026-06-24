local lu = require("luaunit")
local h = require("tests.support.control_harness")
local normalizeRewardRows = h.normalizeRewardRows
local loadCatalog = h.loadCatalog
local loadFixedLinearTemplate = h.loadFixedLinearTemplate
local loadRouteGlobalTemplate = h.loadRouteGlobalTemplate
local loadRouteFeaturesTemplate = h.loadRouteFeaturesTemplate
local loadRunContext = h.loadRunContext
local routeDefinitions = h.routeDefinitions
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields

-- luacheck: globals TestRunPlannerRouteFeatures
TestRunPlannerRouteFeatures = {}

function TestRunPlannerRouteFeatures.testRouteFeaturesStorageDerivesSlotsFromDeclarations()
    local catalog = loadCatalog()
    local template = loadRouteFeaturesTemplate()
    local underworldWell = template.prepare({
        name = "RouteFeatureStygianWellUnderworld",
        route = catalog.routes.lookup.Underworld,
        feature = catalog.features.byKey.StygianWell,
        biomeLookup = catalog.lookup,
    })

    lu.assertEquals(underworldWell.slotCount, 10)
    lu.assertEquals(underworldWell.slots[1].key, "StygianWell1")
    lu.assertEquals(underworldWell.slots[1].label, "Entry 1")
    lu.assertEquals(underworldWell.slots[10].key, "StygianWell10")
    lu.assertEquals(underworldWell.slots[10].featureKey, "wellShop")
    lu.assertEquals(underworldWell.slots[10].plannedSpacingRooms, 4)

    local storage = template.storage(underworldWell)
    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "ManagedCount")
    lu.assertEquals(storage[1].type, "string")
    lu.assertEquals(storage[1].default, "1")
    lu.assertEquals(storage[2].key, "Targets")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 10)
    lu.assertEquals(storage[2].defaultRows, 10)
    lu.assertEquals(storage[2].maxRows, 10)
    lu.assertEquals(storage[2].row[1].key, "TargetKey")
    lu.assertEquals(storage[2].row[2].key, "BiomeKey")
    lu.assertEquals(storage[2].row[3].key, "RowIndex")

    local control = template.createRuntime(routeUiFields(storage), underworldWell)
    lu.assertEquals(control:rowCapacity(), 10)
    lu.assertEquals(control:rowCount(), 1)
    control:writeManagedCount("10")
    lu.assertEquals(control:rowCount(), 10)
    control:writeManagedCount("99")
    lu.assertEquals(control:rawManagedCount(), "10")
end

function TestRunPlannerRouteFeatures.testRouteFeaturesUsesBiomeRoomSelectionAndPolicies()
    local catalog = loadCatalog()
    local route = {
        key = "Surface",
        label = "Surface",
        biomes = { "P" },
    }
    local template = loadRouteFeaturesTemplate()
    local instance = template.prepare({
        name = "RouteFeatureHermesShrineSurface",
        route = route,
        feature = catalog.features.byKey.HermesShrine,
        biomeLookup = catalog.lookup,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        features = catalog.features,
        controlResolver = function(controlName)
            if controlName == "RouteP" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteP",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 0,
                                        slotLabel = "Intro",
                                        roomKey = "P_Intro",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 2,
                                        routeOrdinal = 1,
                                        slotLabel = "Depth 1",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 3,
                                        routeOrdinal = 2,
                                        slotLabel = "Depth 2",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 4,
                                        routeOrdinal = 3,
                                        slotLabel = "Depth 3",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 5,
                                        routeOrdinal = 4,
                                        slotLabel = "Depth 4",
                                        features = { surfaceShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 6,
                                        routeOrdinal = 5,
                                        slotLabel = "Depth 5",
                                        option = { key = "P_Combat01", label = "C01" },
                                        features = { surfaceShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 7,
                                        routeOrdinal = 6,
                                        slotLabel = "Depth 6",
                                        option = { key = "P_Combat02", label = "C02" },
                                        features = { surfaceShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, "Surface")

    lu.assertEquals(control:biomeOptions(1).values, { "", "P" })
    lu.assertEquals(control:biomeOptions(1).displayValues[""], "Vanilla")
    lu.assertEquals(control:biomeOptions(1).displayValues.P, "Olympus")

    control:writeBiome(1, "P")
    lu.assertEquals(fields.Targets:read(1, "BiomeKey"), "P")
    lu.assertEquals(control:roomOptions(1).values, { "", "6", "7" })
    lu.assertEquals(control:roomOptions(1).displayValues["6"], "Depth 5 - C01")

    control:writeRoom(1, "6")
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), "6")
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), "P:6")
    lu.assertEquals(control:selectedTargetKey(1), "P:6")
    lu.assertTrue(control:rowValidation(1).valid)

    control:writeTarget(1, "P:5")
    lu.assertEquals(control:rowValidation(1).code, "feature_target_unavailable")
    local featureSnapshot = control:buildSnapshot()
    lu.assertEquals(featureSnapshot.invalidRows[1].locationLabel, "Surface Hermes Shrine Entry 1")

    control:writeBiome(1, "")
    lu.assertEquals(fields.Targets:read(1, "BiomeKey"), nil)
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), nil)
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), nil)
    lu.assertTrue(control:rowValidation(1).valid)
end

function TestRunPlannerRouteFeatures.testRouteContextDisablesFeatureTargetsWhenFeaturesAreNotConfigured()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalSurface",
        route = catalog.routes.lookup.Surface,
        gods = catalog.gods,
    })
    local globalFields = routeUiFields(globalTemplate.storage(globalInstance))
    globalFields.ConfigureFeatures:write(false)
    local globalControl = globalTemplate.createRuntime(globalFields, globalInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Surface",
                label = "Surface",
                biomes = { "P" },
            },
        }),
        biomes = catalog.lookup,
        features = catalog.features,
        controlResolver = function(controlName)
            if controlName == "RouteGlobalSurface" then
                return globalControl
            elseif controlName == "RouteP" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteP",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 4,
                                        slotLabel = "Depth 4",
                                        option = { key = "P_Combat01", label = "C01" },
                                        features = { surfaceShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })

    local targets = routeContext:featureTargets("Surface")

    lu.assertNil(targets.byFeature.surfaceShop)
    lu.assertNil(targets.byFeatureBiome.surfaceShop)
end

function TestRunPlannerRouteFeatures.testRouteContextDisablesSpecificFeatureTargets()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalSurface",
        route = catalog.routes.lookup.Surface,
        gods = catalog.gods,
        features = catalog.features,
    })
    local globalFields = routeUiFields(globalTemplate.storage(globalInstance))
    globalFields.ConfigureFeatureHermesShrine:write(false)
    local globalControl = globalTemplate.createRuntime(globalFields, globalInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Surface",
                label = "Surface",
                biomes = { "P" },
            },
        }),
        biomes = catalog.lookup,
        features = catalog.features,
        controlResolver = function(controlName)
            if controlName == "RouteGlobalSurface" then
                return globalControl
            elseif controlName == "RouteP" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteP",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 4,
                                        slotLabel = "Depth 4",
                                        option = { key = "P_Combat01", label = "C01" },
                                        features = { surfaceShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })

    local targets = routeContext:featureTargets("Surface")

    lu.assertTrue(routeContext:isLayerConfigured("Surface", "features"))
    lu.assertFalse(routeContext:isFeatureConfigured("Surface", "HermesShrine"))
    lu.assertFalse(routeContext:hasConfiguredFeatures("Surface"))
    lu.assertNil(targets.byFeature.surfaceShop)
    lu.assertNil(targets.byFeatureBiome.surfaceShop)
    lu.assertNil(routeContext:featureTargetsForSlot("Surface", "surfaceShop"))
end

function TestRunPlannerRouteFeatures.testRouteFeaturesUsesShopDepthPolicy()
    local catalog = loadCatalog()
    local route = {
        key = "Surface",
        label = "Surface",
        biomes = { "O" },
    }
    local template = loadRouteFeaturesTemplate()
    local instance = template.prepare({
        name = "RouteFeatureHermesShrineSurface",
        route = route,
        feature = catalog.features.byKey.HermesShrine,
        biomeLookup = catalog.lookup,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        features = catalog.features,
        controlResolver = function(controlName)
            if controlName == "RouteO" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteO",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 0,
                                        slotLabel = "Intro",
                                        roomKey = "O_Intro",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 2,
                                        routeOrdinal = 1,
                                        slotLabel = "Depth 1",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 3,
                                        routeOrdinal = 2,
                                        slotLabel = "Depth 2",
                                        option = { key = "O_Combat01", label = "C01" },
                                        features = { surfaceShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 4,
                                        routeOrdinal = 3,
                                        slotLabel = "Depth 3",
                                        option = { key = "O_Combat02", label = "C02" },
                                        features = { surfaceShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, "Surface")

    control:writeBiome(1, "O")
    lu.assertEquals(control:roomOptions(1).values, { "", "4" })
    lu.assertEquals(control:roomOptions(1).displayValues["4"], "Depth 3 - C02")
end

function TestRunPlannerRouteFeatures.testRouteFeaturesRejectsRepeatedTargetsInsideSpacingWindow()
    local catalog = loadCatalog()
    local route = {
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }
    local template = loadRouteFeaturesTemplate()
    local instance = template.prepare({
        name = "RouteFeatureStygianWellUnderworld",
        route = route,
        feature = catalog.features.byKey.StygianWell,
        biomeLookup = catalog.lookup,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        features = catalog.features,
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 0,
                                        slotLabel = "Opening",
                                        roomKey = "F_Opening01",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 2,
                                        routeOrdinal = 1,
                                        slotLabel = "Depth 1",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 3,
                                        routeOrdinal = 2,
                                        slotLabel = "Depth 2",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 4,
                                        routeOrdinal = 3,
                                        slotLabel = "Depth 3",
                                        option = { key = "F_Combat01", label = "C01" },
                                        features = { wellShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 5,
                                        routeOrdinal = 4,
                                        slotLabel = "Depth 4",
                                        option = { key = "F_Combat02", label = "C02" },
                                        features = { wellShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, "Underworld")

    control:writeBiome(1, "F")
    control:writeRoom(1, "4")
    control:writeBiome(2, "F")
    control:writeRoom(2, "5")

    lu.assertTrue(control:rowValidation(1).valid)
    lu.assertTrue(control:rowValidation(2).valid)
    lu.assertEquals(#control:buildSnapshot().rows, 1)

    control:writeManagedCount("2")
    lu.assertEquals(control:rowValidation(2).code, "feature_spacing")
    local featureSnapshot = control:buildSnapshot()
    lu.assertEquals(#featureSnapshot.invalidRows, 2)
    lu.assertEquals(featureSnapshot.invalidRows[1].markerKind, "primary")
    lu.assertEquals(featureSnapshot.invalidRows[2].markerKind, "related")
    lu.assertEquals(control:valueStates(1, "RowIndex")["4"], 2)
    lu.assertEquals(control:valueStates(2, "RowIndex")["5"], 2)
    control:setRouteContext({
        canDecorateLayer = function()
            return false
        end,
    }, "Underworld")
    lu.assertNil(control:valueStates(1, "RowIndex"))
end

function TestRunPlannerRouteFeatures.testNpcInvalidSuppressesFeatureDecoration()
    local catalog = loadCatalog()
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        features = catalog.features,
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = true,
                                invalidRows = {},
                                rows = {},
                            }
                        end
                        return nil
                    end,
                }
            elseif controlName == "RouteNpcsUnderworld" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteNpcsUnderworld",
                                valid = false,
                                invalidRows = {
                                    {
                                        controlName = "RouteNpcsUnderworld",
                                        rowIndex = 1,
                                        code = "npc_invalid",
                                        message = "NPC invalid",
                                    },
                                },
                                rows = {},
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.layerStatus.route.valid)
    lu.assertFalse(overview.layerStatus.npcs.valid)
    lu.assertFalse(overview.layerStatus.features.canDecorate)
    lu.assertFalse(routeContext:canDecorateLayer("Underworld", "features"))
end

function TestRunPlannerRouteFeatures.testRouteFeaturesUsesTimelineBlockersForPostBossShops()
    local catalog = loadCatalog()
    local biomeLookup = {}
    for key, biome in pairs(catalog.lookup) do
        biomeLookup[key] = biome
    end
    biomeLookup.G = {}
    for key, value in pairs(catalog.lookup.G) do
        biomeLookup.G[key] = value
    end
    biomeLookup.G.featurePolicies = nil

    local route = {
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G" },
    }
    local template = loadRouteFeaturesTemplate()
    local instance = template.prepare({
        name = "RouteFeatureStygianWellUnderworld",
        route = route,
        feature = catalog.features.byKey.StygianWell,
        biomeLookup = catalog.lookup,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = biomeLookup,
        features = catalog.features,
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = true,
                                invalidRows = {},
                                rows = {},
                            }
                        end
                        return nil
                    end,
                }
            elseif controlName == "RouteG" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteG",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 3,
                                        slotLabel = "Depth 3",
                                        option = { key = "G_Combat01", label = "C01" },
                                        features = { wellShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, "Underworld")

    control:writeBiome(1, "G")
    control:writeRoom(1, "1")

    lu.assertEquals(control:rowValidation(1).code, "feature_spacing")
end

function TestRunPlannerRouteFeatures.testRouteFeaturesCanTargetEnabledSideRooms()
    local catalog = loadCatalog()
    local route = {
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }
    local template = loadRouteFeaturesTemplate()
    local instance = template.prepare({
        name = "RouteFeatureHermesShrineSurface",
        route = route,
        feature = catalog.features.byKey.HermesShrine,
        biomeLookup = catalog.lookup,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        features = catalog.features,
        controlResolver = function(controlName)
            if controlName == "RouteN" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteN",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 0,
                                        slotLabel = "Opening",
                                        roomKey = "N_Opening01",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 2,
                                        routeOrdinal = 1,
                                        slotLabel = "Pre-Hub",
                                        roomKey = "N_PreHub01",
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 3,
                                        routeOrdinal = 1,
                                        slotLabel = "Hub",
                                        roomKey = "N_Hub",
                                        valid = true,
                                        roomHistoryCost = 0,
                                    },
                                    {
                                        rowIndex = 4,
                                        routeOrdinal = 1,
                                        slotLabel = "Pylon 1",
                                        option = { key = "N_Combat01", label = "C01 (E)" },
                                        valid = true,
                                        roomHistoryCost = 2,
                                        sideRooms = {
                                            {
                                                sideIndex = 1,
                                                roomKey = "N_Sub01",
                                                enabled = true,
                                                features = { surfaceShop = true },
                                            },
                                        },
                                    },
                                    {
                                        rowIndex = 5,
                                        routeOrdinal = 2,
                                        slotLabel = "Pylon 2",
                                        option = { key = "N_Combat02", label = "C02 (W)" },
                                        valid = true,
                                        roomHistoryCost = 2,
                                        sideRooms = {
                                            {
                                                sideIndex = 1,
                                                roomKey = "N_Sub03",
                                                enabled = true,
                                                features = { surfaceShop = true },
                                            },
                                            {
                                                sideIndex = 2,
                                                roomKey = "N_Sub02",
                                                enabled = false,
                                                features = { surfaceShop = true },
                                            },
                                        },
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, "Surface")

    control:writeBiome(1, "N")
    lu.assertEquals(control:roomOptions(1).values, { "", "4.side1", "5.side1" })
    lu.assertEquals(control:roomOptions(1).displayValues["4.side1"], "Pylon 1 - C01 (E) / Side 1 - N_Sub01")
    lu.assertEquals(control:roomOptions(1).displayValues["5.side1"], "Pylon 2 - C02 (W) / Side 1 - N_Sub03")

    control:writeRoom(1, "4.side1")
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), "4.side1")
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), "N:4.side1")
    lu.assertTrue(control:rowValidation(1).valid)

    local targets = routeContext:featureTargetsForSlot("Surface", "surfaceShop", "N")
    lu.assertEquals(targets.lookup["N:4.side1"].roomHistoryDepth, 4)
    lu.assertEquals(targets.lookup["N:4.side1"].roomHistoryOrdinal, 5)
end

function TestRunPlannerRouteFeatures.testFixedLinearSnapshotsExportDerivedFeaturesOnlyForConcreteRooms()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local fInstance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fControl = template.createRuntime(routeFields({
        { OptionKey = "F_Opening02" },
        { RoleKey = "Combat" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
    }), fInstance)
    local fSnapshot = fControl:buildSnapshot()

    lu.assertEquals(fSnapshot.rows[1].roomKey, "F_Opening02")
    lu.assertEquals(fSnapshot.rows[1].features, { chaos = true })
    lu.assertNil(fSnapshot.rows[2].features)
    lu.assertEquals(fSnapshot.rows[3].roomKey, "F_Combat01")
    lu.assertEquals(fSnapshot.rows[3].features, { chaos = true, wellShop = true })

    local gInstance = template.prepare({
        name = "RouteG",
        biome = catalog.lookup.G,
    })
    local gControl = template.createRuntime(routeFields({
        {},
    }), gInstance)
    local gSnapshot = gControl:buildSnapshot()

    lu.assertEquals(gSnapshot.rows[1].roomKey, "G_Intro")
    lu.assertEquals(gSnapshot.rows[1].features, { chaos = true })
end
