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

local function completeGState()
    return {
        layoutKind = "LinearBiome",
        batches = {
            { parentRoomControlKey = "Underworld_G_Intro" },
            { parentRoomControlKey = "Underworld_G_Combat02" },
        },
        targets = {
            {
                parentRoomControlKey = "Underworld_G_Intro",
                exitIndex = 1,
                roomControlKey = "Underworld_G_Combat02",
                picked = true,
            },
            {
                parentRoomControlKey = "Underworld_G_Combat02",
                exitIndex = 1,
                roomControlKey = "Underworld_G_Combat03",
                picked = true,
            },
            {
                parentRoomControlKey = "Underworld_G_Combat02",
                exitIndex = 2,
                roomControlKey = "Underworld_G_Combat04",
                picked = false,
            },
            {
                parentRoomControlKey = "Underworld_G_Combat02",
                exitIndex = 3,
                roomControlKey = "Underworld_G_Combat05",
                picked = false,
            },
        },
        terminalTransition = {
            parentRoomControlKey = "Underworld_G_Combat03",
        },
    }
end

local function directAccess(state)
    local function copyRows(rows)
        local result = {}
        for index, row in ipairs(rows or {}) do
            local copy = {}
            for key, value in pairs(row) do
                copy[key] = value
            end
            result[index] = copy
        end
        return result
    end
    return {
        readScalar = function(_, root)
            if string.find(root.alias, "SelectedStart", 1, true) then
                return state.selectedStartRoomControlKey
            end
            if string.find(root.alias, "TerminalParent", 1, true) then
                return state.terminalTransition.parentRoomControlKey
            end
            return state[root.semanticKey]
        end,
        readRows = function(_, root)
            if string.find(root.alias, "CompanionTargets", 1, true) then
                return copyRows(state.terminalTransition.companionTargets)
            end
            if string.find(root.alias, "_Batches", 1, true) then
                return copyRows(state.batches)
            end
            return copyRows(state.targets)
        end,
    }
end

local function stateAdaptersFor(systems, biomeStepKey, state)
    local values = {}
    local tables = {}
    for _, descriptor in ipairs(systems.route.storage.moduleStorage) do
        if descriptor.type == "table" then
            tables[descriptor.alias] = {}
        else
            values[descriptor.alias] = descriptor.default
        end
    end
    local descriptor = systems.route.storage.biomes.lookup[biomeStepKey]
    if descriptor.selectedStart ~= nil then
        values[descriptor.selectedStart.alias] = state.selectedStartRoomControlKey
    end
    values[descriptor.terminalTransition.alias] = state.terminalTransition.parentRoomControlKey
    for index, batch in ipairs(state.batches) do
        local row = {}
        for semanticKey, physicalKey in pairs(descriptor.batches.columns) do
            row[physicalKey] = batch[semanticKey]
        end
        tables[descriptor.batches.alias][index] = row
    end
    for index, target in ipairs(state.targets) do
        local row = {}
        for semanticKey, physicalKey in pairs(descriptor.targets.columns) do
            row[physicalKey] = target[semanticKey]
        end
        tables[descriptor.targets.alias][index] = row
    end
    if descriptor.companionTargets ~= nil then
        for index, target in ipairs(state.terminalTransition.companionTargets or {}) do
            local row = {}
            for semanticKey, physicalKey in pairs(descriptor.companionTargets.columns) do
                row[physicalKey] = target[semanticKey]
            end
            tables[descriptor.companionTargets.alias][index] = row
        end
    end

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
                clear = function()
                    for index = #rows, 1, -1 do
                        rows[index] = nil
                    end
                end,
                append = function(_, row)
                    rows[#rows + 1] = row
                end,
            }
        end
        return {
            write = function(_, value)
                values[alias] = value
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
    return runtime, ui, { values = values, tables = tables }
end


local function stateAdapters(systems, state)
    return stateAdaptersFor(systems, "Underworld_F", state)
end

function TestBiomePlan.testComposesExecutableRegistriesAndLongLivedPlans()
    h.withImport(function()
        local systems = load()
        lu.assertIsFunction(systems.route.topologyLayouts.LinearBiome.readTopology)
        lu.assertIsFunction(systems.route.topologyLayouts.LinearBiome.checkStructure)
        lu.assertIsFunction(systems.route.topologyLayouts.LinearBiome.traverse)
        lu.assertIsFunction(systems.route.topologyLayouts.LinearBiome.semanticAddress)
        lu.assertIsFunction(systems.route.batchImplementations.Standard.normalize)
        lu.assertIsFunction(systems.route.batchImplementations.Standard.checkStructure)
        lu.assertIsFunction(systems.route.terminalTransitions.PrebossEntry.normalize)
        lu.assertIsFunction(systems.route.terminalTransitions.PrebossEntry.checkStructure)
        lu.assertEquals(#systems.route.biomePlans.ordered, 4)
        lu.assertEquals(systems.route.biomePlans.unavailable.Underworld_H, "LinearBiome")
        lu.assertEquals(systems.route.biomePlans.unavailable.Underworld_I, "LinearBiome")
        lu.assertEquals(systems.route.biomePlans.unavailable.Surface_N, "HubBiome")
        lu.assertEquals(systems.route.biomePlans.unavailable.Surface_Q, "LinearBiome")
        local plan = systems.route.biomePlans.lookup.Underworld_F
        lu.assertEquals(plan.key, "Underworld_F")
        lu.assertEquals(plan.layoutKind, "LinearBiome")
        lu.assertEquals(systems.route.capabilityEvidence.topology, {
            Underworld_F = true,
            Underworld_G = true,
        })
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
            topologyCapabilityBiomeSteps = {},
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
        lu.assertEquals(result.capabilityEvidence.topology, {})
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

local function collectTraversal(plan, topology)
    local visits = {}
    plan:traverse(topology, {
        visit = function(_, subject, address)
            visits[#visits + 1] = { subject = subject, address = address }
        end,
    })
    return visits
end

function TestBiomePlan.testChecksAndTraversesCompleteFTopologyThroughUiAndRuntimeAccess()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local runtime, ui = stateAdapters(systems, completeFState())
        local runtimeTopology = plan:readTopology(runtime)
        local uiTopology = plan:readTopology(ui)

        lu.assertEquals(plan:checkStructure(runtimeTopology), {})
        lu.assertEquals(plan:checkStructure(uiTopology), {})
        local runtimeVisits = collectTraversal(plan, runtimeTopology)
        local uiVisits = collectTraversal(plan, uiTopology)
        lu.assertEquals(uiVisits, runtimeVisits)
        lu.assertEquals({
            runtimeVisits[1].subject.kind,
            runtimeVisits[2].subject.kind,
            runtimeVisits[3].subject.kind,
            runtimeVisits[4].subject.kind,
            runtimeVisits[5].subject.kind,
            runtimeVisits[6].subject.kind,
            runtimeVisits[7].subject.kind,
        }, {
            "start",
            "batch",
            "batchTarget",
            "batch",
            "batchTarget",
            "batchTarget",
            "terminalTransition",
        })
        lu.assertEquals(runtimeVisits[1].subject.roomControlKey, "Underworld_F_Opening02")
        lu.assertEquals(runtimeVisits[3].subject, {
            kind = "batchTarget",
            parentRoomControlKey = "Underworld_F_Opening02",
            batchRuleKey = "Standard",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat03",
            picked = true,
        })
        lu.assertEquals(runtimeVisits[6].subject.roomControlKey, "Underworld_F_Combat05")
        lu.assertFalse(runtimeVisits[6].subject.picked)
        lu.assertEquals(runtimeVisits[7].subject.terminalRoomControlKey,
            "Underworld_F_PreBoss01")
    end)
end

function TestBiomePlan.testUsesStableSemanticAddressesForLinearOwners()
    h.withImport(function()
        local plan = load().route.biomePlans.lookup.Underworld_F
        lu.assertEquals(plan:semanticAddress({
            kind = "batchTarget",
            parentRoomControlKey = "Underworld_F_Combat03",
            exitIndex = 2,
        }), {
            routeKey = "Underworld",
            biomeStepKey = "Underworld_F",
            ownerKind = "batchTarget",
            ownerKey = "Underworld_F_Combat03",
            parentRoomControlKey = "Underworld_F_Combat03",
            batchKey = "nextDoors",
            exitIndex = 2,
            aspect = "targetRoom",
        })
        lu.assertEquals(plan:semanticAddress({
            kind = "terminalTransition",
            parentRoomControlKey = "Underworld_F_Combat04",
        }), {
            routeKey = "Underworld",
            biomeStepKey = "Underworld_F",
            ownerKind = "terminalTransition",
            ownerKey = "Underworld_F_Combat04",
            parentRoomControlKey = "Underworld_F_Combat04",
            transitionKey = "prebossEntry",
            aspect = "continuation",
        })
    end)
end

function TestBiomePlan.testReportsOwnerKeyedFStructuralIncompleteness()
    h.withImport(function()
        local plan = load().route.biomePlans.lookup.Underworld_F

        local topology = plan:readTopology(directAccess({
            layoutKind = "LinearBiome",
            selectedStartRoomControlKey = "",
            batches = {},
            targets = {},
            terminalTransition = { parentRoomControlKey = "" },
        }))
        lu.assertEquals(plan:checkStructure(topology), {
            {
                code = "start_room_required",
                severity = "incomplete",
                phase = "topology.structure",
                origin = {
                    routeKey = "Underworld",
                    biomeStepKey = "Underworld_F",
                    ownerKind = "layoutStart",
                    ownerKey = "start",
                    aspect = "startRoom",
                },
                providerKey = "startRoom",
                evidence = {},
            },
        })

        local missingTarget = completeFState()
        table.remove(missingTarget.targets, 2)
        topology = plan:readTopology(directAccess(missingTarget))
        local findings = plan:checkStructure(topology)
        lu.assertEquals(#findings, 1)
        lu.assertEquals(findings[1].code, "target_room_required")
        lu.assertEquals(findings[1].providerKey, "targetRoom")
        lu.assertEquals(findings[1].origin.parentRoomControlKey,
            "Underworld_F_Combat03")
        lu.assertEquals(findings[1].origin.exitIndex, 2)
        lu.assertEquals(findings[1].evidence, {
            requiredTargetCount = 2,
            actualTargetCount = 1,
        })

        local missingPicked = completeFState()
        missingPicked.batches = { missingPicked.batches[1] }
        missingPicked.targets = { missingPicked.targets[1] }
        missingPicked.targets[1].picked = false
        missingPicked.terminalTransition.parentRoomControlKey = ""
        topology = plan:readTopology(directAccess(missingPicked))
        findings = plan:checkStructure(topology)
        lu.assertEquals(#findings, 1)
        lu.assertEquals(findings[1].code, "picked_target_required")
        lu.assertEquals(findings[1].origin.ownerKind, "batch")
        lu.assertEquals(findings[1].origin.parentRoomControlKey,
            "Underworld_F_Opening02")
        lu.assertErrorMsgContains("cannot traverse incomplete topology", function()
            collectTraversal(plan, topology)
        end)

        local missingContinuation = completeFState()
        missingContinuation.terminalTransition.parentRoomControlKey = ""
        topology = plan:readTopology(directAccess(missingContinuation))
        findings = plan:checkStructure(topology)
        lu.assertEquals(#findings, 1)
        lu.assertEquals(findings[1].code, "continuation_required")
        lu.assertEquals(findings[1].origin.ownerKind, "continuation")
        lu.assertEquals(findings[1].origin.parentRoomControlKey,
            "Underworld_F_Combat04")
    end)
end

function TestBiomePlan.testTreatsMissingTerminalCompanionsAsIncomplete()
    h.withImport(function()
        local implementation = h.testImport("mods/route/transitions/preboss_entry.lua")
        local parent = {
            control = { key = "Underworld_I_Combat12" },
            room = { exits = { {}, {}, {} } },
        }
        local transition = implementation.normalize({
            companionTargets = {
                { exitIndex = 3, roomControlKey = "Underworld_I_Combat14" },
            },
            declaration = {
                transitionRuleKey = "PrebossEntry",
                exitPolicy = {
                    kind = "terminalWithCompanions",
                    companionBatchRuleKey = "ClockworkDoorBatch",
                },
            },
            fail = function(path, message)
                error(path .. ": " .. message, 0)
            end,
            parent = parent,
            path = "terminalTransition",
            terminal = { control = { key = "Underworld_I_PreBoss02" } },
        })
        local missing = {}
        implementation.checkStructure({
            transition = transition,
            parent = parent,
            reportMissingCompanion = function(exitIndex)
                missing[#missing + 1] = exitIndex
            end,
        })
        lu.assertEquals(missing, { 2 })

        lu.assertErrorMsgContains("must use physical exits 2..N", function()
            implementation.normalize({
                companionTargets = {
                    { exitIndex = 1, roomControlKey = "Underworld_I_Combat14" },
                },
                declaration = {
                    transitionRuleKey = "PrebossEntry",
                    exitPolicy = {
                        kind = "terminalWithCompanions",
                        companionBatchRuleKey = "ClockworkDoorBatch",
                    },
                },
                fail = function(path, message)
                    error(path .. ": " .. message, 0)
                end,
                parent = parent,
                path = "terminalTransition",
                terminal = { control = { key = "Underworld_I_PreBoss02" } },
            })
        end)
    end)
end

function TestBiomePlan.testBuildsCompleteFTopologyThroughUiOnlyCommands()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local runtime, ui = stateAdapters(systems, {
            layoutKind = "LinearBiome",
            selectedStartRoomControlKey = "",
            batches = {},
            targets = {},
            terminalTransition = { parentRoomControlKey = "" },
        })
        lu.assertNil(runtime.replaceBiomeTopology)
        lu.assertErrorMsgContains("mutation requires UiStateAccess", function()
            plan:apply(runtime, {
                kind = "SelectStart",
                roomControlKey = "Underworld_F_Opening02",
            })
        end)

        plan:apply(ui, {
            kind = "SelectStart",
            roomControlKey = "Underworld_F_Opening02",
        })
        plan:apply(ui, {
            kind = "CreateBatch",
            parentRoomControlKey = "Underworld_F_Opening02",
        })
        plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Opening02",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat03",
        })
        plan:apply(ui, {
            kind = "SetPicked",
            parentRoomControlKey = "Underworld_F_Opening02",
            exitIndex = 1,
        })
        plan:apply(ui, {
            kind = "CreateBatch",
            parentRoomControlKey = "Underworld_F_Combat03",
        })
        plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Combat03",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat04",
        })
        plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Combat03",
            exitIndex = 2,
            roomControlKey = "Underworld_F_Combat05",
        })
        plan:apply(ui, {
            kind = "SetPicked",
            parentRoomControlKey = "Underworld_F_Combat03",
            exitIndex = 1,
        })
        local topology = plan:apply(ui, {
            kind = "CreateTerminalTransition",
            parentRoomControlKey = "Underworld_F_Combat04",
        })

        lu.assertEquals(plan:checkStructure(topology), {})
        lu.assertEquals(plan:readTopology(runtime), topology)
        lu.assertEquals(#collectTraversal(plan, topology), 7)
    end)
end

function TestBiomePlan.testChangingSelectedFLinksReanchorsDownstreamTopology()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local _, ui = stateAdapters(systems, completeFState())

        local topology = plan:apply(ui, {
            kind = "SetPicked",
            parentRoomControlKey = "Underworld_F_Combat03",
            exitIndex = 2,
        })
        lu.assertEquals(
            topology.terminalTransition.parentRoomControlKey,
            "Underworld_F_Combat05"
        )
        lu.assertEquals(topology.batches[2].targets, {
            {
                exitIndex = 1,
                roomControlKey = "Underworld_F_Combat04",
                picked = false,
            },
            {
                exitIndex = 2,
                roomControlKey = "Underworld_F_Combat05",
                picked = true,
            },
        })

        local replacementRuntime, replacementUi = stateAdapters(systems, completeFState())
        topology = plan:apply(replacementUi, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Combat03",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat06",
        })
        lu.assertEquals(#topology.batches, 2)
        lu.assertEquals(topology.batches[2].targets[1].roomControlKey,
            "Underworld_F_Combat06")
        lu.assertTrue(topology.batches[2].targets[1].picked)
        lu.assertEquals(
            topology.terminalTransition.parentRoomControlKey,
            "Underworld_F_Combat06"
        )

        topology = plan:apply(replacementUi, {
            kind = "SelectStart",
            roomControlKey = "Underworld_F_Opening03",
        })
        lu.assertEquals(topology.startRoomControlKey, "Underworld_F_Opening03")
        lu.assertEquals(#topology.batches, 2)
        lu.assertEquals(
            topology.batches[1].parentRoomControlKey,
            "Underworld_F_Opening03"
        )
        lu.assertEquals(
            topology.terminalTransition.parentRoomControlKey,
            "Underworld_F_Combat06"
        )

        topology = plan:clearTopology(replacementUi)
        lu.assertNil(topology.startRoomControlKey)
        lu.assertEquals(topology.batches, {})
        lu.assertEquals(plan:readTopology(replacementRuntime), topology)
    end)
end

function TestBiomePlan.testRetainsUnavailableTargetsUntilExplicitReconciliation()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local state = completeFState()
        state.targets[2].picked = true
        state.targets[3].picked = false
        state.terminalTransition.parentRoomControlKey = "Underworld_F_Combat05"
        local runtime, ui = stateAdapters(systems, state)

        local topology = plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Opening02",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat01",
        })
        lu.assertEquals(topology.batches[2].parentRoomControlKey,
            "Underworld_F_Combat01")
        lu.assertEquals(#topology.batches[2].targets, 2)
        lu.assertTrue(topology.batches[2].targets[2].picked)
        lu.assertEquals(topology.terminalTransition.parentRoomControlKey,
            "Underworld_F_Combat05")

        local findings = plan:checkStructure(topology)
        lu.assertEquals({ findings[1].code, findings[2].code }, {
            "target_exit_unavailable",
            "picked_target_required",
        })
        lu.assertEquals(findings[1].origin.exitIndex, 2)
        lu.assertEquals(findings[1].evidence, {
            availableExitCount = 1,
            picked = true,
        })
        lu.assertErrorMsgContains("cannot traverse incomplete topology", function()
            collectTraversal(plan, topology)
        end)

        lu.assertErrorMsgContains("pick an available target", function()
            plan:apply(ui, {
                kind = "ReconcileExitCapacity",
                parentRoomControlKey = "Underworld_F_Combat01",
            })
        end)
        lu.assertEquals(plan:readTopology(runtime), topology)

        topology = plan:apply(ui, {
            kind = "SetPicked",
            parentRoomControlKey = "Underworld_F_Combat01",
            exitIndex = 1,
        })
        lu.assertTrue(topology.batches[2].targets[1].picked)
        lu.assertFalse(topology.batches[2].targets[2].picked)
        lu.assertEquals(topology.terminalTransition.parentRoomControlKey,
            "Underworld_F_Combat04")

        topology = plan:apply(ui, {
            kind = "ReconcileExitCapacity",
            parentRoomControlKey = "Underworld_F_Combat01",
        })
        lu.assertEquals(#topology.batches[2].targets, 1)
        lu.assertEquals(plan:checkStructure(topology), {})
        lu.assertEquals(plan:readTopology(runtime), topology)

        topology = plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Opening02",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat03",
        })
        lu.assertEquals(#topology.batches[2].targets, 1)
        local expandedFindings = plan:checkStructure(topology)
        lu.assertEquals(#expandedFindings, 1)
        lu.assertEquals(expandedFindings[1].code, "target_room_required")
        lu.assertEquals(expandedFindings[1].origin.exitIndex, 2)
    end)
end

function TestBiomePlan.testReactivatesRetainedTargetsWhenExitCapacityReturns()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local _, ui = stateAdapters(systems, completeFState())

        local topology = plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Opening02",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat01",
        })
        lu.assertEquals(plan:checkStructure(topology)[1].code,
            "target_exit_unavailable")

        topology = plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Opening02",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat03",
        })
        lu.assertEquals(#topology.batches[2].targets, 2)
        lu.assertEquals(topology.batches[2].targets[2].roomControlKey,
            "Underworld_F_Combat05")
        lu.assertEquals(plan:checkStructure(topology), {})
    end)
end

function TestBiomePlan.testSpecifiedTargetsCanOnlyBeReplacedOrRemovedWithDecision()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local _, ui = stateAdapters(systems, completeFState())

        lu.assertErrorMsgContains("unknown LinearBiome command 'RemoveTarget'", function()
            plan:apply(ui, {
                kind = "RemoveTarget",
                parentRoomControlKey = "Underworld_F_Combat03",
                exitIndex = 2,
            })
        end)

        local topology = plan:apply(ui, {
            kind = "RemoveBatch",
            parentRoomControlKey = "Underworld_F_Combat03",
        })
        lu.assertEquals(#topology.batches, 1)
        lu.assertEquals(topology.batches[1].targets, {
            {
                exitIndex = 1,
                roomControlKey = "Underworld_F_Combat03",
                picked = true,
            },
        })
        lu.assertNil(topology.terminalTransition)
    end)
end

function TestBiomePlan.testContinuationReplacementIsExplicitAndAtomic()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local runtime, ui = stateAdapters(systems, completeFState())
        local before = plan:readTopology(runtime)

        lu.assertErrorMsgContains("terminal transition must be replaced explicitly", function()
            plan:apply(ui, {
                kind = "CreateBatch",
                parentRoomControlKey = "Underworld_F_Combat04",
            })
        end)
        lu.assertEquals(plan:readTopology(runtime), before)

        lu.assertErrorMsgContains("is already used", function()
            plan:apply(ui, {
                kind = "SetTarget",
                parentRoomControlKey = "Underworld_F_Combat03",
                exitIndex = 2,
                roomControlKey = "Underworld_F_Combat04",
            })
        end)
        lu.assertEquals(plan:readTopology(runtime), before)

        local topology = plan:apply(ui, {
            kind = "ReplaceWithBatch",
            parentRoomControlKey = "Underworld_F_Combat04",
        })
        lu.assertNil(topology.terminalTransition)
        lu.assertEquals(topology.batches[3], {
            parentRoomControlKey = "Underworld_F_Combat04",
            batchRuleKey = "Standard",
            targets = {},
        })
        lu.assertErrorMsgContains("generated batch must be replaced explicitly", function()
            plan:apply(ui, {
                kind = "CreateTerminalTransition",
                parentRoomControlKey = "Underworld_F_Combat04",
            })
        end)

        plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Combat04",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat06",
        })
        plan:apply(ui, {
            kind = "SetTarget",
            parentRoomControlKey = "Underworld_F_Combat04",
            exitIndex = 2,
            roomControlKey = "Underworld_F_Combat07",
        })
        plan:apply(ui, {
            kind = "SetPicked",
            parentRoomControlKey = "Underworld_F_Combat04",
            exitIndex = 1,
        })
        topology = plan:apply(ui, {
            kind = "ReplaceWithTerminalTransition",
            parentRoomControlKey = "Underworld_F_Combat04",
        })
        lu.assertEquals(#topology.batches, 2)
        lu.assertEquals(#topology.batches[2].targets, 2)
        lu.assertEquals(topology.terminalTransition.parentRoomControlKey,
            "Underworld_F_Combat04")

        topology = plan:apply(ui, { kind = "RemoveTerminalTransition" })
        lu.assertNil(topology.terminalTransition)
    end)
end

function TestBiomePlan.testTerminalCompanionCommandsRemainPolicyScoped()
    h.withImport(function()
        local commands = h.testImport("mods/route/topology/linear_biome_commands.lua")
        local authored = {
            layoutKind = "LinearBiome",
            batches = {},
            targets = {},
            terminalTransition = {
                parentRoomControlKey = "Underworld_I_Combat12",
                companionTargets = {
                    { exitIndex = 2, roomControlKey = "Underworld_I_Combat13" },
                },
            },
        }
        local function apply(value, command)
            return commands.apply({
                authored = value,
                command = command,
                fail = function(path, message)
                    error(path .. ": " .. message, 0)
                end,
                layout = {
                    start = { mode = "fixed" },
                    terminal = { exitPolicy = { kind = "terminalWithCompanions" } },
                },
                normalize = function()
                    return { batches = {} }
                end,
            })
        end

        authored = apply(authored, {
            kind = "SetTerminalCompanion",
            exitIndex = 3,
            roomControlKey = "Underworld_I_Combat14",
        })
        lu.assertEquals(authored.terminalTransition.companionTargets, {
            { exitIndex = 2, roomControlKey = "Underworld_I_Combat13" },
            { exitIndex = 3, roomControlKey = "Underworld_I_Combat14" },
        })
        authored = apply(authored, {
            kind = "SetTerminalCompanion",
            exitIndex = 2,
            roomControlKey = "Underworld_I_Combat15",
        })
        lu.assertEquals(authored.terminalTransition.companionTargets, {
            { exitIndex = 2, roomControlKey = "Underworld_I_Combat15" },
            { exitIndex = 3, roomControlKey = "Underworld_I_Combat14" },
        })
        lu.assertErrorMsgContains(
            "unknown LinearBiome command 'RemoveTerminalCompanion'",
            function()
                apply(authored, {
                    kind = "RemoveTerminalCompanion",
                    exitIndex = 2,
                })
            end
        )

        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local runtime, ui = stateAdapters(systems, completeFState())
        local before = plan:readTopology(runtime)
        lu.assertErrorMsgContains("does not admit companion targets", function()
            plan:apply(ui, {
                kind = "SetTerminalCompanion",
                exitIndex = 2,
                roomControlKey = "Underworld_F_Combat06",
            })
        end)
        lu.assertEquals(plan:readTopology(runtime), before)
    end)
end

function TestBiomePlan.testGUsesTheLinearTopologyContractWithFixedStartAndThreeExits()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_G
        local runtime, ui = stateAdaptersFor(systems, "Underworld_G", completeGState())
        local topology = plan:readTopology(runtime)

        lu.assertEquals(topology.startRoomControlKey, "Underworld_G_Intro")
        lu.assertEquals(#topology.batches[2].targets, 3)
        lu.assertEquals(plan:checkStructure(topology), {})
        lu.assertEquals(#collectTraversal(plan, topology), 8)

        local missingExit = completeGState()
        table.remove(missingExit.targets, 4)
        local missingRuntime = stateAdaptersFor(systems, "Underworld_G", missingExit)
        local findings = plan:checkStructure(plan:readTopology(missingRuntime))
        lu.assertEquals(#findings, 1)
        lu.assertEquals(findings[1].code, "target_room_required")
        lu.assertEquals(findings[1].origin.exitIndex, 3)

        local before = plan:readTopology(runtime)
        lu.assertErrorMsgContains("fixed-start topology does not admit SelectStart", function()
            plan:apply(ui, {
                kind = "SelectStart",
                roomControlKey = "Underworld_G_Intro",
            })
        end)
        lu.assertEquals(plan:readTopology(runtime), before)

        topology = plan:apply(ui, {
            kind = "SetPicked",
            parentRoomControlKey = "Underworld_G_Combat02",
            exitIndex = 2,
        })
        lu.assertEquals(
            topology.terminalTransition.parentRoomControlKey,
            "Underworld_G_Combat04"
        )
        lu.assertFalse(topology.batches[2].targets[1].picked)
        lu.assertTrue(topology.batches[2].targets[2].picked)

        local replacementRuntime, replacementUi = stateAdaptersFor(
            systems,
            "Underworld_G",
            completeGState()
        )
        topology = plan:apply(replacementUi, {
            kind = "ReplaceWithBatch",
            parentRoomControlKey = "Underworld_G_Combat03",
        })
        lu.assertNil(topology.terminalTransition)
        lu.assertEquals(#topology.batches, 3)
        topology = plan:apply(replacementUi, {
            kind = "ReplaceWithTerminalTransition",
            parentRoomControlKey = "Underworld_G_Combat03",
        })
        lu.assertEquals(topology.terminalTransition.parentRoomControlKey,
            "Underworld_G_Combat03")

        topology = plan:clearTopology(replacementUi)
        lu.assertEquals(topology.startRoomControlKey, "Underworld_G_Intro")
        lu.assertEquals(topology.batches, {})
        lu.assertNil(topology.terminalTransition)
        lu.assertEquals(plan:readTopology(replacementRuntime), topology)
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
        state.targets[1].exitIndex = 3
        lu.assertErrorMsgContains("exceeds the biome physical-exit bound", function()
            plan:readTopology(directAccess(state))
        end)

        state = completeFState()
        state.targets[2].picked = true
        lu.assertErrorMsgContains("at most one picked target", function()
            plan:readTopology(directAccess(state))
        end)
    end)
end
