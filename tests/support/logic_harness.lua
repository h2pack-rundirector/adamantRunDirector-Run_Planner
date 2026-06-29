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

local function loadCatalog()
    local data = dofile("src/mods/data.lua")
    local catalog
    withTestImport(function()
        catalog = data.loadCatalog(loadCatalogDeps())
    end)
    return catalog, data
end

local function loadRunState()
    return testImport("mods/logic/run_state.lua")
end

local loadedRewardConditions

local function loadRewardConditions()
    if loadedRewardConditions == nil then
        loadedRewardConditions = importHarness.loadRewardConditions()
    end
    return loadedRewardConditions
end

local function loadRewardLegality()
    local semantics = testImport("mods/route/reward_planning/semantics.lua")
    local invalidLocations = testImport("mods/route/invalid_locations.lua")
    local routeEvents = testImport("mods/route/events.lua")
    local routeHistory = testImport("mods/route/history.lua", nil, {
        events = routeEvents,
    })
    local routeQuery = testImport("mods/route/query.lua", nil, {
        events = routeEvents,
        history = routeHistory,
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

local function loadRoutePlan()
    local timeline = testImport("mods/route/timeline.lua")
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    local semantics = testImport("mods/route/reward_planning/semantics.lua")
    local runState = testImport("mods/logic/run_state.lua")
    local rewards = importHarness.loadRewards()
    local historySystem = withTestImport(function()
        return testImport("mods/route/history/assembly.lua").create({
            rewardDomain = rewards.rewardDomain,
            selectedLegalityRules = rewards.selectedLegalityRules,
        })
    end)
    return testImport("mods/logic/route_plan.lua", nil, {
        executionPlan = testImport("mods/logic/execution_plan.lua"),
        runState = runState,
        routeContext = testImport("mods/route/run_context.lua", nil, {
            controls = testImport("mods/route/run_context/controls.lua"),
            historySystem = historySystem,
            rewards = testImport("mods/route/run_context/rewards.lua", nil, {
                rewardLegality = loadRewardLegality(),
                rewardItems = rewardItems,
                semantics = semantics,
                timeline = timeline,
                valueStates = testImport("mods/route/value_states.lua"),
            }),
        }),
    })
end

local function loadRoomRouting(routePlan, game)
    return testImport("mods/logic/room_routing.lua", nil, {
        routePlan = routePlan,
        runState = testImport("mods/logic/run_state.lua"),
        game = game,
    })
end

local function loadRewardRouting(routePlan, game)
    return testImport("mods/logic/reward_routing.lua", nil, {
        routePlan = routePlan,
        runState = testImport("mods/logic/run_state.lua"),
        game = game,
    })
end

local function logsContain(logs, text)
    for _, line in ipairs(logs) do
        if line:find(text, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function availableDoorCount(predetermined, unavailable)
    local count = 0
    for doorId in pairs(predetermined or {}) do
        if unavailable == nil or unavailable[doorId] ~= true then
            count = count + 1
        end
    end
    return count
end

local function validBiomeSnapshot(biomeKey)
    return {
        controlName = "Route" .. biomeKey,
        biomeKey = biomeKey,
        valid = true,
        disabled = false,
        invalidRows = {},
        rows = {},
    }
end

local function plannedBiomeSnapshot(biomeKey, adapter, rows)
    return {
        controlName = "Route" .. biomeKey,
        biomeKey = biomeKey,
        adapter = adapter,
        valid = true,
        disabled = false,
        invalidRows = {},
        rows = normalizeRewardRows(rows),
    }
end

local function invalidBiomeSnapshot(biomeKey)
    return {
        controlName = "Route" .. biomeKey,
        biomeKey = biomeKey,
        adapter = "FixedLinearRoute",
        valid = false,
        disabled = true,
        invalidRows = {},
        rows = normalizeRewardRows({
            {
                rowIndex = 1,
                routeOrdinal = 1,
                slotKind = "biomeRow",
                roleKey = "MissingRole",
                roomKey = "MissingRoom",
            },
        }),
    }
end

local function routeGlobalControl()
    return {
        setRouteContext = function()
        end,
        isLayerConfigured = function(_, layer)
            return layer == "rewards"
        end,
    }
end

local function biomeControl(snapshot)
    return {
        setRouteContext = function()
        end,
        read = function(_, path)
            if path == "snapshot" then
                return snapshot
            end
            return nil
        end,
    }
end

local function buildControls(catalog, snapshots)
    local controlsByName = {
        RouteGlobalUnderworld = routeGlobalControl(),
        RouteGlobalSurface = routeGlobalControl(),
    }

    for _, biome in ipairs(catalog.ordered or {}) do
        local snapshot = snapshots[biome.key] or validBiomeSnapshot(biome.key)
        normalizeRewardRows(snapshot.rows)
        controlsByName["Route" .. biome.key] = biomeControl(snapshot)
    end

    return {
        get = function(controlName)
            return controlsByName[controlName]
        end,
    }
end

local function runtimeWithControls(routePlan, controls)
    local state
    local runtime = {
        controls = controls,
        data = {
            cache = {
                currentRun = {
                    get = function(cacheName)
                        if cacheName ~= routePlan.cacheName() then
                            return nil
                        end
                        state = state or {}
                        return state
                    end,
                },
            },
        },
    }
    return runtime
end

local function runtimeForCatalog(routePlan, catalog, snapshots)
    return runtimeWithControls(routePlan, buildControls(catalog, snapshots or {}))
end

local function withCurrentRun(currentRun, callback)
    local previous = _G.CurrentRun
    _G.CurrentRun = currentRun
    local ok, result = pcall(callback)
    _G.CurrentRun = previous
    if not ok then
        error(result, 0)
    end
    return result
end

return {
    testImport = testImport,
    withTestImport = withTestImport,
    normalizeRewardRows = normalizeRewardRows,
    primaryRewardItem = primaryRewardItem,
    loadCatalog = loadCatalog,
    loadRunState = loadRunState,
    loadRewardLegality = loadRewardLegality,
    loadRoutePlan = loadRoutePlan,
    loadRoomRouting = loadRoomRouting,
    loadRewardRouting = loadRewardRouting,
    logsContain = logsContain,
    availableDoorCount = availableDoorCount,
    validBiomeSnapshot = validBiomeSnapshot,
    plannedBiomeSnapshot = plannedBiomeSnapshot,
    invalidBiomeSnapshot = invalidBiomeSnapshot,
    routeGlobalControl = routeGlobalControl,
    biomeControl = biomeControl,
    buildControls = buildControls,
    runtimeWithControls = runtimeWithControls,
    runtimeForCatalog = runtimeForCatalog,
    withCurrentRun = withCurrentRun,
}
