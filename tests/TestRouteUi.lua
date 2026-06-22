local lu = require("luaunit")
local h = require("tests.support.control_harness")
local testImport = h.testImport
local withTestImport = h.withTestImport
local loadCatalog = h.loadCatalog
local loadFixedLinearTemplate = h.loadFixedLinearTemplate
local loadClockworkGoalTemplate = h.loadClockworkGoalTemplate
local loadHubPylonTemplate = h.loadHubPylonTemplate
local loadMultiEncounterTemplate = h.loadMultiEncounterTemplate
local loadFieldsCageTemplate = h.loadFieldsCageTemplate
local loadRouteGlobalTemplate = h.loadRouteGlobalTemplate
local loadRouteNpcsTemplate = h.loadRouteNpcsTemplate
local loadRouteFeaturesTemplate = h.loadRouteFeaturesTemplate
local loadRunContext = h.loadRunContext
local routeDefinitions = h.routeDefinitions
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw
local createUiControl = h.createUiControl
local measureAllocKb = h.measureAllocKb

-- luacheck: globals TestRunPlannerRouteUi
TestRunPlannerRouteUi = {}

local function loadValueStates()
    return dofile("src/mods/route/value_states.lua")
end

local function loadDecorations()
    local chunk = assert(loadfile("src/mods/ui/decorations.lua"))
    return chunk({
        valueStates = loadValueStates(),
    })
end

local function loadRouteStatus()
    local chunk = assert(loadfile("src/mods/ui/route_status.lua"))
    return chunk({
        decorations = loadDecorations(),
    })
end

function TestRunPlannerRouteUi.testRouteStatusDrawsFirstInvalidMessage()
    local routeStatus = loadRouteStatus()
    local rendered = {}
    local draw = {
        imgui = {
            Text = function(text)
                rendered[#rendered + 1] = text
            end,
            TextColored = function(_, _, _, _, text)
                rendered[#rendered + 1] = text
            end,
            SameLine = function()
                rendered[#rendered + 1] = "<same-line>"
            end,
            SetCursorPosX = function(x)
                rendered[#rendered + 1] = "<x:" .. tostring(x) .. ">"
            end,
        },
    }

    routeStatus.drawRouteStatus(draw, {
        label = "Underworld",
        valid = false,
        invalidRows = {
            {
                locationLabel = "Oceanus Depth 5 Rewards",
                message = "Trial requires 15 rooms since the previous Trial",
            },
        },
    })

    lu.assertEquals(rendered, {
        "Underworld Invalid:",
        "<same-line>",
        "<x:165>",
        "Oceanus Depth 5 Rewards: Trial requires 15 rooms since the previous Trial",
    })
end

function TestRunPlannerRouteUi.testCatalogBuildsControlsForSupportedAdapters()
    local catalog, data = loadCatalog()
    local controls = data.buildControls(catalog, testImport)

    lu.assertEquals(data.routeControlNames(catalog, testImport), {
        "RouteGlobalUnderworld",
        "RouteF",
        "RouteG",
        "RouteH",
        "RouteI",
        "RouteNpcsUnderworld",
        "RouteFeatureChaosGateUnderworld",
        "RouteFeatureStygianWellUnderworld",
        "RouteGlobalSurface",
        "RouteN",
        "RouteO",
        "RouteP",
        "RouteQ",
        "RouteNpcsSurface",
        "RouteFeatureChaosGateSurface",
        "RouteFeatureHermesShrineSurface",
    })
    lu.assertEquals(data.routeControlTabs(catalog, testImport).Underworld, {
        { key = "Global", label = "Global", controlName = "RouteGlobalUnderworld" },
        { key = "F", label = "Erebus", controlName = "RouteF" },
        { key = "G", label = "Oceanus", controlName = "RouteG" },
        { key = "H", label = "Fields", controlName = "RouteH" },
        { key = "I", label = "Tartarus", controlName = "RouteI" },
        { key = "NPCs", label = "NPCs", layer = "npcs", controlName = "RouteNpcsUnderworld" },
        {
            key = "Features",
            label = "Features",
            layer = "features",
            controlNames = {
                "RouteFeatureChaosGateUnderworld",
                "RouteFeatureStygianWellUnderworld",
            },
        },
    })
    lu.assertEquals(data.routeControlTabs(catalog, testImport).Surface, {
        { key = "Global", label = "Global", controlName = "RouteGlobalSurface" },
        { key = "N", label = "Ephyra", controlName = "RouteN" },
        { key = "O", label = "Thessaly", controlName = "RouteO" },
        { key = "P", label = "Olympus", controlName = "RouteP" },
        { key = "Q", label = "Summit", controlName = "RouteQ" },
        { key = "NPCs", label = "NPCs", layer = "npcs", controlName = "RouteNpcsSurface" },
        {
            key = "Features",
            label = "Features",
            layer = "features",
            controlNames = {
                "RouteFeatureChaosGateSurface",
                "RouteFeatureHermesShrineSurface",
            },
        },
    })
    lu.assertEquals(controls.RouteGlobalUnderworld.template, "RouteGlobal")
    lu.assertEquals(controls.RouteF.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteG.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteH.template, "FieldsCageRoute")
    lu.assertEquals(controls.RouteI.template, "ClockworkGoalRoute")
    lu.assertEquals(controls.RouteNpcsUnderworld.template, "RouteNpcs")
    lu.assertEquals(controls.RouteFeatureChaosGateUnderworld.template, "RouteFeatures")
    lu.assertEquals(controls.RouteFeatureStygianWellUnderworld.template, "RouteFeatures")
    lu.assertEquals(controls.RouteGlobalSurface.template, "RouteGlobal")
    lu.assertEquals(controls.RouteN.template, "HubPylonRoute")
    lu.assertEquals(controls.RouteO.template, "MultiEncounterFixedRoute")
    lu.assertEquals(controls.RouteP.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteQ.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteNpcsSurface.template, "RouteNpcs")
    lu.assertEquals(controls.RouteFeatureChaosGateSurface.template, "RouteFeatures")
    lu.assertEquals(controls.RouteFeatureHermesShrineSurface.template, "RouteFeatures")
end

function TestRunPlannerRouteUi.testRouteUiHidesTabsForDisabledLayers()
    local routeUi
    local capturedTabs
    local routeContext = {
        beginPass = function()
        end,
        bindControl = function(_, control)
            return control
        end,
        overview = function(_, routeKey)
            return {
                routeKey = routeKey,
                valid = true,
            }
        end,
        isLayerConfigured = function(_, _, layer)
            return layer ~= "npcs" and layer ~= "features"
        end,
    }
    withTestImport(function()
        routeUi = testImport("mods/ui.lua", nil, {
            routes = routeDefinitions({
                {
                    key = "Underworld",
                    label = "Underworld",
                    biomes = { "F" },
                },
            }),
            routeControlTabs = {
                Underworld = {
                    { key = "Global", label = "Global", controlName = "RouteGlobalUnderworld" },
                    { key = "F", label = "Erebus", controlName = "RouteF" },
                    { key = "NPCs", label = "NPCs", layer = "npcs", controlName = "RouteNpcsUnderworld" },
                    { key = "Features", label = "Features", layer = "features", controlNames = {} },
                },
            },
            routeContext = {
                create = function()
                    return routeContext
                end,
            },
            routeStatus = {
                drawRouteStatus = function()
                end,
            },
        })
    end)
    local draw = noOpDraw()
    draw.imgui.BeginTabBar = function()
        return true
    end
    draw.imgui.BeginTabItem = function(label)
        return label == "Underworld"
    end
    draw.imgui.BeginChild = function()
    end
    draw.imgui.EndChild = function()
    end
    draw.nav = {
        verticalTabs = function(opts)
            capturedTabs = opts.tabs
            return opts.tabs[1] and opts.tabs[1].key or nil
        end,
    }
    draw.control = function()
    end

    routeUi.drawTab(nil, {
        draw = draw,
        controls = {
            get = function()
                return {}
            end,
        },
    })

    lu.assertEquals(capturedTabs, {
        { key = "Global", label = "Global", controlNames = { "RouteGlobalUnderworld" } },
        { key = "F", label = "Erebus", controlNames = { "RouteF" } },
    })
end

function TestRunPlannerRouteUi.testDecorationsNavInvalidScansAllRowsAndPrefersControlOwnership()
    local decorations = loadDecorations()
    local snapshot = {
        valid = false,
        invalidRows = {
            {
                controlName = "RouteNpcsUnderworld",
                biomeKey = "F",
                message = "NPC conflict",
            },
            {
                controlName = "RouteF",
                biomeKey = "F",
                message = "Biome conflict",
            },
        },
    }

    lu.assertTrue(decorations.navTabInvalid(snapshot, {
        key = "F",
        controlNames = { "RouteF" },
    }))
    lu.assertTrue(decorations.navTabInvalid(snapshot, {
        key = "NPCs",
        controlNames = { "RouteNpcsUnderworld" },
    }))
end

function TestRunPlannerRouteUi.testRouteUiColorsInvalidRouteAndRegionTabs()
    local routeUi
    local capturedTabs
    local pushedColors = {}
    local firstInvalid = {
        controlName = "RouteF",
        biomeKey = "F",
        message = "Invalid route",
    }
    local secondInvalid = {
        controlName = "RouteG",
        biomeKey = "G",
        message = "Second invalid route",
    }
    local routeContext = {
        beginPass = function()
        end,
        bindControl = function(_, control)
            return control
        end,
        overview = function(_, routeKey)
            return {
                routeKey = routeKey,
                valid = false,
                invalidRows = { firstInvalid, secondInvalid },
            }
        end,
        isLayerConfigured = function()
            return true
        end,
    }

    withTestImport(function()
        routeUi = testImport("mods/ui.lua", nil, {
            routes = routeDefinitions({
                {
                    key = "Underworld",
                    label = "Underworld",
                    biomes = { "F", "G" },
                },
            }),
            routeControlTabs = {
                Underworld = {
                    { key = "Global", label = "Global", controlName = "RouteGlobalUnderworld" },
                    { key = "F", label = "Erebus", controlName = "RouteF" },
                    { key = "G", label = "Oceanus", controlName = "RouteG" },
                },
            },
            routeContext = {
                create = function()
                    return routeContext
                end,
            },
            routeStatus = {
                drawRouteStatus = function()
                end,
            },
        })
    end)

    local draw = noOpDraw()
    draw.imgui.BeginTabBar = function()
        return true
    end
    draw.imgui.BeginTabItem = function(label)
        return label == "Underworld"
    end
    draw.imgui.PushStyleColor = function(_, red, green, blue, alpha)
        pushedColors[#pushedColors + 1] = { red, green, blue, alpha }
    end
    draw.imgui.BeginChild = function()
    end
    draw.imgui.EndChild = function()
    end
    draw.nav = {
        verticalTabs = function(opts)
            capturedTabs = opts.tabs
            return opts.tabs[2] and opts.tabs[2].key or nil
        end,
    }
    draw.control = function()
    end

    routeUi.drawTab(nil, {
        draw = draw,
        controls = {
            get = function()
                return {}
            end,
        },
    })

    lu.assertEquals(pushedColors[1], { 1.0, 0.24, 0.16, 1.0 })
    lu.assertNil(capturedTabs[1].color)
    lu.assertEquals(capturedTabs[2].color, { 1.0, 0.24, 0.16, 1.0 })
    lu.assertEquals(capturedTabs[3].color, { 1.0, 0.24, 0.16, 1.0 })
end

function TestRunPlannerRouteUi.testDecorationsClassifyAllPlannerInvalids()
    local decorations = loadDecorations()
    local control = {
        name = function()
            return "RouteN"
        end,
    }
    local instance = {
        routeKey = "Surface",
        biomeKey = "N",
        routeContext = {
            overview = function()
                return {
                    valid = false,
                    invalidRows = {
                        {
                            controlName = "RouteN",
                            biomeKey = "N",
                            address = "row",
                            rewardType = "TalentDrop",
                        },
                        {
                            controlName = "RouteN",
                            biomeKey = "N",
                            address = "side:1",
                            rewardType = "MinorTalentDrop",
                        },
                    },
                }
            end,
        },
    }

    lu.assertFalse(decorations.plannerTabInvalid(control, "rooms", instance))
    lu.assertTrue(decorations.plannerTabInvalid(control, "rewards", instance))
    lu.assertTrue(decorations.plannerTabInvalid(control, "sideRooms", instance))
end

function TestRunPlannerRouteUi.testRouteTemplateViewsSupportNoOpUiTraversal()
    local catalog = loadCatalog()
    local cases = {
        { key = "F", template = loadFixedLinearTemplate() },
        { key = "G", template = loadFixedLinearTemplate() },
        { key = "H", template = loadFieldsCageTemplate() },
        { key = "I", template = loadClockworkGoalTemplate() },
        { key = "N", template = loadHubPylonTemplate() },
        { key = "O", template = loadMultiEncounterTemplate() },
        { key = "P", template = loadFixedLinearTemplate() },
        { key = "Q", template = loadFixedLinearTemplate() },
    }
    local draw = noOpDraw()
    local viewNames = { "rooms", "rewards", "sideRooms" }

    for _, case in ipairs(cases) do
        local control, instance = createUiControl(case.template, catalog.lookup[case.key], "Route" .. case.key)
        for _, viewName in ipairs(viewNames) do
            local view = case.template.views[viewName]
            if view ~= nil then
                view(draw, control, instance)
            end
        end
    end

    local globalTemplate = loadRouteGlobalTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local globalControl = globalTemplate.createUi(routeUiFields(globalTemplate.storage(globalInstance)), globalInstance)
    globalTemplate.views.planner(draw, globalControl, globalInstance)

    local routeNpcsTemplate = loadRouteNpcsTemplate()
    local routeNpcsInstance = routeNpcsTemplate.prepare({
        name = "RouteNpcsUnderworld",
        route = catalog.routes.lookup.Underworld,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local routeNpcsControl = routeNpcsTemplate.createUi(
        routeUiFields(routeNpcsTemplate.storage(routeNpcsInstance)),
        routeNpcsInstance
    )
    routeNpcsTemplate.views.planner(draw, routeNpcsControl, routeNpcsInstance)

    local routeFeaturesTemplate = loadRouteFeaturesTemplate()
    local routeFeaturesInstance = routeFeaturesTemplate.prepare({
        name = "RouteFeatureChaosGateUnderworld",
        route = catalog.routes.lookup.Underworld,
        feature = catalog.features.byKey.ChaosGate,
        biomeLookup = catalog.lookup,
    })
    local routeFeaturesControl = routeFeaturesTemplate.createUi(
        routeUiFields(routeFeaturesTemplate.storage(routeFeaturesInstance)),
        routeFeaturesInstance
    )
    routeFeaturesTemplate.views.planner(draw, routeFeaturesControl, routeFeaturesInstance)
end

function TestRunPlannerRouteUi.testRouteTemplateViewAllocationsStayBounded()
    local catalog = loadCatalog()
    local draw = noOpDraw()
    local iterations = 100
    local cases = {
        {
            key = "F",
            template = loadFixedLinearTemplate(),
            budgets = { rooms = 224, rewards = 128 },
        },
        {
            key = "G",
            template = loadFixedLinearTemplate(),
            budgets = { rooms = 192, rewards = 128 },
        },
        {
            key = "H",
            template = loadFieldsCageTemplate(),
            budgets = { rooms = 96, rewards = 96 },
        },
        {
            key = "I",
            template = loadClockworkGoalTemplate(),
            budgets = { rooms = 256, rewards = 160 },
        },
        {
            key = "N",
            template = loadHubPylonTemplate(),
            budgets = { rooms = 128, rewards = 128, sideRooms = 96 },
        },
        {
            key = "O",
            template = loadMultiEncounterTemplate(),
            budgets = { rooms = 160, rewards = 96 },
        },
        {
            key = "P",
            template = loadFixedLinearTemplate(),
            budgets = { rooms = 224, rewards = 128 },
        },
        {
            key = "Q",
            template = loadFixedLinearTemplate(),
            budgets = { rooms = 160, rewards = 96 },
        },
    }

    for _, case in ipairs(cases) do
        local control, instance = createUiControl(case.template, catalog.lookup[case.key], "Route" .. case.key)
        for viewName, budgetKb in pairs(case.budgets) do
            local view = case.template.views[viewName]
            local allocatedKb = measureAllocKb(iterations, function()
                view(draw, control, instance)
            end)

            lu.assertTrue(
                allocatedKb < budgetKb,
                string.format(
                    "Route%s %s traversal allocated %.1f KB across %d no-op draws; budget %.1f KB",
                    case.key,
                    viewName,
                    allocatedKb,
                    iterations,
                    budgetKb
                )
            )
        end
    end

    local routeGlobalTemplate = loadRouteGlobalTemplate()
    local routeGlobalInstance = routeGlobalTemplate.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local routeGlobalFields = routeUiFields(routeGlobalTemplate.storage(routeGlobalInstance))
    routeGlobalFields.ConfigureRewards:write(false)
    local routeGlobalControl = routeGlobalTemplate.createUi(routeGlobalFields, routeGlobalInstance)
    local allocatedKb = measureAllocKb(iterations, function()
        routeGlobalTemplate.views.planner(draw, routeGlobalControl, routeGlobalInstance)
    end)
    lu.assertTrue(
        allocatedKb < 64,
        string.format(
            "RouteGlobal traversal allocated %.1f KB across %d no-op draws; budget %.1f KB",
            allocatedKb,
            iterations,
            64
        )
    )

    local routeNpcsTemplate = loadRouteNpcsTemplate()
    local routeNpcsInstance = routeNpcsTemplate.prepare({
        name = "RouteNpcsUnderworld",
        route = catalog.routes.lookup.Underworld,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local routeNpcsControl = routeNpcsTemplate.createUi(
        routeUiFields(routeNpcsTemplate.storage(routeNpcsInstance)),
        routeNpcsInstance
    )
    allocatedKb = measureAllocKb(iterations, function()
        routeNpcsTemplate.views.planner(draw, routeNpcsControl, routeNpcsInstance)
    end)
    lu.assertTrue(
        allocatedKb < 96,
        string.format(
            "RouteNpcs traversal allocated %.1f KB across %d no-op draws; budget %.1f KB",
            allocatedKb,
            iterations,
            96
        )
    )

    local routeFeaturesTemplate = loadRouteFeaturesTemplate()
    local routeFeaturesInstance = routeFeaturesTemplate.prepare({
        name = "RouteFeatureChaosGateUnderworld",
        route = catalog.routes.lookup.Underworld,
        feature = catalog.features.byKey.ChaosGate,
        biomeLookup = catalog.lookup,
    })
    local routeFeaturesControl = routeFeaturesTemplate.createUi(
        routeUiFields(routeFeaturesTemplate.storage(routeFeaturesInstance)),
        routeFeaturesInstance
    )
    allocatedKb = measureAllocKb(iterations, function()
        routeFeaturesTemplate.views.planner(draw, routeFeaturesControl, routeFeaturesInstance)
    end)
    lu.assertTrue(
        allocatedKb < 64,
        string.format(
            "RouteFeatures traversal allocated %.1f KB across %d no-op draws; budget %.1f KB",
            allocatedKb,
            iterations,
            64
        )
    )
end

function TestRunPlannerRouteUi.testRouteOverviewRebuildsOnlyWhenDirty()
    local readsByControl = {}
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "RouteA",
                label = "Route A",
                biomes = { "F", "G" },
            },
            {
                key = "RouteB",
                label = "Route B",
                biomes = { "G" },
            },
        }),
        controlResolver = function(controlName)
            return {
                read = function(_, path)
                    if path == "snapshot" then
                        readsByControl[controlName] = (readsByControl[controlName] or 0) + 1
                        return {
                            controlName = controlName,
                            valid = true,
                            invalidRows = {},
                            rows = {},
                        }
                    end
                    return nil
                end,
            }
        end,
    })

    routeContext:beginPass()
    lu.assertTrue(routeContext:overview("RouteA").valid)
    lu.assertTrue(routeContext:overview("RouteA").valid)
    lu.assertEquals(readsByControl.RouteF, 1)
    lu.assertEquals(readsByControl.RouteG, 1)

    routeContext:beginPass()
    lu.assertTrue(routeContext:overview("RouteA").valid)
    lu.assertEquals(readsByControl.RouteF, 1)
    lu.assertEquals(readsByControl.RouteG, 1)

    routeContext:markDirty("RouteA")
    routeContext:beginPass()
    lu.assertTrue(routeContext:overview("RouteA").valid)
    lu.assertEquals(readsByControl.RouteF, 2)
    lu.assertEquals(readsByControl.RouteG, 2)

    routeContext:beginPass()
    lu.assertTrue(routeContext:overview("RouteB").valid)
    lu.assertEquals(readsByControl.RouteG, 3)

    routeContext:markDirty(nil, "G")
    routeContext:beginPass()
    lu.assertTrue(routeContext:overview("RouteA").valid)
    lu.assertTrue(routeContext:overview("RouteB").valid)
    lu.assertEquals(readsByControl.RouteF, 3)
    lu.assertEquals(readsByControl.RouteG, 5)
end
