local lu = require("luaunit")

-- luacheck: globals TestRunPlannerControls
TestRunPlannerControls = {}

local function testImport(path, _, deps)
    local chunk = assert(loadfile("src/" .. path))
    return chunk(deps)
end

local function withTestImport(callback)
    local previousImport = _G.import
    _G.import = testImport
    local ok, err = pcall(callback)
    _G.import = previousImport
    if not ok then
        error(err, 0)
    end
end

local function normalizeRewardRows(rows)
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    for _, row in ipairs(rows or {}) do
        rewardItems.attach(row)
    end
    return rows
end

local function primaryRewardItem(row)
    return row and row.rewardItems and row.rewardItems[1] or nil
end

local function rewardItemBySource(row, sourceKind, sourceIndex)
    for _, item in ipairs(row and row.rewardItems or {}) do
        if item.sourceKind == sourceKind and (sourceIndex == nil or item.sourceIndex == sourceIndex) then
            return item
        end
    end
    return nil
end

local function loadCatalog()
    local data = dofile("src/mods/data.lua")
    return data.loadCatalog(testImport), data
end

local function loadRouteDeps()
    local route
    withTestImport(function()
        local rewards = testImport("mods/rewards/rewards.lua").create({
            definitions = testImport("mods/rewards/declarations/definitions.lua"),
        })
        local timeline = testImport("mods/route/timeline.lua")
        local rows = testImport("mods/route/rows.lua", nil, {
            rewards = rewards,
            timeline = timeline,
        })
        route = {
            common = rows.common,
            availability = rows.availability,
            readCache = rows.readCache,
            requirements = rows.requirements,
            biomeRules = rows.biomeRules,
            rowEngine = rows.engine,
            timeline = timeline,
            rewards = rewards,
        }
    end)
    return route
end

local loadedControlTemplates

local function loadControlTemplates()
    if loadedControlTemplates == nil then
        withTestImport(function()
            local catalog, data = loadCatalog()
            loadedControlTemplates = testImport("mods/systems.lua").create({
                data = data,
                catalog = catalog,
            }).controlTemplates
        end)
    end
    return loadedControlTemplates
end

local function loadFixedLinearTemplate()
    return loadControlTemplates().FixedLinearRoute
end

local function loadClockworkGoalTemplate()
    return loadControlTemplates().ClockworkGoalRoute
end

local function loadHubPylonTemplate()
    return loadControlTemplates().HubPylonRoute
end

local function loadMultiEncounterTemplate()
    return loadControlTemplates().MultiEncounterFixedRoute
end

local function loadFieldsCageTemplate()
    return loadControlTemplates().FieldsCageRoute
end

local function loadRouteGlobalTemplate()
    return loadControlTemplates().RouteGlobal
end

local function loadRouteNpcsTemplate()
    return loadControlTemplates().RouteNpcs
end

local function loadRouteFeaturesTemplate()
    return loadControlTemplates().RouteFeatures
end

local function loadRewardLegality()
    return testImport("mods/route/reward_planning/legality.lua", nil, {
        conditions = testImport("mods/rewards/declarations/conditions.lua"),
        timeline = testImport("mods/route/timeline.lua"),
        rewardItems = testImport("mods/route/reward_planning/items.lua"),
        semantics = testImport("mods/route/reward_planning/semantics.lua"),
        invalidLocations = testImport("mods/route/invalid_locations.lua"),
    })
end

local function loadRouteTargets(timeline, rewardItems, semantics)
    local targetCommon = testImport("mods/route/run_context/targets/common.lua")
    return testImport("mods/route/run_context/targets.lua", nil, {
        npcs = testImport("mods/route/run_context/targets/npcs.lua", nil, {
            timeline = timeline,
            rewardItems = rewardItems,
            semantics = semantics,
            common = targetCommon,
        }),
        features = testImport("mods/route/run_context/targets/features.lua", nil, {
            timeline = timeline,
            common = targetCommon,
        }),
    })
end

local function loadFixedLinearData()
    return testImport("mods/controls/FixedLinearRoute/data.lua", nil, loadRouteDeps())
end

local function loadClockworkGoalData()
    return testImport("mods/controls/ClockworkGoalRoute/data.lua", nil, loadRouteDeps())
end

local function loadHubPylonData()
    return testImport("mods/controls/HubPylonRoute/data.lua", nil, loadRouteDeps())
end

local function loadMultiEncounterData()
    return testImport("mods/controls/MultiEncounterFixedRoute/data.lua", nil, loadRouteDeps())
end

local function loadFieldsCageData()
    return testImport("mods/controls/FieldsCageRoute/data.lua", nil, loadRouteDeps())
end

local function loadRunContext()
    local timeline = testImport("mods/route/timeline.lua")
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    local semantics = testImport("mods/route/reward_planning/semantics.lua")
    return testImport("mods/route/run_context.lua", nil, {
        controls = testImport("mods/route/run_context/controls.lua"),
        targets = loadRouteTargets(timeline, rewardItems, semantics),
        rewards = testImport("mods/route/run_context/rewards.lua", nil, {
            rewardLegality = loadRewardLegality(),
            rewardItems = rewardItems,
            semantics = semantics,
        }),
    })
end

local function routeDefinitions(routes)
    local lookup = {}
    for _, route in ipairs(routes or {}) do
        lookup[route.key] = route
    end
    return {
        ordered = routes,
        lookup = lookup,
    }
end

local function hasValue(values, expected)
    for _, value in ipairs(values) do
        if value == expected then
            return true
        end
    end
    return false
end

local function optionByKey(options, expected)
    for _, option in ipairs(options or {}) do
        if option.key == expected then
            return option
        end
    end
    return nil
end

local function fakeRows(rows)
    return {
        count = function()
            return #rows
        end,
        read = function(_, rowIndex, alias)
            return rows[rowIndex] and rows[rowIndex][alias] or nil
        end,
    }
end

local function routeFields(rows, sideRows, sideRewardRows, encounterRewardRows, cageRewardRows)
    return {
        Rooms = fakeRows(rows or {}),
        Rewards = fakeRows(rows or {}),
        SideRooms = fakeRows(sideRows or {}),
        SideRewards = fakeRows(sideRewardRows or {}),
        EncounterRewards = fakeRows(encounterRewardRows or {}),
        CageRewards = fakeRows(cageRewardRows or {}),
    }
end

local function npcFields(rows)
    return {
        Targets = fakeRows(rows or {}),
    }
end

local function fakeUiRows(rowCount)
    local rows = {}
    local fields = {}
    for rowIndex = 1, rowCount do
        rows[rowIndex] = {}
        fields[rowIndex] = {}
    end

    return {
        count = function()
            return rowCount
        end,
        read = function(_, rowIndex, alias)
            return rows[rowIndex] and rows[rowIndex][alias] or nil
        end,
        get = function(_, rowIndex, alias)
            local rowFields = fields[rowIndex]
            if rowFields == nil then
                return nil
            end

            local field = rowFields[alias]
            if field == nil then
                field = {
                    read = function()
                        return rows[rowIndex] and rows[rowIndex][alias] or nil
                    end,
                    write = function(_, value)
                        if rows[rowIndex] then
                            rows[rowIndex][alias] = value
                        end
                    end,
                }
                rowFields[alias] = field
            end
            return field
        end,
        reset = function(_, rowIndex, alias)
            if rows[rowIndex] then
                rows[rowIndex][alias] = nil
            end
        end,
    }
end

local function fakePackedField(root)
    local values = {}
    for _, bit in ipairs(root.bits or {}) do
        values[bit.key] = bit.default == true
    end

    return {
        read = function()
            return 0
        end,
        get = function()
            return nil
        end,
        readAlias = function(_, alias)
            return values[alias]
        end,
        writeAlias = function(_, alias, value)
            values[alias] = value == true
        end,
        schema = function()
            return root
        end,
        alias = function()
            return root.key
        end,
        controlId = function()
            return root.key
        end,
    }
end

local function fakeStringField(root)
    local value = root.default or ""
    return {
        read = function()
            return value
        end,
        write = function(_, nextValue)
            value = nextValue
        end,
        schema = function()
            return root
        end,
        alias = function()
            return root.key
        end,
        controlId = function()
            return root.key
        end,
    }
end

local function fakeBoolField(root)
    local value = root.default == true
    return {
        read = function()
            return value
        end,
        write = function(_, nextValue)
            value = nextValue == true
        end,
        schema = function()
            return root
        end,
        alias = function()
            return root.key
        end,
        controlId = function()
            return root.key
        end,
    }
end

local function routeUiFields(storage)
    local fields = {}
    for _, root in ipairs(storage or {}) do
        if root.type == "table" then
            fields[root.key] = fakeUiRows(root.defaultRows or root.maxRows or root.minRows or 0)
        elseif root.type == "packedInt" then
            fields[root.key] = fakePackedField(root)
        elseif root.type == "string" then
            fields[root.key] = fakeStringField(root)
        elseif root.type == "bool" then
            fields[root.key] = fakeBoolField(root)
        end
    end
    return fields
end

local function noOpDraw()
    local imgui = {
        BeginTabBar = function()
            return false
        end,
        BeginTabItem = function()
            return false
        end,
        Checkbox = function(_, current)
            return current, false
        end,
        EndTabBar = function()
        end,
        EndTabItem = function()
        end,
        PopStyleColor = function()
        end,
        PushStyleColor = function()
        end,
        GetCursorPosX = function()
            return 0
        end,
    }
    for _, name in ipairs({
        "AlignTextToFramePadding",
        "Text",
        "SameLine",
        "SetCursorPosX",
        "Spacing",
        "Separator",
    }) do
        imgui[name] = function()
        end
    end

    return {
        imgui = imgui,
        widgets = {
            text = function()
            end,
            dropdown = function()
                return false
            end,
            packedCheckboxList = function()
                return false
            end,
        },
    }
end

local function createUiControl(template, biome, name)
    local instance = template.prepare({
        name = name or ("Route" .. biome.key),
        biome = biome,
    })
    return template.createUi(routeUiFields(template.storage(instance)), instance), instance
end

local function measureAllocKb(iterations, callback)
    callback()
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, iterations do
        callback()
    end
    local after = collectgarbage("count")
    collectgarbage("restart")
    return after - before
end

function TestRunPlannerControls.testRouteStatusDrawsFirstInvalidMessage()
    local routeStatus = dofile("src/mods/ui/route_status.lua")
    local rendered = {}
    local draw = {
        imgui = {
            Text = function(text)
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

function TestRunPlannerControls.testRewardItemsNormalizeRowRewardMetadata()
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    local row = {
        rowIndex = 2,
        routeOrdinal = 2,
        slotLabel = "Depth 2",
        rewardKind = "majorMinor",
        rewards = { "Major", "Boon", "ZeusUpgrade" },
        rewardPicks = {
            { kind = "boonSource", value = "ZeusUpgrade" },
        },
        sideRooms = {
            {
                sideIndex = 1,
                rewardKind = "roomStore",
                rewards = { "MaxHealthDrop" },
            },
        },
        cageRewards = {
            {
                cageIndex = 2,
                rewardKind = "fixedReward",
                rewards = { "Boon" },
            },
        },
        encounterRewardLegs = {
            {
                legIndex = 3,
                rewardKind = "roomStore",
                rewards = { "RoomMoneyDrop" },
            },
        },
    }

    rewardItems.attach(row)

    lu.assertEquals(#row.rewardItems, 4)
    lu.assertEquals(row.rewardItems[1].address, "row")
    lu.assertEquals(row.rewardItems[1].rowLabel, "Depth 2")
    lu.assertEquals(row.rewardItems[1].sourceLabel, "Rewards")
    lu.assertEquals(row.rewardItems[1].sourceKind, "row")
    lu.assertEquals(row.rewardItems[1].rewards[2], "Boon")
    lu.assertEquals(row.rewardItems[2].address, "side:1")
    lu.assertEquals(row.rewardItems[2].sourceLabel, "Side Room 1 Reward")
    lu.assertEquals(row.rewardItems[2].sourceKind, "side")
    lu.assertEquals(row.rewardItems[3].address, "cage:2")
    lu.assertEquals(row.rewardItems[3].sourceLabel, "Cage 2 Reward")
    lu.assertEquals(row.rewardItems[3].sourceKind, "cage")
    lu.assertEquals(row.rewardItems[4].address, "encounter:3")
    lu.assertEquals(row.rewardItems[4].sourceLabel, "Combat 3 Reward")
    lu.assertEquals(row.rewardItems[4].sourceKind, "encounter")

    local scratch = {}
    lu.assertIs(rewardItems.collect(row, scratch), scratch)
    lu.assertEquals(#scratch, 4)
    lu.assertEquals(scratch[3].address, "cage:2")
end

function TestRunPlannerControls.testCatalogBuildsControlsForSupportedAdapters()
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

function TestRunPlannerControls.testRouteGlobalTemplateStoresConfigurationAndGodPool()
    local catalog = loadCatalog()
    local template = loadRouteGlobalTemplate()
    local instance = template.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local storage = template.storage(instance)
    local control = template.createRuntime(routeUiFields(storage), instance)

    lu.assertEquals(storage[1], {
        key = "ConfigureRewards",
        type = "bool",
        default = true,
    })
    lu.assertEquals(storage[2], {
        key = "ConfigureNpcs",
        type = "bool",
        default = true,
    })
    lu.assertEquals(storage[3], {
        key = "ConfigureFeatures",
        type = "bool",
        default = true,
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

function TestRunPlannerControls.testRouteGlobalConfigurationPreservesNpcDependencyOnRewards()
    local catalog = loadCatalog()
    local template = loadRouteGlobalTemplate()
    local instance = template.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)

    lu.assertTrue(control:isLayerConfigured("rewards"))
    lu.assertTrue(control:isLayerConfigured("npcs"))
    lu.assertTrue(control:isLayerConfigured("features"))

    fields.ConfigureRewards:write(false)

    lu.assertFalse(control:isLayerConfigured("rewards"))
    lu.assertFalse(control:isLayerConfigured("npcs"))
    lu.assertTrue(control:isLayerConfigured("features"))

    fields.ConfigureRewards:write(true)
    fields.ConfigureNpcs:write(false)
    fields.ConfigureFeatures:write(false)

    lu.assertTrue(control:isLayerConfigured("rewards"))
    lu.assertFalse(control:isLayerConfigured("npcs"))
    lu.assertFalse(control:isLayerConfigured("features"))
end

function TestRunPlannerControls.testRouteGlobalDrawDisablesNpcToggleWhenRewardsAreDisabled()
    local catalog = loadCatalog()
    local template = loadRouteGlobalTemplate()
    local instance = template.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.ConfigureRewards:write(false)
    fields.ConfigureNpcs:write(true)
    local control = template.createUi(fields, instance)

    local draw = noOpDraw()
    local disabledDepth = 0
    local npcCheckboxWasDisabled = false
    local noteWasRendered = false
    draw.imgui.BeginDisabled = function(disabled)
        if disabled then
            disabledDepth = disabledDepth + 1
        end
    end
    draw.imgui.EndDisabled = function()
        disabledDepth = disabledDepth - 1
    end
    draw.imgui.TextWrapped = function(text)
        if text == "Disabling rewards invalidates Trial rewards and disables NPC encounter planning." then
            noteWasRendered = true
        end
    end
    draw.imgui.Checkbox = function(label, current)
        if label:find("Configure NPC Encounters", 1, true) then
            npcCheckboxWasDisabled = disabledDepth > 0
            return false, true
        end
        return current, false
    end

    template.views.planner(draw, control, instance)

    lu.assertTrue(noteWasRendered)
    lu.assertTrue(npcCheckboxWasDisabled)
    lu.assertTrue(fields.ConfigureNpcs:read())
end

function TestRunPlannerControls.testRouteUiHidesTabsForDisabledLayers()
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
        { key = "Global", label = "Global" },
        { key = "F", label = "Erebus" },
    })
end

function TestRunPlannerControls.testRouteGlobalProvidesStableGodSourceDropdownOptions()
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
    lu.assertEquals(opts.valueColors.AphroditeUpgrade, catalog.gods[1].color)

    control:godPoolField():writeAlias("AphroditeUpgrade", false)
    control:invalidateGodSource()

    local updatedOpts = control:godSourceDrawOpts(baseOpts, "")
    lu.assertIs(updatedOpts, opts)
    lu.assertFalse(hasValue(updatedOpts.values, "AphroditeUpgrade"))

    local currentValueOpts = control:godSourceDrawOpts(baseOpts, "AphroditeUpgrade")
    lu.assertIs(currentValueOpts, opts)
    lu.assertTrue(hasValue(currentValueOpts.values, "AphroditeUpgrade"))
end

function TestRunPlannerControls.testRouteNpcsStorageDerivesSlotsFromDeclarations()
    local catalog = loadCatalog()
    local template = loadRouteNpcsTemplate()
    local underworld = template.prepare({
        name = "RouteNpcsUnderworld",
        route = catalog.routes.lookup.Underworld,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local surface = template.prepare({
        name = "RouteNpcsSurface",
        route = catalog.routes.lookup.Surface,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })

    lu.assertEquals(underworld.slotCount, 4)
    lu.assertEquals(underworld.slots[1].key, "Artemis")
    lu.assertEquals(underworld.slots[1].label, "Artemis")
    lu.assertEquals(underworld.slots[2].key, "Nemesis")
    lu.assertEquals(underworld.slots[3].key, "Arachne_F")
    lu.assertEquals(underworld.slots[3].label, "Arachne")
    lu.assertEquals(underworld.slots[3].fixedBiomeKey, "F")
    lu.assertEquals(underworld.slots[4].key, "Arachne_G")
    lu.assertEquals(underworld.slots[4].label, "Arachne")

    lu.assertEquals(surface.slotCount, 4)
    lu.assertEquals(surface.slots[1].key, "Artemis")
    lu.assertEquals(surface.slots[2].key, "Heracles")
    lu.assertEquals(surface.slots[3].key, "Icarus")
    lu.assertEquals(surface.slots[4].key, "Athena")

    local storage = template.storage(underworld)
    lu.assertEquals(#storage, 1)
    lu.assertEquals(storage[1].key, "Targets")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 4)
    lu.assertEquals(storage[1].defaultRows, 4)
    lu.assertEquals(storage[1].maxRows, 4)
    lu.assertEquals(storage[1].row[1].key, "TargetKey")
    lu.assertEquals(storage[1].row[2].key, "VariantKey")
    lu.assertEquals(storage[1].row[3].key, "BiomeKey")
    lu.assertEquals(storage[1].row[4].key, "RowIndex")
end

function TestRunPlannerControls.testRouteNpcsUsesBiomeRoomTypeSelection()
    local catalog = loadCatalog()
    local route = {
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }
    local template = loadRouteNpcsTemplate()
    local instance = template.prepare({
        name = "RouteNpcsUnderworld",
        route = route,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
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
                                        rowIndex = 3,
                                        routeOrdinal = 5,
                                        slotLabel = "Depth 5",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat04", label = "Combat 04" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                    {
                                        rowIndex = 4,
                                        routeOrdinal = 6,
                                        slotLabel = "Depth 6",
                                        roleKey = "Combat",
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                    {
                                        rowIndex = 5,
                                        routeOrdinal = 7,
                                        slotLabel = "Depth 7",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat05", label = "Combat 05" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = {},
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

    lu.assertEquals(control:biomeOptions(1).values, { "", "Disabled", "F" })
    lu.assertEquals(control:biomeOptions(1).displayValues[""], "Vanilla")
    lu.assertEquals(control:biomeOptions(1).displayValues.Disabled, "Disabled")
    lu.assertEquals(control:biomeOptions(1).displayValues.F, "Erebus")

    control:writeBiome(1, "Disabled")
    lu.assertEquals(fields.Targets:read(1, "BiomeKey"), "Disabled")
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), "")
    lu.assertEquals(fields.Targets:read(1, "VariantKey"), "")
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), "")
    lu.assertFalse(control:shouldRenderRoom(1))
    lu.assertFalse(control:shouldRenderVariant(1))

    local disabledRow = control:rowSnapshot(1)
    lu.assertTrue(disabledRow.valid)
    lu.assertTrue(disabledRow.disabled)
    lu.assertEquals(disabledRow.mode, "Disabled")
    lu.assertEquals(disabledRow.biomeKey, "")
    lu.assertEquals(disabledRow.targetKey, "")

    control:writeBiome(1, "F")
    lu.assertEquals(fields.Targets:read(1, "BiomeKey"), "F")
    lu.assertEquals(control:roomOptions(1).values, { "", "3" })
    lu.assertEquals(control:roomOptions(1).displayValues["3"], "Depth 5 - Combat 04")

    control:writeRoom(1, "3")
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), "3")
    lu.assertEquals(fields.Targets:read(1, "VariantKey"), "ArtemisCombatF")
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), "F:3:ArtemisCombatF")
    lu.assertEquals(control:selectedTargetKey(1), "F:3:ArtemisCombatF")
    lu.assertFalse(control:shouldRenderVariant(1))

    control:writeBiome(2, "F")
    control:writeRoom(2, "3")
    lu.assertEquals(control:variantOptions(2).values, { "Combat", "Random" })
    lu.assertTrue(control:shouldRenderVariant(2))
    lu.assertEquals(fields.Targets:read(2, "VariantKey"), "Combat")
    lu.assertEquals(control:rowValidation(2).code, "npc_room_occupied")

    control:writeVariant(2, "Random")
    lu.assertEquals(fields.Targets:read(2, "TargetKey"), "F:3:Random")
    lu.assertEquals(control:selectedTargetKey(2), "F:3:Random")
    lu.assertEquals(control:rowValidation(2).code, "npc_room_occupied")
    local npcSnapshot = control:buildSnapshot()
    lu.assertEquals(npcSnapshot.invalidRows[1].locationLabel, "Underworld Nemesis")

    control:writeBiome(2, "")
    lu.assertEquals(fields.Targets:read(2, "BiomeKey"), nil)
    lu.assertEquals(fields.Targets:read(2, "RowIndex"), nil)
    lu.assertEquals(fields.Targets:read(2, "VariantKey"), nil)
    lu.assertEquals(fields.Targets:read(2, "TargetKey"), nil)
    lu.assertTrue(control:rowValidation(2).valid)
end

function TestRunPlannerControls.testRouteFeaturesStorageDerivesSlotsFromDeclarations()
    local catalog = loadCatalog()
    local template = loadRouteFeaturesTemplate()
    local underworldChaos = template.prepare({
        name = "RouteFeatureChaosGateUnderworld",
        route = catalog.routes.lookup.Underworld,
        feature = catalog.features.byKey.ChaosGate,
        biomeLookup = catalog.lookup,
    })
    local underworldWell = template.prepare({
        name = "RouteFeatureStygianWellUnderworld",
        route = catalog.routes.lookup.Underworld,
        feature = catalog.features.byKey.StygianWell,
        biomeLookup = catalog.lookup,
    })

    lu.assertEquals(underworldChaos.slotCount, 10)
    lu.assertEquals(underworldChaos.slots[1].key, "ChaosGate1")
    lu.assertEquals(underworldChaos.slots[1].label, "Entry 1")
    lu.assertEquals(underworldChaos.slots[1].featureKey, "chaos")
    lu.assertEquals(underworldChaos.slots[1].plannedSpacingRooms, 10)

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

function TestRunPlannerControls.testRouteFeaturesUsesBiomeRoomSelectionAndPolicies()
    local catalog = loadCatalog()
    local route = {
        key = "Surface",
        label = "Surface",
        biomes = { "P" },
    }
    local template = loadRouteFeaturesTemplate()
    local instance = template.prepare({
        name = "RouteFeatureChaosGateSurface",
        route = route,
        feature = catalog.features.byKey.ChaosGate,
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
                                        features = { chaos = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 6,
                                        routeOrdinal = 5,
                                        slotLabel = "Depth 5",
                                        option = { key = "P_Combat01", label = "Combat 01" },
                                        features = { chaos = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 7,
                                        routeOrdinal = 6,
                                        slotLabel = "Depth 6",
                                        option = { key = "P_Combat02", label = "Combat 02" },
                                        features = { chaos = true },
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
    lu.assertEquals(control:roomOptions(1).values, { "", "6" })
    lu.assertEquals(control:roomOptions(1).displayValues["6"], "Depth 5 - Combat 01")

    control:writeRoom(1, "6")
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), "6")
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), "P:6")
    lu.assertEquals(control:selectedTargetKey(1), "P:6")
    lu.assertTrue(control:rowValidation(1).valid)

    control:writeTarget(1, "P:7")
    lu.assertEquals(control:rowValidation(1).code, "feature_target_unavailable")
    local featureSnapshot = control:buildSnapshot()
    lu.assertEquals(featureSnapshot.invalidRows[1].locationLabel, "Surface Chaos Gate Entry 1")

    control:writeBiome(1, "")
    lu.assertEquals(fields.Targets:read(1, "BiomeKey"), nil)
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), nil)
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), nil)
    lu.assertTrue(control:rowValidation(1).valid)
end

function TestRunPlannerControls.testRouteContextDisablesFeatureTargetsWhenFeaturesAreNotConfigured()
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
                                        option = { key = "P_Combat01", label = "Combat 01" },
                                        features = { chaos = true },
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

    lu.assertNil(targets.byFeature.chaos)
    lu.assertNil(targets.byFeatureBiome.chaos)
end

function TestRunPlannerControls.testRouteSnapshotsTreatRewardsAsVanillaWhenRewardsAreNotConfigured()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local fixedTemplate = loadFixedLinearTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local globalFields = routeUiFields(globalTemplate.storage(globalInstance))
    globalFields.ConfigureRewards:write(false)
    local globalControl = globalTemplate.createRuntime(globalFields, globalInstance)
    local fInstance = fixedTemplate.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fControl = fixedTemplate.createRuntime(routeFields({
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3LootKey = "ZeusUpgrade",
        },
    }), fInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteGlobalUnderworld" then
                return globalControl
            elseif controlName == "RouteF" then
                return fControl
            end
            return nil
        end,
    })
    fControl:setRouteContext(routeContext, "Underworld")

    local row = fControl:rowSnapshot(1)

    lu.assertNil(row.rewardKind)
    lu.assertNil(row.rewards)
    lu.assertNil(row.rewardLoot)
    lu.assertNil(row.rewardPicks)
    lu.assertEquals(primaryRewardItem(row).rewardKind, "vanilla")
    lu.assertEquals(primaryRewardItem(row).rewards, {})
    lu.assertEquals(primaryRewardItem(row).rewardLoot, {})
    lu.assertEquals(primaryRewardItem(row).rewardPicks, {})
end

function TestRunPlannerControls.testRouteFeaturesUsesShopDepthPolicy()
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
                                        option = { key = "O_Combat01", label = "Combat 01" },
                                        features = { surfaceShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 4,
                                        routeOrdinal = 3,
                                        slotLabel = "Depth 3",
                                        option = { key = "O_Combat02", label = "Combat 02" },
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
    lu.assertEquals(control:roomOptions(1).displayValues["4"], "Depth 3 - Combat 02")
end

function TestRunPlannerControls.testRouteFeaturesRejectsRepeatedTargetsInsideSpacingWindow()
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
                                        option = { key = "F_Combat01", label = "Combat 01" },
                                        features = { wellShop = true },
                                        valid = true,
                                        roomHistoryCost = 1,
                                    },
                                    {
                                        rowIndex = 5,
                                        routeOrdinal = 4,
                                        slotLabel = "Depth 4",
                                        option = { key = "F_Combat02", label = "Combat 02" },
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
end

function TestRunPlannerControls.testRouteFeaturesUsesTimelineBlockersForPostBossShops()
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
                                        option = { key = "G_Combat01", label = "Combat 01" },
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

function TestRunPlannerControls.testRouteFeaturesCanTargetEnabledSideRooms()
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
                                        option = { key = "N_Combat01", label = "Combat 01" },
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
                                        option = { key = "N_Combat02", label = "Combat 02" },
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
    lu.assertEquals(control:roomOptions(1).displayValues["4.side1"], "Pylon 1 - Combat 01 / Side 1 - N_Sub01")
    lu.assertEquals(control:roomOptions(1).displayValues["5.side1"], "Pylon 2 - Combat 02 / Side 1 - N_Sub03")

    control:writeRoom(1, "4.side1")
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), "4.side1")
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), "N:4.side1")
    lu.assertTrue(control:rowValidation(1).valid)

    local targets = routeContext:featureTargetsForSlot("Surface", "surfaceShop", "N")
    lu.assertEquals(targets.lookup["N:4.side1"].roomHistoryDepth, 4)
    lu.assertEquals(targets.lookup["N:4.side1"].roomHistoryOrdinal, 5)
end

function TestRunPlannerControls.testFixedLinearSnapshotsExportDerivedFeaturesOnlyForConcreteRooms()
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

function TestRunPlannerControls.testRouteContextSuppliesRouteGlobalGodSource()
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

function TestRunPlannerControls.testRouteTemplateViewsSupportNoOpUiTraversal()
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

function TestRunPlannerControls.testRouteTemplateViewAllocationsStayBounded()
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

function TestRunPlannerControls.testFixedLinearStorageMatchesRouteRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 13)
    lu.assertEquals(instance.routeSlots[1].routeOrdinal, 0)
    lu.assertEquals(instance.routeSlots[1].kind, "opening")
    lu.assertEquals(instance.routeSlots[1].label, "Opening")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Opening")
    lu.assertEquals(instance.routeSlots[2].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[10].routeOrdinal, 9)
    lu.assertEquals(instance.routeSlots[11].routeOrdinal, 10)
    lu.assertEquals(instance.routeSlots[11].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[11].biomeDepthCacheCost, 1)
    lu.assertEquals(instance.routeSlots[12].routeOrdinal, 11)
    lu.assertEquals(instance.routeSlots[12].biomeDepthCacheCost, 0)
    lu.assertEquals(instance.routeSlots[12].kind, "preboss")
    lu.assertEquals(instance.routeSlots[12].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[12].branchKey, "Shop")
    lu.assertEquals(instance.routeSlots[12].roomHistoryCost, 1)
    lu.assertEquals(instance.routeSlots[12].branchValues, {
        "Shop",
    })
    lu.assertEquals(instance.routeSlots[13].routeOrdinal, 11)
    lu.assertEquals(instance.routeSlots[13].biomeDepthCacheCost, 0)
    lu.assertEquals(instance.routeSlots[13].kind, "preboss")
    lu.assertEquals(instance.routeSlots[13].label, "Preboss Room")
    lu.assertEquals(instance.routeSlots[13].branchKey, "MajorReward")
    lu.assertEquals(instance.routeSlots[13].roomHistoryCost, 0)
    lu.assertEquals(instance.routeSlots[13].branchValues, {
        "MajorReward",
    })
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Story",
        "Fountain",
        "Midshop",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "F_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Fountain, { "F_Reprieve01" })
    lu.assertEquals(instance.optionValuesByRole.Midshop, { "F_Shop01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")

    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 13)
    lu.assertEquals(storage[1].defaultRows, 13)
    lu.assertEquals(storage[1].maxRows, 13)
    lu.assertEquals(storage[1].row[1].key, "RoleKey")
    lu.assertEquals(storage[1].row[1].default, "")
    lu.assertEquals(storage[1].row[2].key, "OptionKey")
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 13)
    lu.assertEquals(storage[2].defaultRows, 13)
    lu.assertEquals(storage[2].maxRows, 13)
    lu.assertEquals(storage[2].row[1].key, "Reward1Key")
    lu.assertEquals(storage[2].row[6].key, "Reward6Key")
    lu.assertEquals(storage[2].row[7].key, "Reward1LootKey")
    lu.assertEquals(storage[2].row[12].key, "Reward6LootKey")
end

function TestRunPlannerControls.testErebusSpecialRoomsUseSelectionDepthWindow()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})

    lu.assertEquals(instance.routeSlots[4].routeOrdinal, 3)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, rows, 4, "Story"), "F_Story01"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, rows, 4, "Story").F_Story01)

    lu.assertEquals(instance.routeSlots[5].routeOrdinal, 4)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, rows, 5, "Story"), "F_Story01"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, rows, 5, "Story").F_Story01)

    lu.assertEquals(instance.routeSlots[6].routeOrdinal, 5)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, rows, 6, "Story"), "F_Story01"))
    lu.assertNil(data.optionValueColorsForRow(instance, rows, 6, "Story").F_Story01)
end

function TestRunPlannerControls.testFixedLinearEntryMetadataRendersIntroRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local cases = {
        { key = "G", name = "RouteG", rowCount = 10, introRoom = "G_Intro", prebossRow = 9 },
        { key = "P", name = "RouteP", rowCount = 11, introRoom = "P_Intro", prebossRow = 10 },
        { key = "Q", name = "RouteQ", rowCount = 8, introRoom = "Q_Intro", prebossRow = 8 },
    }

    for _, case in ipairs(cases) do
        local instance = template.prepare({
            name = case.name,
            biome = catalog.lookup[case.key],
        })
        lu.assertEquals(instance.routeRowCount, case.rowCount)
        lu.assertEquals(instance.routeSlots[1].routeOrdinal, 0)
        lu.assertEquals(instance.routeSlots[1].kind, "intro")
        lu.assertEquals(instance.routeSlots[1].label, "Intro")
        lu.assertEquals(instance.routeSlots[1].roomKey, case.introRoom)
        lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
        lu.assertEquals(instance.routeSlots[case.prebossRow].kind, "preboss")
    end
end

function TestRunPlannerControls.testFixedLinearQShopSharedOfferGroupInvalidatesDuplicates()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {
            Reward1Key = "RandomLoot",
            Reward2Key = "RandomLoot",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertFalse(snapshot.rows[8].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[8]).rewardKind, "shop")
    lu.assertEquals(snapshot.rows[8].invalidCode, "duplicate_shop_group_option")
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 8)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_shop_group_option")
end

local function buildThessalyRuntime(rows)
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    return template.createRuntime(routeFields(rows), instance)
end

function TestRunPlannerControls.testThessalyRequiresStoryOrShopByDepthFive()
    local control = buildThessalyRuntime({
        {},
        { RoleKey = "Combat", OptionKey = "O_Combat01" },
        { RoleKey = "Combat", OptionKey = "O_Combat02" },
        { RoleKey = "Combat", OptionKey = "O_Combat03" },
        { RoleKey = "Combat", OptionKey = "O_Combat05" },
        { RoleKey = "Combat", OptionKey = "O_Combat06" },
    })
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertTrue(snapshot.rows[5].valid)
    lu.assertFalse(snapshot.rows[6].valid)
    lu.assertEquals(snapshot.rows[6].routeOrdinal, 5)
    lu.assertEquals(snapshot.rows[6].invalidCode, "thessaly_story_or_shop_deadline")
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 6)
    lu.assertEquals(snapshot.invalidRows[1].code, "thessaly_story_or_shop_deadline")
end

function TestRunPlannerControls.testThessalyDepthFiveStorySatisfiesDeadline()
    local control = buildThessalyRuntime({
        {},
        { RoleKey = "Combat", OptionKey = "O_Combat01" },
        { RoleKey = "Combat", OptionKey = "O_Combat02" },
        { RoleKey = "Combat", OptionKey = "O_Combat03" },
        { RoleKey = "Combat", OptionKey = "O_Combat05" },
        { RoleKey = "Story", OptionKey = "O_Story01" },
    })
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertTrue(snapshot.rows[6].valid)
end

function TestRunPlannerControls.testThessalyPriorShopSatisfiesDeadline()
    local control = buildThessalyRuntime({
        {},
        { RoleKey = "Combat", OptionKey = "O_Combat01" },
        { RoleKey = "Combat", OptionKey = "O_Combat02" },
        { RoleKey = "Combat", OptionKey = "O_Combat03", VariantKey = "ThreeCombats" },
        { RoleKey = "Midshop", OptionKey = "O_Shop01" },
        { RoleKey = "Combat", OptionKey = "O_Combat06" },
    })
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertTrue(snapshot.rows[5].valid)
    lu.assertTrue(snapshot.rows[6].valid)
end

function TestRunPlannerControls.testClockworkGoalStorageMatchesTartarusRouteRows()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 14)
    lu.assertEquals(instance.routeSlots[1].routeOrdinal, 0)
    lu.assertEquals(instance.routeSlots[1].kind, "intro")
    lu.assertEquals(instance.routeSlots[1].label, "Intro")
    lu.assertEquals(instance.routeSlots[1].roomKey, "I_Intro")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
    lu.assertEquals(instance.routeSlots[2].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[2].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[2].label, "Step 1")
    lu.assertEquals(instance.routeSlots[13].routeOrdinal, 12)
    lu.assertEquals(instance.routeSlots[13].label, "Step 12")
    lu.assertEquals(instance.routeSlots[14].kind, "preboss")
    lu.assertEquals(instance.routeSlots[14].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[14].roleKey, "Preboss")
    lu.assertEquals(instance.routeSlots[14].roomOptions[1].key, "I_PreBoss01")
    lu.assertEquals(instance.routeSlots[14].roomOptions[2].key, "I_PreBoss02")
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Goal",
        "ExtensionCombat",
        "Story",
        "Fountain",
        "Miniboss",
    })
    lu.assertEquals(instance.roleLabels.Goal, "Goal Room")
    lu.assertEquals(instance.optionValuesByRole.Goal[1], "")
    lu.assertEquals(instance.optionValuesByRole.Goal[2], "I_Combat01")
    lu.assertNil(instance.rolesByKey.Goal.mapOptions[1].reward)
    lu.assertEquals(instance.optionValuesByRole.ExtensionCombat[1], "")
    lu.assertEquals(instance.optionValuesByRole.Story, { "I_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Fountain, { "I_Reprieve01" })
    lu.assertEquals(instance.optionValuesByRole.Miniboss, {
        "I_MiniBoss01",
        "I_MiniBoss02",
    })

    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 14)
    lu.assertEquals(storage[1].defaultRows, 14)
    lu.assertEquals(storage[1].maxRows, 14)
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 14)
    lu.assertEquals(storage[2].defaultRows, 14)
    lu.assertEquals(storage[2].maxRows, 14)
end

function TestRunPlannerControls.testClockworkGoalForcesFirstRouteRowFromDeclaration()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local blankFirstStep = fakeRows({
        {},
        {},
    })
    local staleFirstStep = fakeRows({
        {},
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat01" },
    })

    lu.assertEquals(data.readRoleKey(instance, blankFirstStep, 2), "Goal")
    lu.assertEquals(data.readRoleKey(instance, staleFirstStep, 2), "Goal")
    lu.assertEquals(data.roleValuesForRow(instance, blankFirstStep, 2), {
        "Goal",
    })
    lu.assertEquals(data.optionValuesForRow(instance, blankFirstStep, 2, "ExtensionCombat"), {})
    lu.assertEquals(data.optionValuesForRow(instance, blankFirstStep, 2, "Goal")[2], "I_Combat01")
end

function TestRunPlannerControls.testClockworkGoalRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields({
            {},
            { RoleKey = "Goal", OptionKey = "I_Combat01" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03", Reward1Key = "MaxHealthDrop" },
            { RoleKey = "Goal", OptionKey = "I_Combat04" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat09" },
            { RoleKey = "Goal", OptionKey = "I_Combat10" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat11" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat12" },
            { RoleKey = "Goal", OptionKey = "I_Combat15" },
            { RoleKey = "Goal", OptionKey = "I_Combat18" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat21" },
            { RoleKey = "Story", OptionKey = "I_Story01" },
            {},
            {},
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "I")
    lu.assertEquals(snapshot.adapter, "clockworkGoal")
    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(snapshot.clockwork.goalCount, 5)
    lu.assertEquals(snapshot.clockwork.requiredGoalRewards, 5)
    lu.assertEquals(snapshot.clockwork.nonGoalRewardCount, 5)
    lu.assertEquals(snapshot.clockwork.maxNonGoalRewards, 6)
    lu.assertEquals(snapshot.clockwork.storyCount, 1)
    lu.assertEquals(#snapshot.rows, 14)

    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "I_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "none")
    lu.assertTrue(snapshot.rows[1].valid)

    lu.assertEquals(snapshot.rows[2].slotKind, "biomeRow")
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Goal")
    lu.assertEquals(snapshot.rows[2].optionKey, "I_Combat01")
    lu.assertEquals(snapshot.rows[2].roomKey, "I_Combat01")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardKind, "fixedReward")
    lu.assertTrue(snapshot.rows[2].countsGoalReward)
    lu.assertFalse(snapshot.rows[2].countsNonGoalReward)

    lu.assertEquals(snapshot.rows[3].roleKey, "ExtensionCombat")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "roomStore")
    lu.assertFalse(snapshot.rows[3].countsGoalReward)
    lu.assertTrue(snapshot.rows[3].countsNonGoalReward)
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[1].value, "MaxHealthDrop")

    lu.assertEquals(snapshot.rows[12].roleKey, "Story")
    lu.assertEquals(snapshot.rows[12].optionKey, "I_Story01")
    lu.assertEquals(snapshot.rows[12].roomKey, "I_Story01")
    lu.assertEquals(primaryRewardItem(snapshot.rows[12]).rewardKind, "none")
    lu.assertFalse(snapshot.rows[12].countsGoalReward)
    lu.assertFalse(snapshot.rows[12].countsNonGoalReward)
    lu.assertTrue(snapshot.rows[12].valid)

    lu.assertEquals(snapshot.rows[14].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[14].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[14].roleKey, "Preboss")
    lu.assertEquals(snapshot.rows[14].roomOptions[1].key, "I_PreBoss01")
    lu.assertEquals(snapshot.rows[14].roomOptions[2].key, "I_PreBoss02")
    lu.assertEquals(primaryRewardItem(snapshot.rows[14]).rewardKind, "shop")
    lu.assertTrue(snapshot.rows[14].valid)
end

function TestRunPlannerControls.testClockworkGoalCombatCanSelectDevotionRewardSurface()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        {
            RoleKey = "ExtensionCombat",
            OptionKey = "I_Combat03",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ApolloUpgrade",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[3].roleKey, "ExtensionCombat")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "roomStore")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[1].key, "rewardType")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[1].value, "Devotion")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[2].key, "lootAName")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[2].value, "ZeusUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[3].key, "lootBName")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[3].value, "ApolloUpgrade")
end

function TestRunPlannerControls.testClockworkGoalValidationModelsCountersAndSidePaths()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })

    local storyAfterOneExit = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat02" },
        { RoleKey = "Story", OptionKey = "I_Story01" },
    })
    local validation = data.validateRow(instance, storyAfterOneExit, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")
    lu.assertTrue(hasValue(data.roleValuesForRow(instance, storyAfterOneExit, 3), "Story"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, storyAfterOneExit, 3).Story)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, storyAfterOneExit, 3, "Story"), "I_Story01"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, storyAfterOneExit, 3, "Story").I_Story01)

    local extensionAfterOneExit = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat02" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03" },
    })
    validation = data.validateRow(instance, extensionAfterOneExit, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")

    local rolesAfterTwoExit = data.roleValuesForRow(instance, fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        {},
    }), 3)
    lu.assertTrue(hasValue(rolesAfterTwoExit, "ExtensionCombat"))
    lu.assertTrue(hasValue(rolesAfterTwoExit, "Story"))

    local seventhExtension = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat04" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat09" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat10" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat11" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat12" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat18" },
    })
    validation = data.validateRow(instance, seventhExtension, 9)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")

    local finalExtensionTwoExit = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat04" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat09" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat10" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat11" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat12" },
    })
    validation = data.validateRow(instance, finalExtensionTwoExit, 8)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "option_unavailable")
    local finalExtensionOptions = data.optionValuesForRow(instance, finalExtensionTwoExit, 8, "ExtensionCombat")
    lu.assertTrue(hasValue(finalExtensionOptions, "I_Combat12"))
    lu.assertTrue(hasValue(finalExtensionOptions, "I_Combat13"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, finalExtensionTwoExit, 8, "ExtensionCombat").I_Combat12)
    lu.assertNil(data.optionValueColorsForRow(instance, finalExtensionTwoExit, 8, "ExtensionCombat").I_Combat13)

    local finalExtensionOneExit = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat04" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat09" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat10" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat11" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat13" },
    })
    validation = data.validateRow(instance, finalExtensionOneExit, 8)
    lu.assertTrue(validation.valid)

    local sixthGoal = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Goal", OptionKey = "I_Combat10" },
        { RoleKey = "Goal", OptionKey = "I_Combat11" },
    })
    validation = data.validateRow(instance, sixthGoal, 7)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_goal_limit")
    lu.assertEquals(data.readRoleKey(instance, sixthGoal, 7), "Goal")
    local postGoalRoles = data.roleValuesForRow(instance, sixthGoal, 7)
    lu.assertTrue(hasValue(postGoalRoles, "Goal"))
    lu.assertTrue(hasValue(postGoalRoles, "Story"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, sixthGoal, 7).Goal)

    local missingGoal = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        {},
    })
    validation = data.validateRow(instance, missingGoal, 14)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_goal_count")
end

function TestRunPlannerControls.testClockworkGoalLateVanillaRowIsValidButCanInvalidatePreboss()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rows = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {},
    })

    lu.assertTrue(data.validateRow(instance, rows, 12).valid)
    lu.assertTrue(data.validateRow(instance, rows, 13).valid)

    local validation = data.validateRow(instance, rows, 14)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_goal_count")
end

function TestRunPlannerControls.testClockworkGoalAllowsPostGoalExtensionBehindTwoExitRoom()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local template = loadClockworkGoalTemplate()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rowData = {
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Goal", OptionKey = "I_Combat10" },
        { RoleKey = "Story", OptionKey = "I_Story01" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat12", Reward1Key = "MaxHealthDrop" },
        {},
        {},
        {},
        {},
        {},
        {},
        {},
    }
    local rows = fakeRows(rowData)

    lu.assertEquals(data.readRoleKey(instance, rows, 7), "Story")
    lu.assertFalse(data.isInactiveRouteRow(instance, rows, 7))
    lu.assertTrue(data.validateRow(instance, rows, 7).valid)
    local postGoalRoles = data.roleValuesForRow(instance, rows, 7)
    lu.assertTrue(hasValue(postGoalRoles, "Goal"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 7).Goal)
    lu.assertTrue(hasValue(postGoalRoles, "Story"))

    lu.assertEquals(data.readRoleKey(instance, rows, 8), "Vanilla")
    lu.assertEquals(data.roleValuesForRow(instance, rows, 8), { "Vanilla" })
    lu.assertTrue(data.validateRow(instance, rows, 8).valid)
    lu.assertTrue(data.isInactiveRouteRow(instance, rows, 8))
    lu.assertFalse(data.isInactiveRouteRow(instance, rows, 14))
    lu.assertEquals(data.countGoals(instance, rows), 5)
    lu.assertEquals(data.countNonGoals(instance, rows), 0)
    lu.assertEquals(data.countStories(instance, rows), 1)
    lu.assertTrue(data.validateRow(instance, rows, 14).valid)

    instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields(rowData), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.clockwork.goalCount, 5)
    lu.assertEquals(snapshot.clockwork.nonGoalRewardCount, 0)
    lu.assertEquals(snapshot.clockwork.storyCount, 1)
    lu.assertEquals(snapshot.rows[7].roleKey, "Story")
    lu.assertTrue(snapshot.rows[7].valid)
    lu.assertEquals(snapshot.rows[8].roleKey, "Vanilla")
    lu.assertTrue(snapshot.rows[14].valid)
end

function TestRunPlannerControls.testClockworkGoalTerminatesAfterOneExitFifthGoal()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rows = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Goal", OptionKey = "I_Combat02" },
        { RoleKey = "Story", OptionKey = "I_Story01" },
        {},
    })

    lu.assertEquals(data.readRoleKey(instance, rows, 7), "Vanilla")
    lu.assertEquals(data.roleValuesForRow(instance, rows, 7), { "Vanilla" })
    lu.assertTrue(data.validateRow(instance, rows, 7).valid)
    lu.assertTrue(data.isInactiveRouteRow(instance, rows, 7))
    lu.assertEquals(data.countGoals(instance, rows), 5)
    lu.assertEquals(data.countStories(instance, rows), 0)
    lu.assertTrue(data.validateRow(instance, rows, 14).valid)
end

function TestRunPlannerControls.testClockworkGoalRoomViewHidesInactiveRows()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local fields = routeUiFields(template.storage(instance))
    local rowData = {
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Goal", OptionKey = "I_Combat02" },
        { RoleKey = "Story", OptionKey = "I_Story01" },
    }
    for rowIndex, row in ipairs(rowData) do
        for alias, value in pairs(row) do
            fields.Rooms:get(rowIndex, alias):write(value)
        end
    end

    local control = template.createUi(fields, instance)
    local draw = noOpDraw()
    local rendered = {}
    draw.imgui.Text = function(text)
        rendered[tostring(text)] = true
    end

    template.views.rooms(draw, control, instance)

    lu.assertTrue(rendered.Intro)
    lu.assertTrue(rendered["Step 5"])
    lu.assertNil(rendered["Step 6"])
    lu.assertNil(rendered["Step 12"])
end

function TestRunPlannerControls.testHubPylonStorageMatchesEphyraRouteRows()
    local catalog = loadCatalog()
    local routeData = loadHubPylonData()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 10)
    lu.assertEquals(instance.routeSlots[1].kind, "fixedBeforeHub")
    lu.assertEquals(instance.routeSlots[1].label, "Opening")
    lu.assertEquals(instance.routeSlots[1].roomKey, "N_Opening01")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Opening")
    lu.assertEquals(instance.routeSlots[2].label, "Pre-Hub")
    lu.assertEquals(instance.routeSlots[3].label, "Hub")
    lu.assertEquals(instance.routeSlots[3].roomKey, "N_Hub")
    lu.assertEquals(instance.routeSlots[3].roomHistoryCost, 0)
    lu.assertEquals(instance.routeSlots[4].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[4].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[4].label, "Pylon 1")
    lu.assertEquals(instance.routeSlots[9].routeOrdinal, 6)
    lu.assertEquals(instance.routeSlots[9].label, "Pylon 6")
    lu.assertEquals(instance.routeSlots[10].kind, "fixedAfterHub")
    lu.assertEquals(instance.routeSlots[10].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[10].roomKey, "N_PreBoss01")
    lu.assertEquals(instance.routeSlots[10].roleKey, "Preboss")
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Story",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "N_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")
    lu.assertEquals(instance.optionValuesByRole.Miniboss, {
        "N_MiniBoss01",
        "N_MiniBoss02",
    })
    lu.assertEquals(instance.maxSideDoorCount, 3)
    lu.assertEquals(instance.sideRoomModeValues, {
        "",
        "Disabled",
        "Enabled",
    })
    lu.assertEquals(instance.sideRoomModeLabels, {
        [""] = "Vanilla",
        Disabled = "Disabled",
        Enabled = "Enabled",
    })

    lu.assertEquals(instance.sideRoomRowCount, 18)

    lu.assertEquals(#storage, 4)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 10)
    lu.assertEquals(storage[1].defaultRows, 10)
    lu.assertEquals(storage[1].maxRows, 10)
    lu.assertEquals(storage[1].row[1].key, "RoleKey")
    lu.assertEquals(storage[1].row[2].key, "OptionKey")
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].minRows, 10)
    lu.assertEquals(storage[2].row[1].key, "Reward1Key")
    lu.assertEquals(storage[2].row[12].key, "Reward6LootKey")
    lu.assertEquals(storage[3].key, "SideRooms")
    lu.assertEquals(storage[3].minRows, 18)
    lu.assertEquals(storage[3].defaultRows, 18)
    lu.assertEquals(storage[3].maxRows, 18)
    lu.assertEquals(storage[3].row[1].key, "ModeKey")
    lu.assertEquals(storage[3].row[1].default, "")
    lu.assertEquals(storage[4].key, "SideRewards")
    lu.assertEquals(storage[4].minRows, 18)
    lu.assertEquals(storage[4].row[1].key, "Reward1Key")
    lu.assertEquals(storage[4].row[12].key, "Reward6LootKey")
    lu.assertEquals(routeData.sideRoomRowIndex(instance, 4, 1), 1)
    lu.assertEquals(routeData.sideRoomRowIndex(instance, 4, 3), 3)
    lu.assertEquals(routeData.sideRoomRowIndex(instance, 9, 1), 16)
    lu.assertNil(routeData.sideRoomRowIndex(instance, 1, 1))
end

function TestRunPlannerControls.testMultiEncounterStorageMatchesThessalyRouteRows()
    local catalog = loadCatalog()
    local routeData = loadMultiEncounterData()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 8)
    lu.assertEquals(instance.routeSlots[1].routeOrdinal, 0)
    lu.assertEquals(instance.routeSlots[1].kind, "intro")
    lu.assertEquals(instance.routeSlots[1].label, "Intro")
    lu.assertEquals(instance.routeSlots[1].roomKey, "O_Intro")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
    lu.assertEquals(instance.routeSlots[2].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[2].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[2].label, "Depth 1")
    lu.assertEquals(instance.routeSlots[7].routeOrdinal, 6)
    lu.assertEquals(instance.routeSlots[8].routeOrdinal, 7)
    lu.assertEquals(instance.routeSlots[8].kind, "preboss")
    lu.assertEquals(instance.routeSlots[8].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[8].branchKey, "Shop")
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Story",
        "Fountain",
        "Midshop",
        "Devotion",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "O_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")

    lu.assertEquals(#storage, 3)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 8)
    lu.assertEquals(storage[1].defaultRows, 8)
    lu.assertEquals(storage[1].maxRows, 8)
    lu.assertEquals(storage[1].row[1].key, "RoleKey")
    lu.assertEquals(storage[1].row[2].key, "OptionKey")
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].minRows, 8)
    lu.assertEquals(storage[2].row[1].key, "Reward1Key")
    lu.assertEquals(storage[2].row[12].key, "Reward6LootKey")
    lu.assertEquals(storage[3].key, "EncounterRewards")
    lu.assertEquals(storage[3].minRows, 12)
    lu.assertEquals(storage[3].defaultRows, 12)
    lu.assertEquals(storage[3].maxRows, 12)
    lu.assertEquals(storage[3].row[1].key, "Reward1Key")
    lu.assertEquals(storage[3].row[12].key, "Reward6LootKey")
    lu.assertNil(routeData.encounterRewardRowIndex(instance, 1, 1))
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 2, 1), 1)
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 2, 2), 2)
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 7, 2), 12)
    lu.assertNil(routeData.encounterRewardRowIndex(instance, 8, 1))

    lu.assertEquals(routeData.variantLabelsForRow(instance, "Combat"), {
        [""] = "Vanilla",
        TwoCombats = "2 Combats",
        ThreeCombats = "3 Combats",
    })
    local rows = fakeRows({
        {},
        {
            RoleKey = "Combat",
            VariantKey = "TwoCombats",
        },
        {
            RoleKey = "Combat",
            VariantKey = "TwoCombats",
        },
        {
            RoleKey = "Combat",
            VariantKey = "TwoCombats",
        },
        {
            RoleKey = "Combat",
            VariantKey = "ThreeCombats",
        },
    })

    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 2, "Combat"), {
        "",
        "TwoCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 3, "Combat"), {
        "",
        "TwoCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 4, "Combat"), {
        "",
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 6, "Combat"), {
        "",
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 7, "Combat"), {
        "",
        "TwoCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 3, "Story"), {})
    lu.assertEquals(routeData.rowContext(instance, rows, 2).biomeEncounterDepth, 0)
    lu.assertEquals(routeData.rowContext(instance, rows, 3).biomeEncounterDepth, 1)
    lu.assertEquals(routeData.rowContext(instance, rows, 4).biomeEncounterDepth, 2)
    lu.assertEquals(routeData.rowContext(instance, rows, 5).biomeEncounterDepth, 3)
    lu.assertEquals(routeData.rowContext(instance, rows, 6).biomeEncounterDepth, 5)
end

function TestRunPlannerControls.testMultiEncounterSnapshotUsesSelectedOptionRoomKey()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(routeFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
            VariantKey = "TwoCombats",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[2].roomKey, "O_Combat01")
end

function TestRunPlannerControls.testFieldsCageStorageMatchesFieldsRouteRows()
    local catalog = loadCatalog()
    local routeData = loadFieldsCageData()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 6)
    lu.assertEquals(instance.routeSlots[1].kind, "fixedBeforeRoute")
    lu.assertEquals(instance.routeSlots[1].label, "Intro")
    lu.assertEquals(instance.routeSlots[1].roomKey, "H_Intro")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
    lu.assertEquals(instance.routeSlots[2].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[2].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[2].label, "Pick 1")
    lu.assertEquals(instance.routeSlots[5].routeOrdinal, 4)
    lu.assertEquals(instance.routeSlots[5].label, "Pick 4")
    lu.assertEquals(instance.routeSlots[6].kind, "fixedAfterRoute")
    lu.assertEquals(instance.routeSlots[6].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[6].roomKey, "H_PreBoss01")
    lu.assertEquals(instance.routeSlots[6].roleKey, "Preboss")
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Miniboss",
        "Bridge",
    })
    lu.assertEquals(instance.roleLabels.Bridge, "Echo")
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")
    lu.assertEquals(instance.optionValuesByRole.Bridge, {
        "H_Bridge01",
    })
    lu.assertEquals(instance.maxCageRewardCount, 3)
    lu.assertEquals(instance.cageRewardRowCount, 12)

    lu.assertEquals(#storage, 3)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].minRows, 6)
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].minRows, 6)
    lu.assertEquals(storage[3].key, "CageRewards")
    lu.assertEquals(storage[3].minRows, 12)
    lu.assertEquals(storage[3].defaultRows, 12)
    lu.assertEquals(storage[3].maxRows, 12)
    lu.assertEquals(storage[3].row[1].key, "Reward1Key")
    lu.assertEquals(storage[3].row[12].key, "Reward6LootKey")
    lu.assertEquals(routeData.cageRewardRowIndex(instance, 2, 1), 1)
    lu.assertEquals(routeData.cageRewardRowIndex(instance, 2, 3), 3)
    lu.assertEquals(routeData.cageRewardRowIndex(instance, 5, 1), 10)
    lu.assertEquals(routeData.cageRewardRowIndex(instance, 5, 3), 12)
    lu.assertNil(routeData.cageRewardRowIndex(instance, 1, 1))
    lu.assertNil(routeData.cageRewardRowIndex(instance, 6, 1))

    lu.assertEquals(routeData.cageCountLabelsForRole(instance, "Combat"), {
        [""] = "Vanilla",
        TwoRewards = "2 Rewards",
        ThreeRewards = "3 Rewards",
    })
    lu.assertEquals(routeData.cageCountValuesForRow(instance, fakeRows({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat09",
        },
    }), 2, "Combat"), {
        "",
        "TwoRewards",
    })
    lu.assertEquals(routeData.cageCountValuesForRow(instance, fakeRows({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
        },
    }), 2, "Combat"), {
        "",
        "TwoRewards",
        "ThreeRewards",
    })
end

function TestRunPlannerControls.testFixedLinearOpeningRowUsesFixedRoomChoice()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            OptionKey = "F_Opening02",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
    })
    local values = {}

    data.fillRoleValues(instance, rows, 1, values)
    lu.assertEquals(values, {
        "Opening",
    })

    data.fillOptionValues(instance, rows, 1, "Opening", values)
    lu.assertEquals(values, {
        "",
        "F_Opening01",
        "F_Opening02",
        "F_Opening03",
    })

    local roleKey, role = data.resolveRole(instance, rows, 1)
    local optionKey, option = data.resolveOption(instance, rows, 1, roleKey)
    lu.assertEquals(roleKey, "Opening")
    lu.assertEquals(role.label, "Opening")
    lu.assertEquals(optionKey, "F_Opening02")
    lu.assertEquals(option.label, "Opening 2")
    lu.assertTrue(data.validateRow(instance, rows, 1).valid)
end

function TestRunPlannerControls.testHubPylonFixedRowsUseImplicitRooms()
    local catalog = loadCatalog()
    local data = loadHubPylonData()
    local instance = data.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 1, values)
    lu.assertEquals(values, {
        "Opening",
    })

    data.fillOptionValues(instance, rows, 1, "Opening", values)
    lu.assertEquals(values, {})

    local roleKey, role = data.resolveRole(instance, rows, 1)
    local optionKey, option = data.resolveOption(instance, rows, 1, roleKey)
    lu.assertEquals(roleKey, "Opening")
    lu.assertEquals(role.label, "Opening")
    lu.assertEquals(role.roomKey, "N_Opening01")
    lu.assertEquals(optionKey, "")
    lu.assertNil(option)
    lu.assertTrue(data.validateRow(instance, rows, 1).valid)
end

function TestRunPlannerControls.testHubPylonRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(routeFields({
            {},
            {},
            {},
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat12",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Story",
                OptionKey = "",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "N_MiniBoss02",
                Reward1Key = "AphroditeUpgrade",
            },
            {
                RoleKey = "Story",
                OptionKey = "N_Story01",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {},
        }, {
            { ModeKey = "Enabled" },
            { ModeKey = "Disabled" },
            {},
        }, {
            { Reward1Key = "MaxHealthDrop" },
            {},
            {},
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "N")
    lu.assertEquals(snapshot.adapter, "hubPylon")
    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 7)
    lu.assertEquals(snapshot.invalidRows[1].code, "role_limit")

    lu.assertEquals(snapshot.rows[1].slotKind, "fixedBeforeHub")
    lu.assertEquals(snapshot.rows[1].slotLabel, "Opening")
    lu.assertEquals(snapshot.rows[1].roomKey, "N_Opening01")
    lu.assertEquals(snapshot.rows[1].roleKey, "Opening")
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[3].slotLabel, "Hub")
    lu.assertEquals(snapshot.rows[3].roomHistoryCost, 0)

    lu.assertEquals(snapshot.rows[4].slotKind, "biomeRow")
    lu.assertEquals(snapshot.rows[4].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[4].optionKey, "N_Combat12")
    lu.assertEquals(snapshot.rows[4].roomKey, "N_Combat12")
    lu.assertEquals(snapshot.rows[4].roomHistoryCost, 2)
    lu.assertEquals(snapshot.rows[4].hubDoorId, 561389)
    lu.assertEquals(#snapshot.rows[4].sideDoors, 3)
    lu.assertEquals(#snapshot.rows[4].sideRooms, 3)
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardKind, "roomStore")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardPicks[1].value, "Boon")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardPicks[2].value, "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].roomKey, "N_Sub09")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].doorId, 558352)
    lu.assertEquals(snapshot.rows[4].sideRooms[1].modeKey, "Enabled")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].storedModeKey, "Enabled")
    lu.assertTrue(snapshot.rows[4].sideRooms[1].enabled)
    lu.assertEquals(snapshot.rows[4].sideRooms[1].rewardStore, "SubRoomRewardsHard")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 1).rewardKind, "roomStore")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 1).rewardPicks[1], {
        key = "rewardType",
        kind = "rewardType",
        alias = "Reward1Key",
        storageAlias = "Reward1Key",
        value = "MaxHealthDrop",
    })
    lu.assertEquals(snapshot.rows[4].sideRooms[2].roomKey, "N_Sub10")
    lu.assertEquals(snapshot.rows[4].sideRooms[2].modeKey, "Disabled")
    lu.assertEquals(snapshot.rows[4].sideRooms[2].storedModeKey, "Disabled")
    lu.assertFalse(snapshot.rows[4].sideRooms[2].enabled)
    lu.assertEquals(snapshot.rows[4].sideRooms[2].rewardStore, "SubRoomRewardsHard")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 2).rewardKind, "none")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 2).rewardPicks, {})
    lu.assertEquals(snapshot.rows[4].sideRooms[3].roomKey, "N_Sub07")
    lu.assertEquals(snapshot.rows[4].sideRooms[3].modeKey, "Vanilla")
    lu.assertEquals(snapshot.rows[4].sideRooms[3].storedModeKey, "")
    lu.assertFalse(snapshot.rows[4].sideRooms[3].enabled)
    lu.assertEquals(snapshot.rows[4].sideRooms[3].rewardStore, "SubRoomRewards")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 3).rewardPicks, {})

    lu.assertEquals(snapshot.rows[5].roleKey, "Story")
    lu.assertEquals(snapshot.rows[5].optionKey, "N_Story01")
    lu.assertEquals(snapshot.rows[5].roomKey, "N_Story01")
    lu.assertEquals(snapshot.rows[5].hubDoorId, 560848)
    lu.assertTrue(snapshot.rows[5].valid)

    lu.assertEquals(snapshot.rows[6].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[6].optionKey, "N_MiniBoss02")
    lu.assertEquals(snapshot.rows[6].roomKey, "N_MiniBoss02")
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardKind, "boonSource")
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardPicks[1].value, "AphroditeUpgrade")
    lu.assertTrue(snapshot.rows[6].valid)

    lu.assertEquals(snapshot.rows[7].roleKey, "Story")
    lu.assertFalse(snapshot.rows[7].valid)
    lu.assertEquals(snapshot.rows[7].invalidCode, "role_limit")

    lu.assertEquals(snapshot.rows[10].slotKind, "fixedAfterHub")
    lu.assertEquals(snapshot.rows[10].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[10].roomKey, "N_PreBoss01")
    lu.assertEquals(snapshot.rows[10].roleKey, "Preboss")
    lu.assertEquals(snapshot.rows[10].roomHistoryCost, 1)
    lu.assertTrue(snapshot.rows[10].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[10]).rewardKind, "shop")
end

function TestRunPlannerControls.testHubPylonPolicyAllowsDuplicateBoonSources()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(routeFields({
            {},
            {},
            {},
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat12",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat13",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 0)
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardPicks[2].value, "ZeusUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[2].value, "ZeusUpgrade")
end

function TestRunPlannerControls.testHubPylonPolicyRejectsDuplicateNonBoonRewards()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local rowData = {
            {},
            {},
            {},
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat12",
                Reward1Key = "MaxHealthDropBig",
            },
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat13",
                Reward1Key = "MaxHealthDropBig",
            },
        }
    local control = template.createRuntime(routeFields(rowData), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_reward_type")
    lu.assertEquals(snapshot.rows[5].invalidCode, "duplicate_reward_type")

end

function TestRunPlannerControls.testFixedLinearPrebossRowsUseBranchChoices()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 12, values)
    lu.assertEquals(values, {
        "Shop",
    })

    data.fillOptionValues(instance, rows, 12, "Shop", values)
    lu.assertEquals(values, {})

    local roleKey, branch = data.resolveRole(instance, rows, 12)
    lu.assertEquals(roleKey, "Shop")
    lu.assertEquals(branch.label, "Preboss Shop")
    lu.assertTrue(data.validateRow(instance, rows, 12).valid)

    data.fillRoleValues(instance, rows, 13, values)
    lu.assertEquals(values, {
        "MajorReward",
    })

    roleKey, branch = data.resolveRole(instance, rows, 13)
    lu.assertEquals(roleKey, "MajorReward")
    lu.assertEquals(branch.label, "Preboss Room")
    lu.assertTrue(data.validateRow(instance, rows, 13).valid)
end

function TestRunPlannerControls.testFixedLinearRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Combat",
                OptionKey = "Q_Combat03",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "Q_MiniBoss02",
                VariantKey = "Manual",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Missing",
                OptionKey = "Q_MiniBoss03",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "Q")
    lu.assertEquals(snapshot.adapter, "scriptedFixedLinear")
    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "unknown_role")
    lu.assertEquals(snapshot.invalidRows[1].locationLabel, "Summit Depth 4")
    lu.assertEquals(snapshot.rows[1].routeOrdinal, 0)
    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "Q_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Vanilla")
    lu.assertTrue(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[3].routeOrdinal, 2)
    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertTrue(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[4].routeOrdinal, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[4].role.key, "Miniboss")
    lu.assertEquals(snapshot.rows[4].optionKey, "Q_MiniBoss02")
    lu.assertEquals(snapshot.rows[4].option.label, "Brute")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].variantKey, "Manual")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewards[1], "Boon")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewards[2], "ZeusUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardKind, "roomStore")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardPicks, {
        {
            key = "rewardType",
            kind = "rewardType",
            alias = "Reward1Key",
            value = "Boon",
        },
        {
            key = "boonSource",
            kind = "boonSource",
            alias = "Reward2Key",
            value = "ZeusUpgrade",
        },
    })
    lu.assertEquals(snapshot.rows[4].rewardItems[1].address, "row")
    lu.assertEquals(snapshot.rows[4].rewardItems[1].sourceKind, "row")
    lu.assertEquals(snapshot.rows[4].rewardItems[1].rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[4].rewardItems[1].rewards[1], "Boon")
    lu.assertEquals(snapshot.rows[4].rewardItems[1].rewardPicks[2].value, "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[5].roleKey, "Missing")
    lu.assertEquals(snapshot.rows[5].invalidCode, "unknown_role")
    lu.assertFalse(snapshot.rows[5].valid)
    lu.assertEquals(snapshot.rows[5].optionKey, "Q_MiniBoss03")
    lu.assertNil(snapshot.rows[5].option)
end

function TestRunPlannerControls.testMultiEncounterRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat01",
                VariantKey = "",
            },
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat02",
                VariantKey = "TwoCombats",
            },
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat03",
                VariantKey = "ThreeCombats",
            },
            {
                RoleKey = "Fountain",
                OptionKey = "O_Reprieve01",
                Reward1Key = "Minor",
                Reward4Key = "GiftDrop",
            },
            {
                RoleKey = "Story",
                OptionKey = "O_Story01",
            },
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat05",
                VariantKey = "TwoCombats",
            },
            {},
        }, nil, nil, {
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
            },
            {},
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "ZeusUpgrade",
            },
            {
                Reward1Key = "Minor",
                Reward4Key = "GiftDrop",
            },
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "ZeusUpgrade",
            },
            {
                Reward1Key = "Minor",
                Reward4Key = "GiftDrop",
            },
            {},
            {},
            {},
            {},
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "HestiaUpgrade",
            },
            {},
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "O")
    lu.assertEquals(snapshot.adapter, "multiEncounterFixed")
    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.rows, 8)

    lu.assertEquals(snapshot.rows[1].routeOrdinal, 0)
    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "O_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "none")
    lu.assertTrue(snapshot.rows[1].valid)

    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "O_Combat01")
    lu.assertEquals(snapshot.rows[2].variantKey, "")
    lu.assertEquals(snapshot.rows[2].variant.sourceKey, "Vanilla")
    lu.assertNil(snapshot.rows[2].realCombatCount)
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardKind, "none")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardPicks, {})
    lu.assertEquals(snapshot.rows[2].encounterRewardLegs, {})

    lu.assertEquals(snapshot.rows[3].routeOrdinal, 2)
    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[3].optionKey, "O_Combat02")
    lu.assertEquals(snapshot.rows[3].variantKey, "TwoCombats")
    lu.assertEquals(snapshot.rows[3].variant.sourceKey, "TwoCombats")
    lu.assertEquals(snapshot.rows[3].variant.label, "2 Combats")
    lu.assertEquals(snapshot.rows[3].realCombatCount, 2)
    lu.assertEquals(snapshot.rows[3].encounterPolicyKey, "O_CombatData")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "none")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks, {})
    lu.assertEquals(#snapshot.rows[3].encounterRewardLegs, 1)
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].key, "Combat1")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].label, "First Combat")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "encounter", 1).rewardKind, "majorMinor")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "encounter", 1).rewardPicks[1].value, "Major")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "encounter", 1).rewardPicks[2].value, "Boon")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "encounter", 1).rewardPicks[3].value, "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[4].routeOrdinal, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[4].optionKey, "O_Combat03")
    lu.assertEquals(snapshot.rows[4].variantKey, "ThreeCombats")
    lu.assertEquals(snapshot.rows[4].variant.sourceKey, "ThreeCombats")
    lu.assertEquals(snapshot.rows[4].variant.label, "3 Combats")
    lu.assertEquals(snapshot.rows[4].realCombatCount, 3)
    lu.assertEquals(#snapshot.rows[4].encounterRewardLegs, 2)
    lu.assertEquals(snapshot.rows[4].encounterRewardLegs[1].key, "Combat1")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "encounter", 1).rewardPicks[3].value, "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[4].encounterRewardLegs[2].key, "Combat2")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "encounter", 2).rewardPicks[1].value, "Minor")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "encounter", 2).rewardPicks[2].value, "GiftDrop")

    lu.assertEquals(snapshot.rows[5].roleKey, "Fountain")
    lu.assertEquals(snapshot.rows[5].variantKey, "")
    lu.assertNil(snapshot.rows[5].variant)
    lu.assertNil(snapshot.rows[5].encounterPolicyKey)
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardKind, "majorMinor")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[1].value, "Minor")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[2].value, "GiftDrop")

    lu.assertEquals(snapshot.rows[6].roleKey, "Story")
    lu.assertEquals(snapshot.rows[6].optionKey, "O_Story01")
    lu.assertEquals(snapshot.rows[6].variantKey, "")
    lu.assertNil(snapshot.rows[6].variant)
    lu.assertNil(snapshot.rows[6].realCombatCount)
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardKind, "none")
    lu.assertEquals(snapshot.rows[6].encounterRewardLegs, {})

    lu.assertEquals(snapshot.rows[7].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[7].variantKey, "TwoCombats")
    lu.assertEquals(snapshot.rows[7].realCombatCount, 2)
    lu.assertEquals(primaryRewardItem(snapshot.rows[7]).rewardKind, "none")
    lu.assertEquals(#snapshot.rows[7].encounterRewardLegs, 1)
    lu.assertEquals(snapshot.rows[7].encounterRewardLegs[1].key, "Combat1")
    lu.assertEquals(rewardItemBySource(snapshot.rows[7], "encounter", 1).rewardPicks[3].value, "HestiaUpgrade")

    lu.assertEquals(snapshot.rows[8].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[8].roomKey, "O_PreBoss01")
    lu.assertEquals(snapshot.rows[8].branchKey, "Shop")
    lu.assertEquals(snapshot.rows[8].roleKey, "Shop")
    lu.assertEquals(snapshot.rows[8].role.label, "Preboss Shop")
    lu.assertEquals(primaryRewardItem(snapshot.rows[8]).rewardKind, "shop")
end

function TestRunPlannerControls.testMultiEncounterRuntimeInvalidatesUnavailableCombatCount()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat01",
                VariantKey = "ThreeCombats",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "variant_unavailable")
    lu.assertEquals(snapshot.rows[2].invalidCode, "variant_unavailable")
end

function TestRunPlannerControls.testFieldsCageRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat04",
                VariantKey = "ThreeRewards",
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat09",
                VariantKey = "TwoRewards",
            },
            {
                RoleKey = "Bridge",
                OptionKey = "",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                Reward1Key = "ZeusUpgrade",
            },
            {},
        }, nil, nil, nil, {
            {
                Reward1Key = "Boon",
                Reward2Key = "PoseidonUpgrade",
            },
            {
                Reward1Key = "HermesUpgrade",
            },
            {
                Reward1Key = "StackUpgrade",
            },
            {
                Reward1Key = "Boon",
                Reward2Key = "HestiaUpgrade",
            },
            {
                Reward1Key = "WeaponUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "H")
    lu.assertEquals(snapshot.adapter, "fieldsCageRoute")
    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.rows, 6)

    lu.assertEquals(snapshot.rows[1].slotKind, "fixedBeforeRoute")
    lu.assertEquals(snapshot.rows[1].slotLabel, "Intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "H_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "none")

    lu.assertEquals(snapshot.rows[2].slotKind, "biomeRow")
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].roomKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].variantKey, "ThreeRewards")
    lu.assertEquals(snapshot.rows[2].cagePolicyKey, "H_FieldsCageRewards")
    lu.assertEquals(snapshot.rows[2].cageRewardCount, 3)
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardKind, "none")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardPicks, {})
    lu.assertEquals(#snapshot.rows[2].cageRewards, 3)
    lu.assertEquals(snapshot.rows[2].cageRewards[1].key, "Cage1")
    lu.assertEquals(snapshot.rows[2].cageRewards[1].label, "Cage 1")
    lu.assertEquals(rewardItemBySource(snapshot.rows[2], "cage", 1).rewardKind, "roomStore")
    lu.assertEquals(rewardItemBySource(snapshot.rows[2], "cage", 1).rewardPicks[1].value, "Boon")
    lu.assertEquals(rewardItemBySource(snapshot.rows[2], "cage", 1).rewardPicks[2].value, "PoseidonUpgrade")
    lu.assertEquals(rewardItemBySource(snapshot.rows[2], "cage", 1).rewardPicks[2].storageAlias, "Reward2Key")
    lu.assertEquals(rewardItemBySource(snapshot.rows[2], "cage", 2).rewardPicks[1].value, "HermesUpgrade")
    lu.assertEquals(rewardItemBySource(snapshot.rows[2], "cage", 3).rewardPicks[1].value, "StackUpgrade")

    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[3].optionKey, "H_Combat09")
    lu.assertEquals(snapshot.rows[3].cageRewardCount, 2)
    lu.assertEquals(#snapshot.rows[3].cageRewards, 2)
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "cage", 1).rewardPicks[2].value, "HestiaUpgrade")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "cage", 2).rewardPicks[1].value, "WeaponUpgrade")

    lu.assertEquals(snapshot.rows[4].roleKey, "Bridge")
    lu.assertEquals(snapshot.rows[4].role.label, "Echo")
    lu.assertEquals(snapshot.rows[4].optionKey, "H_Bridge01")
    lu.assertEquals(snapshot.rows[4].roomKey, "H_Bridge01")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardKind, "none")

    lu.assertEquals(snapshot.rows[5].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[5].optionKey, "H_MiniBoss01")
    lu.assertEquals(snapshot.rows[5].roomKey, "H_MiniBoss01")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardKind, "boonSource")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[1].value, "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[6].slotKind, "fixedAfterRoute")
    lu.assertEquals(snapshot.rows[6].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[6].roomKey, "H_PreBoss01")
    lu.assertEquals(snapshot.rows[6].roleKey, "Preboss")
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardKind, "shop")
end

function TestRunPlannerControls.testFieldsCageRuntimeInvalidatesCageCountAboveMapCapacity()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat09",
                VariantKey = "ThreeRewards",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "cage_count_exceeds_map")
    lu.assertEquals(snapshot.rows[2].invalidCode, "cage_count_exceeds_map")
end

function TestRunPlannerControls.testFieldsCageRuntimeInvalidatesForcedCageRewardsWithoutMap()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "",
                VariantKey = "TwoRewards",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "cage_count_requires_map")
    lu.assertEquals(snapshot.rows[2].invalidCode, "cage_count_requires_map")
end

function TestRunPlannerControls.testFieldsCagePolicyRejectsDuplicateBoonSourcesInSameCageSet()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat04",
                VariantKey = "ThreeRewards",
            },
        }, nil, nil, nil, {
            {
                Reward1Key = "Boon",
                Reward2Key = "PoseidonUpgrade",
            },
            {
                Reward1Key = "Boon",
                Reward2Key = "PoseidonUpgrade",
            },
            {
                Reward1Key = "HermesUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_boon_source")
    lu.assertEquals(snapshot.rows[2].invalidCode, "duplicate_boon_source")
end

function TestRunPlannerControls.testFieldsCageRuntimePolicyRejectsDuplicateNonBoonRewards()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local fields = routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat04",
                VariantKey = "TwoRewards",
            },
        }, nil, nil, nil, {
            {
                Reward1Key = "MaxHealthDrop",
            },
            {
                Reward1Key = "MaxHealthDrop",
            },
        })
    local runtimeControl = template.createRuntime(fields, instance)

    local row = runtimeControl:rowSnapshot(2)
    lu.assertTrue(row.valid)

    local snapshot = runtimeControl:buildSnapshot()
    lu.assertFalse(snapshot.valid)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_reward_type")
    lu.assertEquals(snapshot.rows[2].invalidCode, "duplicate_reward_type")
end

function TestRunPlannerControls.testFieldsCageAvailabilityColorsEchoBeforeThirdPick()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 2).Miniboss)
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 2).Bridge)

    data.fillRoleValues(instance, rows, 3, values)
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 3).Miniboss)
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 3).Bridge)

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 4).Bridge)
end

function TestRunPlannerControls.testFixedLinearRuntimeSnapshotsPrebossBranchRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
            {},
            { RoleKey = "" },
            { RoleKey = "" },
            { RoleKey = "Miniboss", OptionKey = "Q_MiniBoss02" },
            { RoleKey = "" },
            { RoleKey = "" },
            { RoleKey = "Miniboss", OptionKey = "Q_MiniBoss03" },
            { RoleKey = "" },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.rows, 8)
    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "Q_Intro")
    lu.assertEquals(snapshot.rows[8].routeOrdinal, 7)
    lu.assertEquals(snapshot.rows[8].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[8].roomKey, "Q_PreBoss01")
    lu.assertEquals(snapshot.rows[8].branchKey, "Shop")
    lu.assertEquals(snapshot.rows[8].roleKey, "Shop")
    lu.assertEquals(snapshot.rows[8].role.label, "Preboss Shop")
    lu.assertTrue(snapshot.rows[8].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[8]).rewardKind, "shop")
    lu.assertEquals(#primaryRewardItem(snapshot.rows[8]).rewardPicks, 0)
end

function TestRunPlannerControls.testSingleRoomRolesDefaultToConcreteOption()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Story",
                OptionKey = "",
            },
        }), instance)
    local row = control:rowSnapshot(6)

    lu.assertEquals(row.roleKey, "Story")
    lu.assertEquals(row.optionKey, "F_Story01")
    lu.assertEquals(row.option.label, "Arachne")
end

function TestRunPlannerControls.testCombatRewardSurfaceHidesDevotionByDefault()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            {
	                RoleKey = "",
	            },
	            {
	                RoleKey = "Combat",
	                OptionKey = "F_Combat01",
	            },
	        }), instance)
	    local surface = control:rewardSurface(2)

    lu.assertEquals(surface.kind, "majorMinor")
    lu.assertEquals(surface.controls[1].values, { "", "Major", "Minor" })
    lu.assertFalse(hasValue(surface.controls[2].values, "Devotion"))
    lu.assertTrue(hasValue(surface.controls[2].values, "RoomMoneyDrop"))
    lu.assertTrue(hasValue(surface.controls[4].values, "GiftDrop"))
end

function TestRunPlannerControls.testFixedLinearAvailabilityColorsRolesByRouteRow()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Story"))
    lu.assertTrue(hasValue(values, "Fountain"))
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 2).Story)
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 2).Fountain)
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 2).Midshop)
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 2).Miniboss)

    rows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    })
    data.fillRoleValues(instance, rows, 6, values)
    lu.assertTrue(hasValue(values, "Story"))
    lu.assertTrue(hasValue(values, "Fountain"))
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 6).Story)
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 6).Fountain)
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 6).Midshop)
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 6).Miniboss)
end

function TestRunPlannerControls.testFixedLinearAvailabilityColorsOptionsByRouteRow()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, ""))
    lu.assertTrue(hasValue(values, "F_Combat01"))
    lu.assertTrue(hasValue(values, "F_Combat05"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, rows, 2, "Combat").F_Combat05)

    rows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        { RoleKey = "Combat", OptionKey = "F_Combat04" },
    })
    data.fillOptionValues(instance, rows, 6, "Combat", values)
    lu.assertTrue(hasValue(values, "F_Combat05"))
    lu.assertTrue(hasValue(values, "F_Combat09"))
    lu.assertNil(data.optionValueColorsForRow(instance, rows, 6, "Combat").F_Combat05)
    lu.assertNotNil(data.optionValueColorsForRow(instance, rows, 6, "Combat").F_Combat09)
end

function TestRunPlannerControls.testFixedLinearAvailabilityColorsScriptedExactDepthOptions()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat10"))
    lu.assertTrue(hasValue(values, "Q_Combat11"))
    lu.assertTrue(hasValue(values, "Q_Combat03"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, rows, 2, "Combat").Q_Combat03)

    data.fillOptionValues(instance, rows, 3, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat03"))
    lu.assertTrue(hasValue(values, "Q_Combat05"))
    lu.assertTrue(hasValue(values, "Q_Combat15"))
    lu.assertTrue(hasValue(values, "Q_Combat10"))
    lu.assertNil(data.optionValueColorsForRow(instance, rows, 3, "Combat").Q_Combat03)
    lu.assertNotNil(data.optionValueColorsForRow(instance, rows, 3, "Combat").Q_Combat10)

    data.fillOptionValues(instance, rows, 4, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss05"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, rows, 4, "Miniboss").Q_MiniBoss03)

    data.fillOptionValues(instance, rows, 7, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss04"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertNil(data.optionValueColorsForRow(instance, rows, 7, "Miniboss").Q_MiniBoss03)
    lu.assertNotNil(data.optionValueColorsForRow(instance, rows, 7, "Miniboss").Q_MiniBoss02)
end

function TestRunPlannerControls.testFixedLinearAvailabilityColorsForcedDepthRoles()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 2).Miniboss)

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 4).Combat)
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 4).Miniboss)

    data.fillRoleValues(instance, rows, 7, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 7).Combat)
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 7).Miniboss)
end

function TestRunPlannerControls.testFixedLinearForcedDepthUsesBiomeDepthCache()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local biome = {}
    for key, value in pairs(catalog.lookup.Q) do
        biome[key] = value
    end
    biome.slotLayout = {}
    for key, value in pairs(catalog.lookup.Q.slotLayout) do
        biome.slotLayout[key] = value
    end
    biome.slotLayout.biomeDepthCacheStart = 0

    local instance = data.prepare({
        name = "RouteQ",
        biome = biome,
    })
    local rows = fakeRows({})
    local values = {}

    lu.assertEquals(data.rowContext(instance, rows, 4).routeOrdinal, 3)
    lu.assertEquals(data.rowContext(instance, rows, 4).biomeDepthCache, 2)
    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 4).Miniboss)

    lu.assertEquals(data.rowContext(instance, rows, 5).routeOrdinal, 4)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeDepthCache, 3)
    data.fillRoleValues(instance, rows, 5, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 5).Combat)
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 5).Miniboss)
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesForcedDepthRoles()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
            {
                RoleKey = "",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Combat",
                OptionKey = "Q_Combat01",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 4)
    lu.assertEquals(snapshot.invalidRows[1].code, "forced_depth_role")
    lu.assertEquals(snapshot.rows[4].routeOrdinal, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertFalse(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].invalidCode, "forced_depth_role")
end

function TestRunPlannerControls.testFixedLinearAvailabilityConsumesPriorOneShotRoles()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Story",
            OptionKey = "F_Story01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
        },
        {
            RoleKey = "Story",
            OptionKey = "F_Story01",
        },
    })
    local values = {}

    data.fillRoleValues(instance, rows, 6, values)
    lu.assertTrue(hasValue(values, "Story"))

    data.fillRoleValues(instance, rows, 7, values)
    lu.assertTrue(hasValue(values, "Story"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 7).Story)
end

function TestRunPlannerControls.testFixedLinearAvailabilityChecksPreviousRoomExitRequirement()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local missingExitRows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
    })
    local validExitRows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    })
    local values = {}

    data.fillRoleValues(instance, missingExitRows, 6, values)
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, missingExitRows, 6).Midshop)

    data.fillRoleValues(instance, validExitRows, 6, values)
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertNil(data.roleValueColorsForRow(instance, validExitRows, 6).Midshop)
end

function TestRunPlannerControls.testFixedLinearReadPassInvalidationRefreshesCachedValues()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rowState = {
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
    }
    local rows = fakeRows(rowState)

    data.beginReadPass(instance)
    local values = data.roleValuesForRow(instance, rows, 6)
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 6).Midshop)

    rowState[5].OptionKey = "F_Combat02"
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 6).Midshop)

    data.invalidateReadPass(instance)
    lu.assertTrue(hasValue(data.roleValuesForRow(instance, rows, 6), "Midshop"))
    lu.assertNil(data.roleValueColorsForRow(instance, rows, 6).Midshop)
    data.endReadPass(instance)
end

function TestRunPlannerControls.testFixedLinearRowContextUsesSelectionDepthCosts()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
        },
        {
            RoleKey = "Story",
            OptionKey = "F_Story01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
        },
    })

    lu.assertEquals(data.rowContext(instance, rows, 1), {
        rowIndex = 1,
        routeOrdinal = 0,
        biomeDepthCache = 0,
        biomeDepthCacheKnown = true,
        biomeDepthCacheCost = 0,
        biomeDepthCacheCostKnown = true,
        biomeEncounterDepth = 0,
        biomeEncounterDepthKnown = true,
        biomeEncounterDepthCost = 1,
        biomeEncounterDepthCostKnown = true,
        roomHistoryCost = 1,
    })
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeDepthCache, 3)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepth, 4)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCost, 0)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeDepthCache, 4)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepth, 4)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepthCost, 1)
end

function TestRunPlannerControls.testFixedLinearUnknownEncounterDepthBlocksDepthGatedOptions()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat05",
        },
    })

    local context = data.rowContext(instance, rows, 3)
    lu.assertNil(context.biomeEncounterDepth)
    lu.assertFalse(context.biomeEncounterDepthKnown)
    lu.assertFalse(data.isOptionAvailable(instance, rows, 3, "Combat", "F_Combat05"))

    local validation = data.validateRow(instance, rows, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "encounter_depth_unknown")
end

function TestRunPlannerControls.testFixedLinearRowContextUsesOptionDepthCostOverrides()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "Q_Combat10",
        },
        {
            RoleKey = "Combat",
            OptionKey = "Q_Combat03",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "Q_MiniBoss02",
        },
        {
            RoleKey = "Combat",
            OptionKey = "Q_Combat04",
        },
        {
            RoleKey = "Combat",
            OptionKey = "Q_Combat12",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "Q_MiniBoss04",
        },
        {
            RoleKey = "Shop",
        },
    })

    lu.assertEquals(data.rowContext(instance, rows, 7).biomeDepthCache, 6)
    lu.assertEquals(data.rowContext(instance, rows, 7).biomeEncounterDepth, 5)
    lu.assertEquals(data.rowContext(instance, rows, 7).biomeEncounterDepthCost, 0)
    lu.assertEquals(data.rowContext(instance, rows, 8).biomeEncounterDepth, 5)
end

function TestRunPlannerControls.testMinibossRequiresConcreteOption()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Miniboss",
        },
    })
    local values = {}

    data.fillOptionValues(instance, rows, 6, "Miniboss", values)
    lu.assertEquals(values[1], "F_MiniBoss01")

    local validation = data.validateRow(instance, rows, 6)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "option_required")
end

function TestRunPlannerControls.testConcreteMinibossOptionUsesLeafDepthCost()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteP",
        biome = catalog.lookup.P,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "P_MiniBoss01",
        },
    })

    lu.assertTrue(data.validateRow(instance, rows, 5).valid)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCost, 0)
end

function TestRunPlannerControls.testFixedLinearCombatRewardSurfaceMarksDevotionCapableMaps()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })

    local combatRole = instance.rolesByKey.Combat
    lu.assertNil(optionByKey(combatRole.mapOptions, "F_Combat02").reward)
    lu.assertEquals(optionByKey(combatRole.mapOptions, "F_Combat05").reward, {
        kind = "majorMinor",
        majorRewardStore = "RunProgress",
        minorRewardStore = "MetaProgress",
        allowDevotion = true,
    })
    lu.assertFalse(hasValue(instance.roleValues, "Trial"))
end

function TestRunPlannerControls.testRouteContextDevotionRewardUsesPriorUnderworldBiomes()
    local catalog = loadCatalog()
    local fixedTemplate = loadFixedLinearTemplate()
    local fInstance = fixedTemplate.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fControl = fixedTemplate.createRuntime(routeFields({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ApolloUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat13",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), fInstance)
    local template = loadClockworkGoalTemplate()
    local iInstance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local iControl = template.createRuntime(routeFields({
        {},
        {
            RoleKey = "Goal",
            OptionKey = "I_Combat01",
        },
        {
            RoleKey = "ExtensionCombat",
            OptionKey = "I_Combat03",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ApolloUpgrade",
        },
    }), iInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F", "I" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return fControl
            elseif controlName == "RouteI" then
                return iControl
            end
            return nil
        end,
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
end

function TestRunPlannerControls.testRouteContextScopesPriorGodLootByRoute()
    local catalog = loadCatalog()
    local fixedTemplate = loadFixedLinearTemplate()
    local fInstance = fixedTemplate.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fControl = fixedTemplate.createRuntime(routeFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ApolloUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat13",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), fInstance)
    local template = loadClockworkGoalTemplate()
    local iInstance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local iControl = template.createRuntime(routeFields({
        {},
        {
            RoleKey = "Goal",
            OptionKey = "I_Combat01",
        },
        {
            RoleKey = "ExtensionCombat",
            OptionKey = "I_Combat03",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ApolloUpgrade",
        },
    }), iInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "WithErebus",
                label = "With Erebus",
                biomes = { "F", "I" },
            },
            {
                key = "TartarusOnly",
                label = "Tartarus Only",
                biomes = { "I" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return fControl
            elseif controlName == "RouteI" then
                return iControl
            end
            return nil
        end,
    })

    lu.assertFalse(routeContext:overview("TartarusOnly").valid)
    lu.assertEquals(routeContext:rewardRowValidation("TartarusOnly", "I", 3).code, "prior_distinct_god_loot")

    lu.assertTrue(routeContext:overview("WithErebus").valid)
end

local function routeRewardRow(rowIndex, rewardType, opts)
    opts = opts or {}
    return {
        rowIndex = rowIndex,
        routeOrdinal = opts.routeOrdinal or rowIndex,
        slotLabel = opts.slotLabel or ("Depth " .. tostring(rowIndex)),
        roleKey = "Combat",
        option = {
            key = opts.roomKey or ("Test_Combat" .. tostring(rowIndex)),
            label = opts.roomLabel or "Combat",
            exitCount = opts.exitCount,
        },
        valid = opts.valid ~= false,
        rewardKind = opts.rewardKind or "roomStore",
        rewards = opts.rewards or { rewardType },
        rewardPicks = opts.rewardPicks or {},
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1,
        biomeEncounterDepthCostKnown = opts.biomeEncounterDepthCostKnown ~= false,
    }
end

local function fakeRouteControlSnapshot(controlName, rows)
    return {
        read = function(_, path)
            if path == "snapshot" then
                return {
                    controlName = controlName,
                    valid = true,
                    invalidRows = {},
                    rows = normalizeRewardRows(rows or {}),
                }
            end
            return nil
        end,
    }
end

local function rewardLegalityRouteContext(route, controls, opts)
    opts = opts or {}
    return loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = opts.biomes or {},
        controlResolver = function(controlName)
            return controls[controlName]
        end,
    })
end

local function fakeTimelineBiome()
    return {
        timeline = {
            afterBiome = {
                { key = "Boss", roomHistoryCost = 1 },
                { key = "PostBoss", roomHistoryCost = 1 },
            },
        },
    }
end

local function devotionRewardRow(rowIndex, opts)
    opts = opts or {}
    return routeRewardRow(rowIndex, "Devotion", {
        exitCount = opts.exitCount,
        rewardKind = "majorMinor",
        rewards = { "Major", "Devotion", "", "", "ZeusUpgrade", "ApolloUpgrade" },
    })
end

local function boonRewardRow(rowIndex, lootName, opts)
    opts = opts or {}
    return routeRewardRow(rowIndex, "Boon", {
        exitCount = opts.exitCount,
        rewards = { "Major", "Boon", lootName },
        rewardKind = "majorMinor",
        rewardPicks = {
            { kind = "boonSource", value = lootName },
        },
    })
end

local function firstValidDevotionRows()
    return {
        boonRewardRow(1, "ZeusUpgrade"),
        boonRewardRow(2, "ApolloUpgrade"),
        routeRewardRow(3, "MaxHealthDrop"),
        routeRewardRow(4, "MaxHealthDrop"),
        routeRewardRow(5, "MaxHealthDrop"),
        routeRewardRow(6, "MaxHealthDrop"),
        routeRewardRow(7, "MaxHealthDrop"),
        routeRewardRow(8, "MaxHealthDrop", { exitCount = 2 }),
        devotionRewardRow(9),
    }
end

function TestRunPlannerControls.testRouteContextInvalidatesTalentRewardsBeforeSpellDrop()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "TalentDrop"),
            routeRewardRow(2, "MinorTalentDrop"),
            routeRewardRow(3, "SpellDrop"),
            routeRewardRow(4, "TalentBigDrop"),
        }),
    }, {
        biomes = {
            F = { label = "Erebus" },
        },
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 1)
    lu.assertEquals(overview.invalidRows[1].address, "row")
    lu.assertEquals(overview.invalidRows[1].rewardType, "TalentDrop")
    lu.assertEquals(overview.invalidRows[1].locationLabel, "Erebus Depth 1 Rewards")
    lu.assertEquals(overview.invalidRows[1].code, "talent_requires_spell")
    lu.assertEquals(overview.invalidRows[2].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[2].address, "row")
    lu.assertEquals(overview.invalidRows[2].rewardType, "MinorTalentDrop")
    lu.assertEquals(overview.invalidRows[2].code, "talent_requires_spell")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 1).code, "talent_requires_spell")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 1).address, "row")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 1).rewardType, "TalentDrop")
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "F", 4))
end

function TestRunPlannerControls.testRouteContextPreservesRewardInvalidAddress()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "Shop", {
                rewardKind = "shop",
                rewards = { "RandomLoot", "TalentDrop" },
                rewardLoot = { "ZeusUpgrade", "" },
            }),
        }),
    }, {
        biomes = {
            F = { label = "Erebus" },
        },
    })

    local invalid = routeContext:overview("Underworld").invalidRows[1]

    lu.assertEquals(invalid.rowIndex, 1)
    lu.assertEquals(invalid.address, "shop:2")
    lu.assertEquals(invalid.rewardType, "TalentDrop")
    lu.assertEquals(invalid.locationLabel, "Erebus Depth 1 Shop Offer 2")
    lu.assertEquals(invalid.code, "talent_requires_spell")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 1).address, "shop:2")
end

function TestRunPlannerControls.testRouteContextInvalidatesDevotionBeforeSevenRunEncounters()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            boonRewardRow(1, "ZeusUpgrade"),
            boonRewardRow(2, "ApolloUpgrade", { exitCount = 2 }),
            devotionRewardRow(3),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 3)
    lu.assertEquals(overview.invalidRows[1].code, "devotion_run_encounter_depth")
end

function TestRunPlannerControls.testRouteContextAllowsDevotionAfterSevenRunEncounters()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            boonRewardRow(1, "ZeusUpgrade"),
            boonRewardRow(2, "ApolloUpgrade"),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop", { exitCount = 2 }),
            devotionRewardRow(8),
        }),
    })

    lu.assertTrue(routeContext:overview("Underworld").valid)
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "F", 8))
end

function TestRunPlannerControls.testRouteContextInvalidatesDevotionBeforeFifteenRooms()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", firstValidDevotionRows()),
        RouteG = fakeRouteControlSnapshot("RouteG", {
            routeRewardRow(1, "MaxHealthDrop"),
            routeRewardRow(2, "MaxHealthDrop"),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop"),
            routeRewardRow(8, "MaxHealthDrop"),
            routeRewardRow(9, "MaxHealthDrop"),
            routeRewardRow(10, "MaxHealthDrop"),
            routeRewardRow(11, "MaxHealthDrop", { exitCount = 2 }),
            devotionRewardRow(12),
        }),
    }, {
        biomes = {
            F = fakeTimelineBiome(),
            G = fakeTimelineBiome(),
        },
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "G")
    lu.assertEquals(overview.invalidRows[1].rowIndex, 12)
    lu.assertEquals(overview.invalidRows[1].code, "devotion_spacing")
end

function TestRunPlannerControls.testRouteContextCountsTimelineRoomsForDevotionSpacing()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", firstValidDevotionRows()),
        RouteG = fakeRouteControlSnapshot("RouteG", {
            routeRewardRow(1, "MaxHealthDrop"),
            routeRewardRow(2, "MaxHealthDrop"),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop"),
            routeRewardRow(8, "MaxHealthDrop"),
            routeRewardRow(9, "MaxHealthDrop"),
            routeRewardRow(10, "MaxHealthDrop"),
            routeRewardRow(11, "MaxHealthDrop"),
            routeRewardRow(12, "MaxHealthDrop", { exitCount = 2 }),
            devotionRewardRow(13),
        }),
    }, {
        biomes = {
            F = fakeTimelineBiome(),
            G = fakeTimelineBiome(),
        },
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "G", 13))
end

function TestRunPlannerControls.testRouteContextInvalidatesDuplicateSpellDrops()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "SpellDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "spell_drop_limit")
end

function TestRunPlannerControls.testRouteContextInvalidatesTalentAfterPreviousShopTalent()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "TalentDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(3, "TalentBigDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 3)
    lu.assertEquals(overview.invalidRows[1].code, "talent_shop_conflict")
end

function TestRunPlannerControls.testRouteContextOnlyAppliesShopTalentBlockerToNextRow()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "TalentDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "TalentBigDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertEquals(#overview.invalidRows, 0)
end

function TestRunPlannerControls.testRouteContextDevotionPairSkipsPreviousExitRequirement()
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "O" },
    }, {
        RouteO = fakeRouteControlSnapshot("RouteO", {
            routeRewardRow(1, "Boon", {
                rewards = { "Boon", "ZeusUpgrade" },
            }),
            routeRewardRow(2, "Boon", {
                rewards = { "Boon", "ApolloUpgrade" },
            }),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop"),
            routeRewardRow(8, "Devotion", {
                rewardKind = "devotionPair",
                rewards = { "ZeusUpgrade", "ApolloUpgrade" },
            }),
        }),
    })

    local overview = routeContext:overview("Surface")

    lu.assertTrue(overview.valid)
    lu.assertNil(routeContext:rewardRowValidation("Surface", "O", 8))
end

function TestRunPlannerControls.testRouteContextDevotionPairRequiresPriorGodLoot()
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "O" },
    }, {
        RouteO = fakeRouteControlSnapshot("RouteO", {
            routeRewardRow(1, "Devotion", {
                rewardKind = "devotionPair",
                rewards = { "ZeusUpgrade", "ApolloUpgrade" },
            }),
        }),
    })

    local overview = routeContext:overview("Surface")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 1)
    lu.assertEquals(overview.invalidRows[1].code, "prior_distinct_god_loot")
end

function TestRunPlannerControls.testRouteContextSelectableDevotionRequiresPreviousExitCount()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "Boon", {
                rewards = { "Major", "Boon", "ZeusUpgrade" },
                rewardKind = "majorMinor",
                rewardPicks = {
                    { kind = "boonSource", value = "ZeusUpgrade" },
                },
            }),
            routeRewardRow(2, "Boon", {
                rewards = { "Major", "Boon", "ApolloUpgrade" },
                rewardKind = "majorMinor",
                rewardPicks = {
                    { kind = "boonSource", value = "ApolloUpgrade" },
                },
            }),
            routeRewardRow(3, "Devotion", {
                rewards = { "Major", "Devotion", "", "", "ZeusUpgrade", "ApolloUpgrade" },
                rewardKind = "majorMinor",
            }),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 3)
    lu.assertEquals(overview.invalidRows[1].code, "previous_room_exit_count")
end

function TestRunPlannerControls.testRouteContextInvalidatesHermesBiomeAndRouteLimits()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "HermesUpgrade"),
            routeRewardRow(2, "ShopHermesUpgrade"),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {
            routeRewardRow(1, "HermesUpgrade"),
        }),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "HermesUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "F")
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "hermes_biome_limit")
    lu.assertEquals(overview.invalidRows[2].biomeKey, "H")
    lu.assertEquals(overview.invalidRows[2].code, "hermes_run_limit")
end

function TestRunPlannerControls.testRouteContextInvalidatesEarlySecondWeaponUpgrade()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "G")
    lu.assertEquals(overview.invalidRows[1].code, "weapon_upgrade_late_requirement")
end

function TestRunPlannerControls.testRouteContextAllowsSecondWeaponUpgradeFromThirdBiome()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertEquals(#overview.invalidRows, 0)
end

function TestRunPlannerControls.testRouteContextInvalidatesWeaponUpgradeAfterPreviousShopHammer()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {}),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "WeaponUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "H")
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "weapon_upgrade_shop_conflict")
end

function TestRunPlannerControls.testRouteContextOnlyAppliesShopHammerBlockerToNextRow()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {}),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "MaxHealthDrop"),
            routeRewardRow(3, "WeaponUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertEquals(#overview.invalidRows, 0)
end

function TestRunPlannerControls.testFixedLinearRuntimeUsesRouteRewardValidation()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), instance)
    control:setRouteContext({
        rewardRowValidation = function(_, routeKey, biomeKey, rowIndex)
            if routeKey == "Underworld" and biomeKey == "F" and rowIndex == 2 then
                return {
                    valid = false,
                    code = "route_reward",
                    message = "Route reward invalid",
                }
            end
            return nil
        end,
    }, "Underworld")

    local validation = control:rowValidation(2)

    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "route_reward")
end

function TestRunPlannerControls.testRouteContextInvalidatesThirdWeaponUpgrade()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H", "I" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop"),
        }),
        RouteI = fakeRouteControlSnapshot("RouteI", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "I")
    lu.assertEquals(overview.invalidRows[1].code, "weapon_upgrade_run_limit")
end

function TestRunPlannerControls.testRouteContextBuildsNpcTargetsFromValidCombatRows()
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
                                        routeOrdinal = 3,
                                        slotLabel = "Depth 3",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat02", label = "Combat 02" },
                                        valid = true,
                                    },
                                    {
                                        rowIndex = 2,
                                        routeOrdinal = 4,
                                        slotLabel = "Depth 4",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat03", label = "Combat 03" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "Boon", "ZeusUpgrade" },
                                    },
                                    {
                                        rowIndex = 3,
                                        routeOrdinal = 5,
                                        slotLabel = "Depth 5",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat04", label = "Combat 04" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "MaxHealthDrop" },
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

    local targets = routeContext:npcTargets("Underworld")

    lu.assertNil(targets.byNpc.Artemis.lookup["F:1:ArtemisCombatF"])
    lu.assertNil(targets.byNpc.Artemis.lookup["F:2:ArtemisCombatF"])
    lu.assertNotNil(targets.byNpc.Artemis.lookup["F:3:ArtemisCombatF"])
    lu.assertEquals(targets.byNpc.Artemis.displayValues["F:3:ArtemisCombatF"], "Erebus Depth 5 - Combat 04")
    lu.assertNotNil(targets.byNpc.Nemesis.lookup["F:3:Combat"])
    lu.assertNotNil(targets.byNpc.Nemesis.lookup["F:3:Random"])
    lu.assertEquals(targets.byNpcBiome.Arachne.F.values, {
        "",
        "F:3:ArachneCombatF",
    })
end

function TestRunPlannerControls.testRouteContextDisablesNpcTargetsWhenRewardsAreNotConfigured()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local globalFields = routeUiFields(globalTemplate.storage(globalInstance))
    globalFields.ConfigureRewards:write(false)
    local globalControl = globalTemplate.createRuntime(globalFields, globalInstance)
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
        controlResolver = function(controlName)
            if controlName == "RouteGlobalUnderworld" then
                return globalControl
            elseif controlName == "RouteF" then
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
                                        routeOrdinal = 5,
                                        slotLabel = "Depth 5",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat04", label = "Combat 04" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "Boon", "ZeusUpgrade" },
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

    local targets = routeContext:npcTargets("Underworld")

    lu.assertNil(targets.byNpc.Artemis)
    lu.assertNil(targets.byNpcBiome.Artemis)
end

function TestRunPlannerControls.testRouteContextUsesRoomHistoryTimelineForNpcTargets()
    local catalog = loadCatalog()
    local hubTemplate = loadHubPylonTemplate()
    local nInstance = hubTemplate.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
	    local nControl = hubTemplate.createRuntime(routeFields({
	        {},
	        {},
	        {},
	        {
	            RoleKey = "Combat",
	            OptionKey = "N_Combat01",
	            Reward1Key = "MaxHealthDropBig",
	        },
	        {
	            RoleKey = "Combat",
	            OptionKey = "N_Combat02",
	            Reward1Key = "MaxManaDropBig",
	        },
	    }), nInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Surface",
                label = "Surface",
                biomes = { "N" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteN" then
                return nControl
            end
            return nil
        end,
    })

    local targets = routeContext:npcTargets("Surface")

    lu.assertEquals(targets.byNpc.Heracles.lookup["N:4:HeraclesCombatN"].roomHistoryOrdinal, 4)
    lu.assertEquals(targets.byNpc.Heracles.lookup["N:5:HeraclesCombatN"].roomHistoryOrdinal, 6)
end

function TestRunPlannerControls.testRouteContextAddsPostBiomeTimelineForNpcSpacing()
    local catalog = loadCatalog()
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F", "G" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
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
	                                        routeOrdinal = 4,
	                                        slotLabel = "Depth 4",
	                                        roleKey = "Combat",
	                                        option = { key = "F_Combat03", label = "Combat F" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
	                                        rewards = { "Major", "MaxHealthDrop" },
	                                    },
                                }),
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
	                                        routeOrdinal = 4,
	                                        slotLabel = "Depth 4",
	                                        roleKey = "Combat",
	                                        option = { key = "G_Combat03", label = "Combat G" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
	                                        rewards = { "Major", "MaxHealthDrop" },
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

    local targets = routeContext:npcTargets("Underworld")

    lu.assertEquals(targets.byNpc.Artemis.lookup["F:1:ArtemisCombatF"].roomHistoryOrdinal, 1)
    lu.assertEquals(targets.byNpc.Artemis.lookup["G:1:ArtemisCombatG"].roomHistoryOrdinal, 4)
end

function TestRunPlannerControls.testRouteContextFiltersOlympusNpcsByRoomTag()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local pInstance = template.prepare({
        name = "RouteP",
        biome = catalog.lookup.P,
    })
    local pControl = template.createRuntime(routeFields({
        {},
        { RoleKey = "Combat", OptionKey = "P_Combat02" },
        { RoleKey = "Combat", OptionKey = "P_Combat04" },
        {
            RoleKey = "Combat",
            OptionKey = "P_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "P_Combat17",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), pInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Surface",
                label = "Surface",
                biomes = { "P" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteP" then
                return pControl
            end
            return nil
        end,
    })

    local targets = routeContext:npcTargets("Surface")

    lu.assertNotNil(targets.byNpc.Heracles.lookup["P:4:HeraclesCombatP"])
    lu.assertNil(targets.byNpc.Heracles.lookup["P:5:HeraclesCombatP"])
    lu.assertNil(targets.byNpc.Icarus.lookup["P:4:IcarusCombatP"])
    lu.assertNotNil(targets.byNpc.Icarus.lookup["P:5:IcarusCombatP"])
    lu.assertEquals(
        targets.byNpc.Heracles.displayValues["P:4:HeraclesCombatP"],
        "Olympus Depth 3 - Combat 02"
    )
    lu.assertEquals(
        targets.byNpc.Icarus.displayValues["P:5:IcarusCombatP"],
        "Olympus Depth 4 - Combat 17"
    )
end

function TestRunPlannerControls.testRouteNpcsSnapshotValidatesTargetsAndSpacing()
    local catalog = loadCatalog()
    local route = {
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }
    local template = loadRouteNpcsTemplate()
    local instance = template.prepare({
        name = "RouteNpcsUnderworld",
        route = route,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local control = template.createRuntime(npcFields({
        {
            VariantKey = "ArtemisCombatF",
            BiomeKey = "F",
            RowIndex = "3",
        },
        {
            VariantKey = "Combat",
            BiomeKey = "F",
            RowIndex = "4",
        },
        {
            VariantKey = "ArachneCombatF",
            BiomeKey = "F",
            RowIndex = "2",
        },
    }), instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
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
                                        rowIndex = 2,
	                                        routeOrdinal = 4,
	                                        slotLabel = "Depth 4",
	                                        roleKey = "Combat",
	                                        option = { key = "F_Combat03", label = "Combat 03" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
	                                        rewards = { "Major", "Boon", "ZeusUpgrade" },
                                    },
                                    {
                                        rowIndex = 3,
	                                        routeOrdinal = 5,
	                                        slotLabel = "Depth 5",
	                                        roleKey = "Combat",
	                                        option = { key = "F_Combat04", label = "Combat 04" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
	                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                    {
                                        rowIndex = 4,
	                                        routeOrdinal = 6,
	                                        slotLabel = "Depth 6",
	                                        roleKey = "Combat",
	                                        option = { key = "F_Combat05", label = "Combat 05" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            if controlName == "RouteNpcsUnderworld" then
                return control
            end
            return nil
        end,
    })

    control:setRouteContext(routeContext, "Underworld")
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertFalse(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[2].invalidCode, "npc_spacing")
    lu.assertFalse(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[3].invalidCode, "npc_target_unavailable")

    local routeSnapshot = routeContext:overview("Underworld")
    lu.assertFalse(routeSnapshot.valid)
    lu.assertEquals(routeSnapshot.invalidRows[1].controlName, "RouteNpcsUnderworld")
    lu.assertEquals(routeSnapshot.invalidRows[1].code, "npc_spacing")
    lu.assertEquals(routeSnapshot.invalidRows[1].locationLabel, snapshot.invalidRows[1].locationLabel)
end

function TestRunPlannerControls.testRouteOverviewRebuildsOnlyWhenDirty()
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

function TestRunPlannerControls.testMultiEncounterDevotionRequirementsUsePriorSurfaceBiomes()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalSurface",
        route = catalog.routes.lookup.Surface,
        gods = catalog.gods,
    })
    local globalFields = routeUiFields(globalTemplate.storage(globalInstance))
    globalFields.ConfigureRewards:write(false)
    local globalControl = globalTemplate.createRuntime(globalFields, globalInstance)
    local hubTemplate = loadHubPylonTemplate()
    local nInstance = hubTemplate.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local nControl = hubTemplate.createRuntime(routeFields({
        {},
        {},
        {},
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat12",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Story",
            OptionKey = "N_Story01",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "N_MiniBoss02",
            Reward1Key = "AphroditeUpgrade",
        },
    }), nInstance)
    local routeContext = loadRunContext().create({
        routes = catalog.routes,
        controlResolver = function(controlName)
            if controlName == "RouteN" then
                return nControl
            elseif controlName == "RouteGlobalSurface" then
                return globalControl
            end
            return nil
        end,
    })

    local data = loadMultiEncounterData()
    local oInstance = data.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local rows = fakeRows({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat02",
        },
        {},
    })

    lu.assertTrue(hasValue(data.roleValuesForRow(oInstance, rows, 4), "Devotion"))

    oInstance.routeContext = routeContext
    oInstance.routeKey = "Surface"
    lu.assertTrue(hasValue(data.roleValuesForRow(oInstance, rows, 4), "Devotion"))
    lu.assertNotNil(data.roleValueColorsForRow(oInstance, rows, 4).Devotion)

    globalFields.ConfigureRewards:write(true)
    routeContext:beginPass()
    lu.assertTrue(hasValue(data.roleValuesForRow(oInstance, rows, 4), "Devotion"))
    lu.assertNil(data.roleValueColorsForRow(oInstance, rows, 4).Devotion)
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesPreviousRoomExitRequirement()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            { RoleKey = "" },
	            { RoleKey = "Combat", OptionKey = "F_Combat02" },
	            { RoleKey = "Combat", OptionKey = "F_Combat03" },
	            {
                RoleKey = "Combat",
                OptionKey = "F_Combat01",
            },
	            {
	                RoleKey = "Midshop",
	                OptionKey = "F_Shop01",
	            },
	        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "previous_room_exit_count")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertFalse(snapshot.rows[5].valid)
    lu.assertEquals(snapshot.rows[5].invalidCode, "previous_room_exit_count")
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesDevotionRewardRequirements()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            {
	                RoleKey = "",
	            },
	            {
	                RoleKey = "Combat",
	                OptionKey = "F_Combat02",
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat03",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat04",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat04",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat05",
                Reward1Key = "Major",
                Reward2Key = "Devotion",
                Reward5Key = "ZeusUpgrade",
                Reward6Key = "ApolloUpgrade",
            },
	        }), instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return control
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, "Underworld")

    local validation = control:rowValidation(6)

    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "prior_distinct_god_loot")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 6).code, "prior_distinct_god_loot")
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesOutOfRangeAndDuplicateRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            {
	                RoleKey = "",
	            },
	            {
	                RoleKey = "Story",
	                OptionKey = "F_Story01",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Story",
                OptionKey = "F_Story01",
            },
            {
                RoleKey = "Story",
                OptionKey = "F_Story01",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 2)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "biome_depth_unavailable")
    lu.assertEquals(snapshot.invalidRows[2].rowIndex, 7)
    lu.assertEquals(snapshot.invalidRows[2].code, "role_limit")
    lu.assertEquals(snapshot.rows[2].roleKey, "Story")
    lu.assertEquals(snapshot.rows[2].optionKey, "F_Story01")
    lu.assertFalse(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[6].roleKey, "Story")
    lu.assertEquals(snapshot.rows[6].optionKey, "F_Story01")
    lu.assertTrue(snapshot.rows[6].valid)
    lu.assertEquals(snapshot.rows[7].roleKey, "Story")
    lu.assertEquals(snapshot.rows[7].optionKey, "F_Story01")
    lu.assertFalse(snapshot.rows[7].valid)
    lu.assertEquals(snapshot.rows[7].invalidCode, "role_limit")
end
