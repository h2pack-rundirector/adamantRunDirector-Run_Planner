local importHarness = require("tests.support.import_harness")
local testImport = importHarness.testImport
local withTestImport = importHarness.withTestImport

local function normalizeRewardRows(rows)
    for _, row in ipairs(rows or {}) do
        if row.biomeEncounterDepthCost == nil then
            row.biomeEncounterDepthCost = 1
        end
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
    return row
end

local function rewardItemByEventSource(row, eventSourceKind, sameExitRewardIndex)
    if eventSourceKind == "row" then
        return row
    elseif eventSourceKind == "side" then
        return row and row.sideRooms and row.sideRooms[sameExitRewardIndex] or nil
    elseif eventSourceKind == "encounter" then
        return row and row.encounterRewardLegs and row.encounterRewardLegs[sameExitRewardIndex] or nil
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

local function loadRouteDeps()
    local route
    withTestImport(function()
        local rewards = testImport("mods/rewards/rewards.lua").create({
            rewardDomain = loadRewardDomain(),
        })
        local valueStates = testImport("mods/ui/value_states.lua")
        local controlForm = testImport("mods/controls/form.lua", nil, {
            rewards = rewards,
            valueStates = valueStates,
        })
        route = {
            controlForm = controlForm,
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

local function addFormDeps(deps, routeDeps)
    local form = routeDeps.controlForm
    deps.common = form.common
    deps.readCache = form.readCache
    deps.rowData = form.rowData
    deps.valueStates = form.valueStates
    deps.slotTimeline = form.slots
end

local function addBiomeHelperDeps(deps, routeDeps)
    deps.roomStructure = testImport("mods/controls/biome_helpers/room_structure.lua")
    deps.roomTopology = testImport("mods/controls/biome_helpers/room_topology.lua", nil, {
        common = deps.common,
        roomStructure = deps.roomStructure,
        valueStates = deps.valueStates,
        form = routeDeps.controlForm,
    })
    deps.roomTopologyAdapter = testImport("mods/controls/biome_helpers/room_topology_adapter.lua", nil, {
        common = deps.common,
        readCache = deps.readCache,
        roomTopology = deps.roomTopology,
        roomStructure = deps.roomStructure,
        valueStates = deps.valueStates,
        form = routeDeps.controlForm,
    })
    deps.topologyControls = testImport("mods/controls/biome_helpers/topology_controls.lua", nil, {
        roomTopology = deps.roomTopology,
        roomTopologyAdapter = deps.roomTopologyAdapter,
    })
end

local function loadFixedLinearData()
    local routeDeps = loadRouteDeps()
    local deps = {}
    for key, value in pairs(routeDeps) do
        deps[key] = value
    end
    addFormDeps(deps, routeDeps)
    addBiomeHelperDeps(deps, routeDeps)
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
    addFormDeps(deps, routeDeps)
    addBiomeHelperDeps(deps, routeDeps)
    return withTestImport(function()
        return testImport("mods/controls/ClockworkGoalRoute/data/data.lua", nil, deps)
    end)
end

local function loadHubPylonData()
    local routeDeps = loadRouteDeps()
    local deps = {}
    for key, value in pairs(routeDeps) do
        deps[key] = value
    end
    addFormDeps(deps, routeDeps)
    return testImport("mods/controls/HubPylonRoute/data.lua", nil, deps)
end

local function loadMultiEncounterData()
    local routeDeps = loadRouteDeps()
    local deps = {}
    for key, value in pairs(routeDeps) do
        deps[key] = value
    end
    addFormDeps(deps, routeDeps)
    return testImport("mods/controls/MultiEncounterFixedRoute/data.lua", nil, deps)
end

local function loadFieldsCageDeps()
    local routeDeps = loadRouteDeps()
    local deps = {}
    for key, value in pairs(routeDeps) do
        deps[key] = value
    end
    addFormDeps(deps, routeDeps)
    addBiomeHelperDeps(deps, routeDeps)
    return deps
end

local function loadFieldsCageData()
    return withTestImport(function()
        return testImport("mods/controls/FieldsCageRoute/data/data.lua", nil, loadFieldsCageDeps())
    end)
end

local function loadRunContext(opts)
    opts = opts or {}
    local rewards = importHarness.loadRewards()
    local historySystem = opts.historySystem
        or withTestImport(function()
            return testImport("mods/route/history/assembly.lua").create({
                rewardDomain = rewards.rewardDomain,
                selectedLegalityRules = rewards.selectedLegalityRules,
            })
        end)
    return testImport("mods/route/run_context.lua", nil, {
        controls = testImport("mods/route/run_context/controls.lua"),
        historySystem = historySystem,
        horizon = testImport("mods/route/run_context/horizon.lua"),
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
        sameExitRewardCount = opts.sameExitRewardCount,
        invalidCode = opts.invalidCode,
        invalidReason = opts.invalidReason,
        invalidCompletion = opts.invalidCompletion,
        locationLabel = opts.locationLabel,
        rewardConstraints = opts.rewardConstraints,
        roomTopology = opts.roomTopology,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1,
    }
end

local function fakeRouteControlSnapshot(controlName, rows)
    local snapshotRows = normalizeRewardRows(rows or {})
    local function completionReport()
        local invalidRows = {}
        local completionInvalidRows = {}
        for _, row in ipairs(snapshotRows) do
            if row.valid == false then
                local invalidRow = {
                    rowIndex = row.rowIndex,
                    routeOrdinal = row.routeOrdinal,
                    locationLabel = row.locationLabel or row.slotLabel or ("Row " .. tostring(row.rowIndex)),
                    code = row.invalidCode or "test_invalid",
                    message = row.invalidReason or row.message or "Test invalid",
                }
                invalidRows[#invalidRows + 1] = invalidRow
                if row.invalidCompletion == true then
                    completionInvalidRows[#completionInvalidRows + 1] = invalidRow
                end
            end
        end
        return {
            controlName = controlName,
            valid = invalidRows[1] == nil,
            disabled = invalidRows[1] ~= nil,
            completionInvalidRows = completionInvalidRows,
        }
    end

    return {
        read = function(_, path)
            if path == "completion" then
                return completionReport()
            end
            return nil
        end,
        rowCount = function()
            return #snapshotRows
        end,
        rowSnapshot = function(_, rowIndex)
            return snapshotRows[rowIndex]
        end,
    }
end

local function attachSingleBiomeRouteContext(control, routeKey, biomeKey, opts)
    opts = opts or {}
    routeKey = routeKey or "TestRoute"
    biomeKey = biomeKey or control:biomeKey()
    local catalog = opts.biomes == nil and loadCatalog() or nil
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = routeKey,
                label = opts.label or routeKey,
                biomes = { biomeKey },
            },
        }),
        biomes = opts.biomes or catalog.lookup,
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
    rewardItemByEventSource = rewardItemByEventSource,
    loadCatalog = loadCatalog,
    loadRouteDeps = loadRouteDeps,
    loadControlTemplates = loadControlTemplates,
    loadFixedLinearTemplate = loadFixedLinearTemplate,
    loadClockworkGoalTemplate = loadClockworkGoalTemplate,
    loadHubPylonTemplate = loadHubPylonTemplate,
    loadMultiEncounterTemplate = loadMultiEncounterTemplate,
    loadFieldsCageTemplate = loadFieldsCageTemplate,
    loadRouteGlobalTemplate = loadRouteGlobalTemplate,
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
    attachSingleBiomeRouteContext = attachSingleBiomeRouteContext,
    fakeTimelineBiome = fakeTimelineBiome,
    devotionRewardRow = devotionRewardRow,
    boonRewardRow = boonRewardRow,
    firstValidDevotionRows = firstValidDevotionRows,
}
