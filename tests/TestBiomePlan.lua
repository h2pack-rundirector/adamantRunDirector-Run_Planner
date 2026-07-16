-- luacheck: globals TestBiomePlan

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestBiomePlan = {}

local function load()
    return h.testImport("mods/systems.lua").create()
end

local function completeFState()
    return {
        layoutKind = "LinearBiome",
        selectedStartRoomControlKey = "Underworld_F_Opening02",
        batches = {
            { parentRoomControlKey = "Underworld_F_Opening02" },
            { parentRoomControlKey = "Underworld_F_Combat03" },
        },
        targets = {
            {
                parentRoomControlKey = "Underworld_F_Opening02",
                exitIndex = 1,
                roomControlKey = "Underworld_F_Combat03",
                picked = true,
            },
            {
                parentRoomControlKey = "Underworld_F_Combat03",
                exitIndex = 2,
                roomControlKey = "Underworld_F_Combat05",
                picked = false,
            },
            {
                parentRoomControlKey = "Underworld_F_Combat03",
                exitIndex = 1,
                roomControlKey = "Underworld_F_Combat04",
                picked = true,
            },
        },
        terminalTransition = {
            parentRoomControlKey = "Underworld_F_Combat04",
        },
    }
end

local function directAccess(state)
    return {
        readBiome = function(_, biomeStepKey)
            lu.assertEquals(biomeStepKey, "Underworld_F")
            return state
        end,
    }
end

local function stateAdapters(systems, state)
    local values = {}
    local tables = {}
    for _, descriptor in ipairs(systems.route.storage.moduleStorage) do
        if descriptor.type == "table" then
            tables[descriptor.alias] = {}
        else
            values[descriptor.alias] = descriptor.default
        end
    end
    values.Underworld_F_SelectedStartRoomControlKey = state.selectedStartRoomControlKey
    values.Underworld_F_TerminalParentRoomControlKey =
        state.terminalTransition.parentRoomControlKey
    for index, batch in ipairs(state.batches) do
        tables.Underworld_F_Batches[index] = {
            ParentRoomControlKey = batch.parentRoomControlKey,
        }
    end
    for index, target in ipairs(state.targets) do
        tables.Underworld_F_Targets[index] = {
            ParentRoomControlKey = target.parentRoomControlKey,
            ExitIndex = target.exitIndex,
            RoomControlKey = target.roomControlKey,
            Picked = target.picked,
        }
    end

    local data = {}
    function data.read(alias)
        return values[alias]
    end
    function data.get(alias)
        local rows = tables[alias]
        return {
            count = function()
                return #rows
            end,
            read = function(_, rowIndex, column)
                return rows[rowIndex][column]
            end,
        }
    end
    local common = {
        controls = {},
        data = data,
    }
    local runtime = systems.route.stateAccess.createRuntime(
        common,
        systems.catalog,
        systems.route.storage
    )
    local ui = systems.route.stateAccess.createUi({
        controls = {},
        data = data,
        resetAll = function() end,
    }, systems.catalog, systems.route.storage)
    return runtime, ui
end

function TestBiomePlan.testComposesExecutableRegistriesAndLongLivedPlans()
    h.withImport(function()
        local systems = load()
        lu.assertIsFunction(systems.route.topologyLayouts.LinearBiome.readTopology)
        lu.assertIsFunction(systems.route.batchImplementations.Standard.normalize)
        lu.assertIsFunction(systems.route.terminalTransitions.PrebossEntry.normalize)
        lu.assertEquals(#systems.route.biomePlans.ordered, 4)
        lu.assertEquals(systems.route.biomePlans.unavailable.Underworld_H, "LinearBiome")
        lu.assertEquals(systems.route.biomePlans.unavailable.Underworld_I, "LinearBiome")
        lu.assertEquals(systems.route.biomePlans.unavailable.Surface_N, "HubBiome")
        lu.assertEquals(systems.route.biomePlans.unavailable.Surface_Q, "LinearBiome")
        local plan = systems.route.biomePlans.lookup.Underworld_F
        lu.assertEquals(plan.key, "Underworld_F")
        lu.assertEquals(plan.layoutKind, "LinearBiome")
    end)
end

function TestBiomePlan.testRouteAssemblyPreservesInjectedRegistryBoundaries()
    h.withImport(function()
        local catalog = { key = "catalog" }
        local storage = { key = "storage" }
        local stateAccess = { key = "state access" }
        local batchImplementations = { Standard = { key = "batch" } }
        local terminalTransitions = { PrebossEntry = { key = "transition" } }
        local topologyLayouts = { LinearBiome = { key = "topology" } }
        local plans = { key = "plans" }
        local captured = {}
        local assembly = h.testImport("mods/route/assembly.lua", nil, {
            storageManifest = {
                build = function(value)
                    captured.storageCatalog = value
                    return storage
                end,
            },
            stateAccess = stateAccess,
            standardBatch = {},
            prebossEntry = {},
            biomePlan = {},
            biomePlans = {
                build = function(catalogValue, storageValue, layoutsValue)
                    captured.planArgs = { catalogValue, storageValue, layoutsValue }
                    return plans
                end,
            },
            batchImplementations = batchImplementations,
            terminalTransitions = terminalTransitions,
            topologyLayouts = topologyLayouts,
        })

        local result = assembly.create(catalog)
        lu.assertIs(captured.storageCatalog, catalog)
        lu.assertEquals(captured.planArgs, { catalog, storage, topologyLayouts })
        lu.assertIs(result.storage, storage)
        lu.assertIs(result.stateAccess, stateAccess)
        lu.assertIs(result.batchImplementations, batchImplementations)
        lu.assertIs(result.terminalTransitions, terminalTransitions)
        lu.assertIs(result.topologyLayouts, topologyLayouts)
        lu.assertIs(result.biomePlans, plans)
    end)
end

function TestBiomePlan.testReadsIncompleteButWellFormedFTopology()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        lu.assertEquals(plan:readTopology(directAccess({
            layoutKind = "LinearBiome",
            selectedStartRoomControlKey = "",
            batches = {},
            targets = {},
            terminalTransition = { parentRoomControlKey = "" },
        })), {
            biomeStepKey = "Underworld_F",
            layoutKind = "LinearBiome",
            biomeState = {},
            batches = {},
        })

        local incomplete = completeFState()
        incomplete.batches = { incomplete.batches[1] }
        incomplete.targets = { incomplete.targets[1] }
        incomplete.targets[1].picked = false
        incomplete.terminalTransition.parentRoomControlKey = ""
        local topology = plan:readTopology(directAccess(incomplete))
        lu.assertEquals(#topology.batches, 1)
        lu.assertFalse(topology.batches[1].targets[1].picked)
        lu.assertNil(topology.terminalTransition)
    end)
end

function TestBiomePlan.testNormalizesCompleteFTopologyThroughUiAndRuntimeAccess()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local runtime, ui = stateAdapters(systems, completeFState())
        local runtimeTopology = plan:readTopology(runtime)
        local uiTopology = plan:readTopology(ui)

        lu.assertEquals(uiTopology, runtimeTopology)
        lu.assertEquals(runtimeTopology, {
            biomeStepKey = "Underworld_F",
            layoutKind = "LinearBiome",
            startRoomControlKey = "Underworld_F_Opening02",
            biomeState = {},
            batches = {
                {
                    parentRoomControlKey = "Underworld_F_Opening02",
                    batchRuleKey = "Standard",
                    targets = {
                        {
                            exitIndex = 1,
                            roomControlKey = "Underworld_F_Combat03",
                            picked = true,
                        },
                    },
                },
                {
                    parentRoomControlKey = "Underworld_F_Combat03",
                    batchRuleKey = "Standard",
                    targets = {
                        {
                            exitIndex = 1,
                            roomControlKey = "Underworld_F_Combat04",
                            picked = true,
                        },
                        {
                            exitIndex = 2,
                            roomControlKey = "Underworld_F_Combat05",
                            picked = false,
                        },
                    },
                },
            },
            terminalTransition = {
                parentRoomControlKey = "Underworld_F_Combat04",
                transitionRuleKey = "PrebossEntry",
                exitPolicyKind = "allExitsTerminal",
                terminalRoomControlKey = "Underworld_F_PreBoss01",
                companionTargets = {},
            },
        })
        lu.assertNil(runtimeTopology.batches[1].targets[1].roomState)
        lu.assertNil(runtimeTopology.batches[1].targets[1].incomingReward)
    end)
end

function TestBiomePlan.testRejectsMalformedFTopologyAtContactBoundary()
    h.withImport(function()
        local plan = load().route.biomePlans.lookup.Underworld_F

        local state = completeFState()
        state.targets[1].roomControlKey = "Surface_O_Combat01"
        lu.assertErrorMsgContains("unknown or cross-biome Room Control", function()
            plan:readTopology(directAccess(state))
        end)

        state = completeFState()
        state.targets[3].roomControlKey = "Underworld_F_Combat03"
        lu.assertErrorMsgContains("is already used", function()
            plan:readTopology(directAccess(state))
        end)

        state = completeFState()
        state.batches[3] = { parentRoomControlKey = "Underworld_F_Combat05" }
        lu.assertErrorMsgContains("not on the selected spine", function()
            plan:readTopology(directAccess(state))
        end)

        state = completeFState()
        state.terminalTransition.parentRoomControlKey = "Underworld_F_Combat05"
        lu.assertErrorMsgContains("terminal predecessor is not on the selected spine", function()
            plan:readTopology(directAccess(state))
        end)

        state = completeFState()
        state.batches[3] = { parentRoomControlKey = "Underworld_F_Combat04" }
        lu.assertErrorMsgContains("owns both a generated batch and terminal transition", function()
            plan:readTopology(directAccess(state))
        end)

        state = completeFState()
        state.targets[1].exitIndex = 2
        lu.assertErrorMsgContains("exit index is outside the parent room", function()
            plan:readTopology(directAccess(state))
        end)

        state = completeFState()
        state.targets[2].picked = true
        lu.assertErrorMsgContains("at most one picked target", function()
            plan:readTopology(directAccess(state))
        end)
    end)
end
