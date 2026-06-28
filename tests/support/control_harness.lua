local importHarness = require("tests.support.import_harness")
local testImport = importHarness.testImport
local withTestImport = importHarness.withTestImport

local function normalizeRewardRows(rows)
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    for _, row in ipairs(rows or {}) do
        if row.biomeEncounterDepthCost == nil then
            row.biomeEncounterDepthCost = 1
        end
        rewardItems.attach(row)
    end
    return rows
end

local loadedCatalogDeps

local function loadCatalogDeps()
    if loadedCatalogDeps == nil then
        loadedCatalogDeps = importHarness.loadCatalogDeps()
    end
    return loadedCatalogDeps
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
    local catalog
    withTestImport(function()
        catalog = data.loadCatalog(loadCatalogDeps())
    end)
    return catalog, data
end

local loadedRewardDomain

local function loadRewardDomain()
    if loadedRewardDomain == nil then
        loadedRewardDomain = importHarness.loadRewardDomain()
    end
    return loadedRewardDomain
end

local loadedRewardConditions

local function loadRewardConditions()
    if loadedRewardConditions == nil then
        loadedRewardConditions = importHarness.loadRewardConditions()
    end
    return loadedRewardConditions
end

local function loadRouteDeps()
    local route
    withTestImport(function()
        local rewards = testImport("mods/rewards/rewards.lua").create({
            rewardDomain = loadRewardDomain(),
        })
        local timeline = testImport("mods/route/timeline.lua")
        local routeEvents = testImport("mods/route/events.lua")
        local routeQuery = testImport("mods/route/query.lua", nil, {
            events = routeEvents,
        })
        local valueStates = testImport("mods/route/value_states.lua")
        local controlRequirements = testImport("mods/route/control_requirements.lua", nil, {
            valueStates = valueStates,
        })
        local rows = testImport("mods/route/rows.lua", nil, {
            rewards = rewards,
            timeline = timeline,
            controlRequirements = controlRequirements,
            query = routeQuery,
        })
        route = {
            common = rows.common,
            availability = rows.availability,
            readCache = rows.readCache,
            requirements = rows.requirements,
            biomeRules = rows.biomeRules,
            valueStates = rows.valueStates,
            rowEngine = rows.engine,
            timeline = timeline,
            query = routeQuery,
            controlRequirements = controlRequirements,
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
    local semantics = testImport("mods/route/reward_planning/semantics.lua")
    local invalidLocations = testImport("mods/route/invalid_locations.lua")
    local routeQuery = testImport("mods/route/query.lua", nil, {
        events = testImport("mods/route/events.lua"),
    })
    local valueStates = testImport("mods/route/value_states.lua")
    local controlRequirements = testImport("mods/route/control_requirements.lua", nil, {
        valueStates = valueStates,
    })
    return testImport("mods/route/reward_planning/legality.lua", nil, {
        conditions = loadRewardConditions(),
        rewardItems = testImport("mods/route/reward_planning/items.lua"),
        semantics = semantics,
        invalidLocations = invalidLocations,
        context = testImport("mods/route/reward_planning/context.lua"),
        markers = testImport("mods/route/reward_planning/marker_targets.lua", nil, {
            markers = testImport("mods/route/markers.lua"),
            semantics = semantics,
            invalidLocations = invalidLocations,
        }),
        topologyBranches = testImport("mods/route/reward_planning/topology_branches.lua", nil, {
            valueStates = valueStates,
            controlRequirements = controlRequirements,
        }),
        controlRequirements = controlRequirements,
        query = routeQuery,
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
    local routeDeps = loadRouteDeps()
    local deps = {}
    for key, value in pairs(routeDeps) do
        deps[key] = value
    end
    deps.roomTopology = testImport("mods/controls/biome_helpers/room_topology.lua", nil, {
        common = routeDeps.common,
        availability = routeDeps.availability,
        valueStates = routeDeps.valueStates,
    })
    deps.roomStructure = testImport("mods/controls/biome_helpers/room_structure.lua")
    deps.roomTopologyAdapter = testImport("mods/controls/biome_helpers/room_topology_adapter.lua", nil, {
        common = routeDeps.common,
        readCache = routeDeps.readCache,
        roomTopology = deps.roomTopology,
        roomStructure = deps.roomStructure,
        valueStates = routeDeps.valueStates,
        controlRequirements = routeDeps.controlRequirements,
    })
    return withTestImport(function()
        return testImport("mods/controls/FixedLinearRoute/data/data.lua", nil, deps)
    end)
end

local function loadClockworkGoalData()
    local routeDeps = loadRouteDeps()
    local deps = {}
    for key, value in pairs(routeDeps) do
        deps[key] = value
    end
    deps.roomTopology = testImport("mods/controls/biome_helpers/room_topology.lua", nil, {
        common = routeDeps.common,
        availability = routeDeps.availability,
        valueStates = routeDeps.valueStates,
    })
    deps.roomStructure = testImport("mods/controls/biome_helpers/room_structure.lua")
    deps.roomTopologyAdapter = testImport("mods/controls/biome_helpers/room_topology_adapter.lua", nil, {
        common = routeDeps.common,
        readCache = routeDeps.readCache,
        roomTopology = deps.roomTopology,
        roomStructure = deps.roomStructure,
        valueStates = routeDeps.valueStates,
        controlRequirements = routeDeps.controlRequirements,
    })
    return withTestImport(function()
        return testImport("mods/controls/ClockworkGoalRoute/data/data.lua", nil, deps)
    end)
end

local function loadHubPylonData()
    return testImport("mods/controls/HubPylonRoute/data.lua", nil, loadRouteDeps())
end

local function loadMultiEncounterData()
    return testImport("mods/controls/MultiEncounterFixedRoute/data.lua", nil, loadRouteDeps())
end

local function loadFieldsCageDeps()
    local routeDeps = loadRouteDeps()
    local deps = {}
    for key, value in pairs(routeDeps) do
        deps[key] = value
    end
    deps.roomTopology = testImport("mods/controls/biome_helpers/room_topology.lua", nil, {
        common = routeDeps.common,
        availability = routeDeps.availability,
        valueStates = routeDeps.valueStates,
    })
    deps.roomStructure = testImport("mods/controls/biome_helpers/room_structure.lua")
    deps.roomTopologyAdapter = testImport("mods/controls/biome_helpers/room_topology_adapter.lua", nil, {
        common = routeDeps.common,
        readCache = routeDeps.readCache,
        roomTopology = deps.roomTopology,
        roomStructure = deps.roomStructure,
        valueStates = routeDeps.valueStates,
        controlRequirements = routeDeps.controlRequirements,
    })
    return deps
end

local function loadFieldsCageData()
    return withTestImport(function()
        return testImport("mods/controls/FieldsCageRoute/data/data.lua", nil, loadFieldsCageDeps())
    end)
end

local function loadRunContext()
    local timeline = testImport("mods/route/timeline.lua")
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    local semantics = testImport("mods/route/reward_planning/semantics.lua")
    return testImport("mods/route/run_context.lua", nil, {
        controls = testImport("mods/route/run_context/controls.lua"),
        position = testImport("mods/route/position.lua"),
        targets = loadRouteTargets(timeline, rewardItems, semantics),
        rewards = testImport("mods/route/run_context/rewards.lua", nil, {
            rewardLegality = loadRewardLegality(),
            rewardItems = rewardItems,
            semantics = semantics,
            timeline = timeline,
            valueStates = testImport("mods/route/value_states.lua"),
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

local function routeFields(rows, sideRows, sideRewardRows, encounterRewardRows)
    return {
        Rooms = fakeRows(rows or {}),
        Rewards = fakeRows(rows or {}),
        SideRooms = fakeRows(sideRows or {}),
        SideRewards = fakeRows(sideRewardRows or {}),
        EncounterRewards = fakeRows(encounterRewardRows or {}),
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
        "TextColored",
        "TextWrapped",
        "SameLine",
        "SetCursorPosX",
        "Indent",
        "Unindent",
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

local function measureCpuMs(iterations, callback)
    callback()
    collectgarbage("collect")
    local before = os.clock()
    for _ = 1, iterations do
        callback()
    end
    return (os.clock() - before) * 1000
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
        rewardLoot = opts.rewardLoot or {},
        rewardPicks = opts.rewardPicks or {},
        selectionRequirements = opts.selectionRequirements or {},
        rewardSourceCount = opts.rewardSourceCount,
        invalidCode = opts.invalidCode,
        invalidReason = opts.invalidReason,
        locationLabel = opts.locationLabel,
        rewardConstraints = opts.rewardConstraints,
        rewardRowGroup = opts.rewardRowGroup,
        roomTopology = opts.roomTopology,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1,
    }
end

local function fakeRouteControlSnapshot(controlName, rows)
    return {
        read = function(_, path)
            if path == "snapshot" then
                local snapshotRows = normalizeRewardRows(rows or {})
                local invalidRows = {}
                for _, row in ipairs(snapshotRows) do
                    if row.valid == false then
                        invalidRows[#invalidRows + 1] = {
                            rowIndex = row.rowIndex,
                            routeOrdinal = row.routeOrdinal,
                            locationLabel = row.locationLabel or row.slotLabel or ("Row " .. tostring(row.rowIndex)),
                            code = row.invalidCode or "test_invalid",
                            message = row.invalidReason or row.message or "Test invalid",
                        }
                    end
                end
                return {
                    controlName = controlName,
                    valid = invalidRows[1] == nil,
                    invalidRows = invalidRows,
                    rows = snapshotRows,
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

local function attachSingleBiomeRouteContext(control, routeKey, biomeKey, opts)
    opts = opts or {}
    routeKey = routeKey or "TestRoute"
    biomeKey = biomeKey or control:biomeKey()
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = routeKey,
                label = opts.label or routeKey,
                biomes = { biomeKey },
            },
        }),
        biomes = opts.biomes or {},
        controlResolver = function(controlName)
            if controlName == control:name() then
                return control
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, routeKey)
    return routeContext
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
        rewardRowGroup = opts.rewardRowGroup,
        rewards = {
            "Major",
            "Devotion",
            "",
            "",
            opts.lootAName or "ZeusUpgrade",
            opts.lootBName or "ApolloUpgrade",
        },
    })
end

local function boonRewardRow(rowIndex, lootName, opts)
    opts = opts or {}
    return routeRewardRow(rowIndex, "Boon", {
        exitCount = opts.exitCount,
        rewards = { "Major", "Boon", lootName },
        rewardKind = "majorMinor",
        rewardRowGroup = opts.rewardRowGroup,
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

return {
    testImport = testImport,
    withTestImport = withTestImport,
    normalizeRewardRows = normalizeRewardRows,
    primaryRewardItem = primaryRewardItem,
    rewardItemBySource = rewardItemBySource,
    loadCatalog = loadCatalog,
    loadRouteDeps = loadRouteDeps,
    loadControlTemplates = loadControlTemplates,
    loadFixedLinearTemplate = loadFixedLinearTemplate,
    loadClockworkGoalTemplate = loadClockworkGoalTemplate,
    loadHubPylonTemplate = loadHubPylonTemplate,
    loadMultiEncounterTemplate = loadMultiEncounterTemplate,
    loadFieldsCageTemplate = loadFieldsCageTemplate,
    loadRouteGlobalTemplate = loadRouteGlobalTemplate,
    loadRouteNpcsTemplate = loadRouteNpcsTemplate,
    loadRouteFeaturesTemplate = loadRouteFeaturesTemplate,
    loadRewardLegality = loadRewardLegality,
    loadRouteTargets = loadRouteTargets,
    loadFixedLinearData = loadFixedLinearData,
    loadClockworkGoalData = loadClockworkGoalData,
    loadHubPylonData = loadHubPylonData,
    loadMultiEncounterData = loadMultiEncounterData,
    loadFieldsCageData = loadFieldsCageData,
    loadRunContext = loadRunContext,
    routeDefinitions = routeDefinitions,
    hasValue = hasValue,
    optionByKey = optionByKey,
    fakeRows = fakeRows,
    routeFields = routeFields,
    npcFields = npcFields,
    fakeUiRows = fakeUiRows,
    fakePackedField = fakePackedField,
    fakeStringField = fakeStringField,
    fakeBoolField = fakeBoolField,
    routeUiFields = routeUiFields,
    noOpDraw = noOpDraw,
    createUiControl = createUiControl,
    measureAllocKb = measureAllocKb,
    measureCpuMs = measureCpuMs,
    buildThessalyRuntime = buildThessalyRuntime,
    routeRewardRow = routeRewardRow,
    fakeRouteControlSnapshot = fakeRouteControlSnapshot,
rewardLegalityRouteContext = rewardLegalityRouteContext,
attachSingleBiomeRouteContext = attachSingleBiomeRouteContext,
fakeTimelineBiome = fakeTimelineBiome,
    devotionRewardRow = devotionRewardRow,
    boonRewardRow = boonRewardRow,
    firstValidDevotionRows = firstValidDevotionRows,
}
