local lu = require("luaunit")

-- luacheck: globals TestRunPlannerLogic
TestRunPlannerLogic = {}

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
        if row.biomeEncounterDepthCost == nil
            and row.biomeEncounterDepthCostMin == nil
            and row.biomeEncounterDepthCostMax == nil
        then
            row.biomeEncounterDepthCost = 1
        end
        if row.biomeEncounterDepthCostMin == nil or row.biomeEncounterDepthCostMax == nil then
            if type(row.biomeEncounterDepthCost) == "table" then
                row.biomeEncounterDepthCostMin = row.biomeEncounterDepthCost.min
                row.biomeEncounterDepthCostMax = row.biomeEncounterDepthCost.max
            else
                row.biomeEncounterDepthCostMin = row.biomeEncounterDepthCost
                row.biomeEncounterDepthCostMax = row.biomeEncounterDepthCost
            end
        end
        rewardItems.attach(row)
    end
    return rows
end

local function primaryRewardItem(row)
    return row and row.rewardItems and row.rewardItems[1] or nil
end

local function loadCatalog()
    local data = dofile("src/mods/data.lua")
    return data.loadCatalog(testImport), data
end

local function loadRunState()
    return testImport("mods/logic/run_state.lua")
end

local function loadRewardLegality()
    local semantics = testImport("mods/route/reward_planning/semantics.lua")
    local invalidLocations = testImport("mods/route/invalid_locations.lua")
    return testImport("mods/route/reward_planning/legality.lua", nil, {
        conditions = testImport("mods/rewards/declarations/conditions.lua"),
        rewardItems = testImport("mods/route/reward_planning/items.lua"),
        semantics = semantics,
        invalidLocations = invalidLocations,
        context = testImport("mods/route/reward_planning/context.lua"),
        markers = testImport("mods/route/reward_planning/marker_targets.lua", nil, {
            markers = testImport("mods/route/markers.lua"),
            semantics = semantics,
            invalidLocations = invalidLocations,
        }),
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

local function loadRoutePlan()
    local timeline = testImport("mods/route/timeline.lua")
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    local semantics = testImport("mods/route/reward_planning/semantics.lua")
    local runState = testImport("mods/logic/run_state.lua")
    return testImport("mods/logic/route_plan.lua", nil, {
        executionPlan = testImport("mods/logic/execution_plan.lua"),
        runState = runState,
        routeContext = testImport("mods/route/run_context.lua", nil, {
            controls = testImport("mods/route/run_context/controls.lua"),
            targets = loadRouteTargets(timeline, rewardItems, semantics),
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
        valid = false,
        disabled = true,
        invalidRows = {
            {
                rowIndex = 1,
                code = "test_invalid",
                message = "test invalid",
            },
        },
        rows = {},
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

function TestRunPlannerLogic.testRoutePlanSelectsUnderworldForErebusStart()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local runtime = runtimeForCatalog(routePlan, catalog)

    local plan = routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    lu.assertTrue(plan.active)
    lu.assertTrue(plan.valid)
    lu.assertEquals(plan.routeKey, "Underworld")
    lu.assertNil(plan.snapshot)
    lu.assertEquals(plan.executionPlan.routeKey, "Underworld")
    lu.assertEquals(plan.executionPlan.layers.rooms, true)
    lu.assertEquals(plan.executionPlan.layers.rewards, true)
    lu.assertEquals(plan.executionPlan.layers.npcs, false)
    lu.assertEquals(plan.executionPlan.layers.features, false)
    lu.assertIs(routePlan.get(runtime), plan)
end

function TestRunPlannerLogic.testRunStateNormalizesCurrentBiomeAndRoute()
    local catalog = loadCatalog()
    local runState = loadRunState()

    lu.assertEquals(runState.currentBiomeKey({
        CurrentRoom = {
            RoomSetName = "F",
        },
    }), "F")
    lu.assertEquals(runState.currentBiomeKey({
        CurrentRoom = {
            RoomSetName = "F",
            NextRoomSet = { "G" },
        },
    }), "G")
    lu.assertEquals(runState.currentBiomeKey({
        CurrentRoom = {
            RoomSetName = "F",
            ForceNextRoomSet = "I",
        },
    }), "I")
    lu.assertEquals(runState.currentBiomeKey({
        CurrentRoom = {
            RoomSetName = "Q",
        },
    }, {
        RoomSetName = "O",
    }), "O")
    lu.assertEquals(runState.currentBiomeKey({
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, nil, {
        Name = "O_Combat05",
        RoomSetName = "O",
    }), "O")

    lu.assertEquals(runState.routeKey(catalog, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }), "Underworld")
    lu.assertEquals(runState.routeKey(catalog, {
        CurrentRoom = {
            RoomSetName = "O",
        },
    }), "Surface")
    lu.assertTrue(runState.isRoute(catalog, {
        CurrentRoom = {
            RoomSetName = "O",
        },
    }, nil, nil, "Surface"))
end

function TestRunPlannerLogic.testRunStateNormalizesDepthCounters()
    local runState = loadRunState()
    local currentRun = {
        RunDepthCache = "12",
        BiomeDepthCache = "4",
        BiomeEncounterDepth = "3",
    }

    lu.assertEquals(runState.runDepthCache(currentRun), 12)
    lu.assertEquals(runState.biomeDepthCache(currentRun), 4)
    lu.assertEquals(runState.nextBiomeDepthCache(currentRun), 5)
    lu.assertEquals(runState.biomeEncounterDepth(currentRun), 3)
    lu.assertEquals(runState.runDepthCache(nil), 0)
    lu.assertEquals(runState.biomeDepthCache(nil), 0)
    lu.assertEquals(runState.biomeEncounterDepth(nil), 0)
end

function TestRunPlannerLogic.testRoutePlanSelectsSurfaceForEphyraStart()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local runtime = runtimeForCatalog(routePlan, catalog)

    local plan = routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "N",
        },
    }, {
        StartingBiome = "N",
    })

    lu.assertTrue(plan.active)
    lu.assertTrue(plan.valid)
    lu.assertEquals(plan.routeKey, "Surface")
    lu.assertNil(plan.snapshot)
    lu.assertEquals(plan.executionPlan.routeKey, "Surface")
end

function TestRunPlannerLogic.testRoutePlanCompilesRuntimeExecutionPlan()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = {
            controlName = "RouteF",
            biomeKey = "F",
            adapter = "FixedLinearRoute",
            valid = true,
            disabled = false,
            invalidRows = {},
            rows = {
                {
                    rowIndex = 1,
                    routeOrdinal = 0,
                    slotKind = "intro",
                    isBiomeEntry = true,
                    roomKey = "F_PreRun",
                    roleKey = "Intro",
                    optionKey = "",
                    valid = true,
                    rewardKind = "roomStore",
                    rewards = { "Boon", "ZeusUpgrade" },
                    rewardLoot = { "ZeusUpgrade" },
                    rewardPicks = {
                        {
                            key = "boonSource",
                            kind = "dropdown",
                            alias = "Reward1LootKey",
                            value = "ZeusUpgrade",
                        },
                    },
                },
                {
                    rowIndex = 2,
                    routeOrdinal = 1,
                    slotKind = "biomeRow",
                    roomKey = "",
                    roleKey = "Vanilla",
                    optionKey = "",
                    valid = true,
                },
                {
                    rowIndex = 3,
                    routeOrdinal = 2,
                    biomeDepthCache = 1,
                    biomeDepthCacheCost = 1,
                    slotKind = "biomeRow",
                    roomKey = "F_Story01",
                    roleKey = "Story",
                    optionKey = "Arachne",
                    valid = true,
                    features = {
                        chaos = true,
                    },
                },
            },
        },
    })

    local plan = routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    local execution = plan.executionPlan
    local biome = execution.biomes.F
    lu.assertEquals(#biome.plannedRows, 2)
    lu.assertEquals(biome.plannedByRowIndex[1].roomKey, "F_PreRun")
    lu.assertEquals(biome.plannedEntryRoom.roomKey, "F_PreRun")
    lu.assertEquals(biome.plannedByBiomeDepthCache[1].primary.roomKey, "F_Story01")
    lu.assertEquals(biome.plannedRoutableByBiomeDepthCache[1].primary.roomKey, "F_Story01")
    lu.assertEquals(biome.reservedRoomKeys.F_Story01.primary.rowIndex, 3)
    lu.assertEquals(execution.reservedRoomKeys.F_Story01.primary.biomeKey, "F")
    lu.assertEquals(primaryRewardItem(biome.plannedByRowIndex[1]).kind, "roomStore")
    lu.assertEquals(primaryRewardItem(biome.plannedByRowIndex[1]).rewards[2], "ZeusUpgrade")
    lu.assertEquals(primaryRewardItem(biome.plannedByRowIndex[1]).picks[1].value, "ZeusUpgrade")
    lu.assertEquals(biome.plannedByRowIndex[3].features.chaos, true)
end

function TestRunPlannerLogic.testExecutionPlanPreservesDisabledNpcRows()
    local executionPlan = testImport("mods/logic/execution_plan.lua")
    local plan = executionPlan.compile({
        routeKey = "Underworld",
        biomes = {},
        npcs = {
            rows = {
                {
                    rowIndex = 1,
                    slotKey = "Artemis",
                    npcKey = "Artemis",
                    groupKey = "FieldNPC",
                    disabled = true,
                    mode = "Disabled",
                    valid = true,
                },
                {
                    rowIndex = 2,
                    slotKey = "Nemesis",
                    npcKey = "Nemesis",
                    groupKey = "FieldNPC",
                    mode = "Vanilla",
                    targetKey = "",
                    valid = true,
                },
            },
        },
    }, {
        layers = {
            npcs = true,
        },
    })

    lu.assertEquals(#plan.npcs.rows, 1)
    lu.assertEquals(plan.npcs.rows[1].slotKey, "Artemis")
    lu.assertTrue(plan.npcs.rows[1].disabled)
    lu.assertEquals(plan.npcs.rows[1].mode, "Disabled")
    lu.assertNil(plan.npcs.rows[1].target)
    lu.assertEquals(plan.npcs.bySlotKey.Artemis.slotKey, "Artemis")
    lu.assertNil(plan.npcs.bySlotKey.Nemesis)
end

function TestRunPlannerLogic.testRoutePlanKeepsPrebossBranchesAtSharedRouteOrdinal()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = {
            controlName = "RouteF",
            biomeKey = "F",
            adapter = "FixedLinearRoute",
            valid = true,
            disabled = false,
            invalidRows = {},
            rows = {
            {
                rowIndex = 12,
                routeOrdinal = 11,
                biomeDepthCache = 10,
                biomeDepthCacheCost = 0,
                slotKind = "preboss",
                    roomKey = "F_PreBoss01",
                    branchKey = "Shop",
                    roleKey = "Shop",
                    optionKey = "",
                    valid = true,
                    rewardKind = "roomStore",
                    rewards = { "Shop" },
                },
            {
                rowIndex = 13,
                routeOrdinal = 11,
                biomeDepthCache = 10,
                biomeDepthCacheCost = 0,
                slotKind = "preboss",
                    roomKey = "F_PreBoss01",
                    branchKey = "MajorReward",
                    roleKey = "MajorReward",
                    optionKey = "",
                    valid = true,
                    rewardKind = "roomStore",
                    rewards = { "Boon" },
                },
            },
        },
    })

    local plan = routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    local biome = plan.executionPlan.biomes.F
    local depthBucket = biome.plannedByBiomeDepthCache[10]
    local room = depthBucket.byRoomKey.F_PreBoss01
    local reservation = plan.executionPlan.reservedRoomKeys.F_PreBoss01

    lu.assertEquals(#depthBucket.rows, 2)
    lu.assertTrue(depthBucket.branchGroup)
    lu.assertEquals(depthBucket.primary.branchKey, "Shop")
    lu.assertEquals(depthBucket.byBranchKey.Shop.rowIndex, 12)
    lu.assertEquals(depthBucket.byBranchKey.MajorReward.rowIndex, 13)
    lu.assertEquals(#room.rows, 2)
    lu.assertEquals(primaryRewardItem(room.byBranchKey.MajorReward).rewards[1], "Boon")
    lu.assertEquals(#biome.plannedByRoomKey.F_PreBoss01.rows, 2)
    lu.assertEquals(#reservation.entries, 2)
    lu.assertEquals(reservation.entries[2].branchKey, "MajorReward")
end

function TestRunPlannerLogic.testRoomRoutingForcesPlannedLinearRoom()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            F_Story01 = { Name = "F_Story01" },
        },
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "F_Story01",
                roleKey = "Story",
                optionKey = "Arachne",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    local originalArgs = {
        PreserveMe = true,
    }
    local args = roomRouting.buildArgs(runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
    }, originalArgs, {})

    lu.assertEquals(args.ForceNextRoom, "F_Story01")
    lu.assertEquals(args.PreserveMe, true)
    lu.assertNil(originalArgs.ForceNextRoom)
end

function TestRunPlannerLogic.testRoomRoutingExcludesFutureReservedRooms()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan)
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 4,
                routeOrdinal = 3,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "F_Story01",
                roleKey = "Story",
                optionKey = "Arachne",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    local args = roomRouting.buildArgs(runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
    }, {
        ExcludedNames = {
            ExistingBan = true,
        },
    }, {})

    lu.assertNil(args.ForceNextRoom)
    lu.assertEquals(args.ExcludedNames.ExistingBan, true)
    lu.assertEquals(args.ExcludedNames.F_Story01, true)
end

function TestRunPlannerLogic.testRoomRoutingDoesNotDuplicateNormalPlannedRoom()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan)
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "F_Story01",
                roleKey = "Story",
                optionKey = "Arachne",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    local args = roomRouting.buildArgs(runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
    }, {}, {
        {
            Room = {
                Name = "F_Story01",
            },
        },
    })

    lu.assertNil(args.ForceNextRoom)
    lu.assertEquals(args.ExcludedNames.F_Story01, true)
end

function TestRunPlannerLogic.testRoomRoutingAllowsSharedPrebossBranchRoom()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            F_PreBoss01 = { Name = "F_PreBoss01" },
        },
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 12,
                routeOrdinal = 11,
                biomeDepthCache = 10,
                biomeDepthCacheCost = 0,
                slotKind = "preboss",
                roomKey = "F_PreBoss01",
                branchKey = "Shop",
                roleKey = "Shop",
                valid = true,
            },
            {
                rowIndex = 13,
                routeOrdinal = 11,
                biomeDepthCache = 10,
                biomeDepthCacheCost = 0,
                slotKind = "preboss",
                roomKey = "F_PreBoss01",
                branchKey = "MajorReward",
                roleKey = "MajorReward",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    local args = roomRouting.buildArgs(runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 10,
    }, {}, {
        {
            Room = {
                Name = "F_PreBoss01",
            },
        },
    })

    lu.assertEquals(args.ForceNextRoom, "F_PreBoss01")
end

function TestRunPlannerLogic.testRoomRoutingSupportsSummitLinearAdapter()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            Q_MiniBoss01 = { Name = "Q_MiniBoss01" },
        },
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        Q = plannedBiomeSnapshot("Q", "scriptedFixedLinear", {
            {
                rowIndex = 3,
                routeOrdinal = 3,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "Q_MiniBoss01",
                roleKey = "Miniboss",
                optionKey = "Q_MiniBoss01",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "Q",
        },
    }, {
        StartingBiome = "Q",
    })

    local args = roomRouting.buildArgs(runtime, {
        CurrentRoom = {
            RoomSetName = "Q",
        },
        BiomeDepthCache = 2,
    }, {}, {})

    lu.assertEquals(args.ForceNextRoom, "Q_MiniBoss01")
end

function TestRunPlannerLogic.testRoomRoutingSupportsThessalyMultiEncounterAdapter()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            O_Story01 = { Name = "O_Story01" },
        },
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        O = plannedBiomeSnapshot("O", "multiEncounterFixed", {
            {
                rowIndex = 5,
                routeOrdinal = 4,
                biomeDepthCache = 4,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "O_Story01",
                roleKey = "Story",
                optionKey = "O_Story01",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "O",
        },
    }, {
        StartingBiome = "O",
    })

    local args = roomRouting.buildArgs(runtime, {
        CurrentRoom = {
            RoomSetName = "O",
        },
        BiomeDepthCache = 4,
    }, {}, {})

    lu.assertEquals(args.ForceNextRoom, "O_Story01")
end

function TestRunPlannerLogic.testRoomRoutingSupportsTartarusClockworkAdapter()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            I_Combat03 = { Name = "I_Combat03" },
        },
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        I = plannedBiomeSnapshot("I", "clockworkGoal", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "I_Combat03",
                roleKey = "Goal",
                optionKey = "I_Combat03",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "I",
        },
    }, {
        StartingBiome = "I",
    })

    local args = roomRouting.buildArgs(runtime, {
        CurrentRoom = {
            RoomSetName = "I",
        },
        BiomeDepthCache = 2,
    }, {}, {})

    lu.assertEquals(args.ForceNextRoom, "I_Combat03")
end

function TestRunPlannerLogic.testRoomRoutingSupportsFieldsCageAdapter()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            H_Combat05 = { Name = "H_Combat05" },
        },
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        H = plannedBiomeSnapshot("H", "fieldsCageRoute", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "H_Combat05",
                roleKey = "Combat",
                optionKey = "H_Combat05",
                variantKey = "TwoRewards",
                cageRewardCount = 2,
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "H",
        },
    }, {
        StartingBiome = "H",
    })

    local args = roomRouting.buildArgs(runtime, {
        CurrentRoom = {
            RoomSetName = "H",
        },
        BiomeDepthCache = 2,
    }, {}, {})

    local planned = routePlan.get(runtime).executionPlan.biomes.H.plannedByBiomeDepthCache[2].primary
    lu.assertEquals(args.ForceNextRoom, "H_Combat05")
    lu.assertEquals(planned.cageRewardCount, 2)
end

function TestRunPlannerLogic.testRoomRoutingForcesFieldsCageRewardCount()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local logs = {}
    local roomRouting = loadRoomRouting(routePlan, {
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        H = plannedBiomeSnapshot("H", "fieldsCageRoute", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "H_Combat05",
                roleKey = "Combat",
                optionKey = "H_Combat05",
                variantKey = "ThreeRewards",
                cageRewardCount = 3,
                valid = true,
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "H",
        },
        BiomeDepthCache = 2,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "H",
    })

    local baseCalled = false
    local count = roomRouting.selectFieldsDoorCageCount(runtime, function()
        baseCalled = true
        return 2
    end, currentRun, {
        Name = "H_Combat05",
        RoomSetName = "H",
        MinDoorCageRewards = 2,
        MaxDoorCageRewards = 3,
    })

    lu.assertFalse(baseCalled)
    lu.assertEquals(count, 3)
    lu.assertTrue(logsContain(logs, "cage rewards H_Combat05 forced count=3 planned=3"))
end

function TestRunPlannerLogic.testRoomRoutingClampsFieldsCageRewardCountToRoomMax()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        H = plannedBiomeSnapshot("H", "fieldsCageRoute", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "H_Combat05",
                roleKey = "Combat",
                optionKey = "H_Combat05",
                variantKey = "ThreeRewards",
                cageRewardCount = 3,
                valid = true,
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "H",
        },
        BiomeDepthCache = 2,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "H",
    })

    local count = roomRouting.selectFieldsDoorCageCount(runtime, function()
        return 2
    end, currentRun, {
        Name = "H_Combat05",
        RoomSetName = "H",
        MinDoorCageRewards = 2,
        MaxDoorCageRewards = 2,
    })

    lu.assertEquals(count, 2)
end

function TestRunPlannerLogic.testRoomRoutingPrioritizesPlannedEphyraHubDoors()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local predetermined = {
        [101] = "N_Combat01",
        [102] = "N_Combat02",
        [103] = "N_Combat03",
        [104] = "N_Combat04",
        [105] = "N_Combat05",
        [106] = "N_Combat06",
        [107] = "N_Combat07",
        [108] = "N_Combat08",
        [109] = "N_Combat09",
        [110] = "N_Combat10",
    }
    local logs = {}
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            N_Hub = {
                Name = "N_Hub",
                PredeterminedDoorRooms = predetermined,
            },
        },
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        N = plannedBiomeSnapshot("N", "hubPylon", {
            {
                rowIndex = 4,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_Combat01",
                hubDoorId = 101,
                roleKey = "Combat",
                optionKey = "N_Combat01",
                valid = true,
            },
            {
                rowIndex = 5,
                routeOrdinal = 2,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_Combat02",
                hubDoorId = 102,
                roleKey = "Combat",
                optionKey = "N_Combat02",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "N",
        },
    }, {
        StartingBiome = "N",
    })

    local room = {
        Name = "N_Hub",
        RoomSetName = "N",
    }
    local baseCalled = false
    local result = roomRouting.chooseAvailableNHubDoors(runtime, function(baseRoom)
        baseCalled = true
        baseRoom.UnavailableDoors = {
            [101] = true,
        }
        baseRoom.DoorsChosen = true
        return "base"
    end, room, {})
    local planned = routePlan.get(runtime).executionPlan.biomes.N.plannedByRowIndex[4]

    lu.assertTrue(baseCalled)
    lu.assertEquals(result, "base")
    lu.assertEquals(planned.hubDoorId, 101)
    lu.assertNil(room.UnavailableDoors[101])
    lu.assertNil(room.UnavailableDoors[102])
    lu.assertTrue(room.UnavailableDoors[103])
    lu.assertEquals(availableDoorCount(predetermined, room.UnavailableDoors), 9)
    lu.assertTrue(logsContain(logs, "hub doors N_Hub planned=2 available=9"))
end

function TestRunPlannerLogic.testRoomRoutingSuppressesUnplannedEphyraMinibossDoor()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local predetermined = {
        [101] = "N_Combat01",
        [102] = "N_Combat02",
        [103] = "N_Combat03",
        [104] = "N_Combat04",
        [105] = "N_Combat05",
        [106] = "N_Combat06",
        [107] = "N_Combat07",
        [108] = "N_Combat08",
        [201] = "N_MiniBoss01",
        [202] = "N_MiniBoss02",
    }
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            N_Hub = {
                Name = "N_Hub",
                PredeterminedDoorRooms = predetermined,
            },
        },
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        N = plannedBiomeSnapshot("N", "hubPylon", {
            {
                rowIndex = 4,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_MiniBoss01",
                hubDoorId = 201,
                roleKey = "Miniboss",
                optionKey = "N_MiniBoss01",
                valid = true,
            },
        }),
    })
    routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "N",
        },
    }, {
        StartingBiome = "N",
    })

    local room = {
        Name = "N_Hub",
        RoomSetName = "N",
    }
    roomRouting.chooseAvailableNHubDoors(runtime, function(baseRoom)
        baseRoom.UnavailableDoors = {
            [201] = true,
        }
        baseRoom.DoorsChosen = true
    end, room, {})

    lu.assertNil(room.UnavailableDoors[201])
    lu.assertTrue(room.UnavailableDoors[202])
    lu.assertEquals(availableDoorCount(predetermined, room.UnavailableDoors), 9)
end

function TestRunPlannerLogic.testRoomRoutingDisablesPlannedEphyraSideDoor()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local logs = {}
    local roomRouting = loadRoomRouting(routePlan, {
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        N = plannedBiomeSnapshot("N", "hubPylon", {
            {
                rowIndex = 4,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_Combat12",
                hubDoorId = 561389,
                roleKey = "Combat",
                optionKey = "N_Combat12",
                valid = true,
                sideRooms = {
                    {
                        sideIndex = 1,
                        doorId = 558352,
                        roomKey = "N_Sub09",
                        modeKey = "Disabled",
                        enabled = false,
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            Name = "N_Combat12",
            RoomSetName = "N",
        },
        BiomeDepthCache = 1,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "N",
    })

    local baseCalled = false
    withCurrentRun(currentRun, function()
        roomRouting.checkNSubRoomDoorUnavailable(runtime, function()
            baseCalled = true
        end, {
            ObjectId = 558352,
        }, {
            AboveMinAvailableChance = 0.3,
        })
    end)

    lu.assertFalse(baseCalled)
    lu.assertTrue(currentRun.CurrentRoom.UnavailableDoors[558352])
    lu.assertNil(currentRun.NumSubRoomsSpawned)
    lu.assertTrue(logsContain(logs, "side door N_Combat12 door=558352 disabled planned=N_Sub09 row=4"))
end

function TestRunPlannerLogic.testRoomRoutingEnablesPlannedEphyraSideDoor()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local logs = {}
    local roomRouting = loadRoomRouting(routePlan, {
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        N = plannedBiomeSnapshot("N", "hubPylon", {
            {
                rowIndex = 4,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_Combat12",
                hubDoorId = 561389,
                roleKey = "Combat",
                optionKey = "N_Combat12",
                valid = true,
                sideRooms = {
                    {
                        sideIndex = 1,
                        doorId = 558352,
                        roomKey = "N_Sub09",
                        modeKey = "Enabled",
                        enabled = true,
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            Name = "N_Combat12",
            RoomSetName = "N",
        },
        BiomeDepthCache = 1,
        NumSubRoomsSpawned = 0,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "N",
    })

    local baseCalled = false
    withCurrentRun(currentRun, function()
        roomRouting.checkNSubRoomDoorUnavailable(runtime, function(source)
            baseCalled = true
            currentRun.CurrentRoom.UnavailableDoors = {
                [source.ObjectId] = true,
            }
        end, {
            ObjectId = 558352,
        }, {
            AboveMinAvailableChance = 0.3,
        })
    end)

    lu.assertTrue(baseCalled)
    lu.assertNil(currentRun.CurrentRoom.UnavailableDoors[558352])
    lu.assertEquals(currentRun.NumSubRoomsSpawned, 1)
    lu.assertTrue(logsContain(logs, "side door N_Combat12 door=558352 enabled planned=N_Sub09 row=4"))
end

function TestRunPlannerLogic.testRoomRoutingLeavesVanillaEphyraSideDoorToBase()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan)
    local runtime = runtimeForCatalog(routePlan, catalog, {
        N = plannedBiomeSnapshot("N", "hubPylon", {
            {
                rowIndex = 4,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_Combat12",
                hubDoorId = 561389,
                roleKey = "Combat",
                optionKey = "N_Combat12",
                valid = true,
                sideRooms = {
                    {
                        sideIndex = 1,
                        doorId = 558352,
                        roomKey = "N_Sub09",
                        modeKey = "Vanilla",
                        enabled = false,
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            Name = "N_Combat12",
            RoomSetName = "N",
        },
        BiomeDepthCache = 1,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "N",
    })

    local baseCalled = false
    withCurrentRun(currentRun, function()
        roomRouting.checkNSubRoomDoorUnavailable(runtime, function(source)
            baseCalled = true
            currentRun.CurrentRoom.UnavailableDoors = {
                [source.ObjectId] = true,
            }
            return "base"
        end, {
            ObjectId = 558352,
        }, {})
    end)

    lu.assertTrue(baseCalled)
    lu.assertTrue(currentRun.CurrentRoom.UnavailableDoors[558352])
end

function TestRunPlannerLogic.testRoomRoutingForcesThessalyTwoEncounterRoom()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        O = plannedBiomeSnapshot("O", "multiEncounterFixed", {
            {
                rowIndex = 5,
                routeOrdinal = 4,
                biomeDepthCache = 4,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "O_Combat05",
                roleKey = "Combat",
                optionKey = "O_Combat05",
                variantKey = "TwoCombats",
                realCombatCount = 2,
                valid = true,
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "O",
        },
        BiomeDepthCache = 4,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "O",
    })

    local room = {
        Name = "O_Combat05",
        RoomSetName = "O",
        MultipleEncountersData = {
            { LegalEncounters = { "Intro" } },
            { LegalEncounters = { "First" } },
            { LegalEncounters = { "Second" }, GameStateRequirements = { ChanceToPlay = 0.6 } },
        },
    }

    withCurrentRun(currentRun, function()
        roomRouting.setupMultipleEncounters(runtime, function(setupRoom)
            lu.assertEquals(#setupRoom.MultipleEncountersData, 2)
            setupRoom.Encounters = {
                { Name = "Intro" },
                { Name = "First" },
            }
        end, room)
    end)

    lu.assertEquals(#room.Encounters, 2)
    lu.assertEquals(#room.MultipleEncountersData, 3)
    lu.assertNotNil(room.MultipleEncountersData[3].GameStateRequirements)
end

function TestRunPlannerLogic.testRoomRoutingForcesThessalyThreeEncounterRoom()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        O = plannedBiomeSnapshot("O", "multiEncounterFixed", {
            {
                rowIndex = 5,
                routeOrdinal = 4,
                biomeDepthCache = 4,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "O_Combat05",
                roleKey = "Combat",
                optionKey = "O_Combat05",
                variantKey = "ThreeCombats",
                realCombatCount = 3,
                valid = true,
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "O",
        },
        BiomeDepthCache = 4,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "O",
    })

    local room = {
        Name = "O_Combat05",
        RoomSetName = "O",
        MultipleEncountersData = {
            { LegalEncounters = { "Intro" } },
            { LegalEncounters = { "First" } },
            { LegalEncounters = { "Second" }, GameStateRequirements = { ChanceToPlay = 0.6 } },
        },
    }

    withCurrentRun(currentRun, function()
        roomRouting.setupMultipleEncounters(runtime, function(setupRoom)
            lu.assertEquals(#setupRoom.MultipleEncountersData, 3)
            lu.assertNil(setupRoom.MultipleEncountersData[3].GameStateRequirements)
            setupRoom.Encounters = {
                { Name = "Intro" },
                { Name = "First" },
                { Name = "Second" },
            }
        end, room)
    end)

    lu.assertEquals(#room.Encounters, 3)
    lu.assertEquals(#room.MultipleEncountersData, 3)
    lu.assertNotNil(room.MultipleEncountersData[3].GameStateRequirements)
end

function TestRunPlannerLogic.testRoomRoutingForcesPlannedStartingRoom()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local createdArgs
    local logs = {}
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            F_Opening02 = {
                Name = "F_Opening02",
                Starting = true,
            },
        },
        IsRoomEligible = function()
            return true
        end,
        CreateRoom = function(roomData, args)
            createdArgs = args
            return {
                Name = roomData.Name,
            }
        end,
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 1,
                routeOrdinal = 0,
                slotKind = "opening",
                isBiomeEntry = true,
                roomKey = "F_Opening02",
                roleKey = "Opening",
                optionKey = "F_Opening02",
                valid = true,
            },
        }),
    })
    local chooseStartingRoomHook
    roomRouting.registerHooks({
        hooks = {
            wrap = function(name, callback)
                if name == "ChooseStartingRoom" then
                    chooseStartingRoomHook = callback
                end
            end,
        },
    }, catalog)

    local originalArgs = {
        StartingBiome = "F",
    }
    local baseCalled = false
    local result = chooseStartingRoomHook({
        isEnabled = function()
            return true
        end,
    }, runtime, function()
        baseCalled = true
    end, {}, originalArgs)

    lu.assertFalse(baseCalled)
    lu.assertEquals(result.Name, "F_Opening02")
    lu.assertNotIs(createdArgs, originalArgs)
    lu.assertEquals(createdArgs.StartingBiome, "F")
    lu.assertEquals(routePlan.get(runtime).routeKey, "Underworld")
    lu.assertTrue(logsContain(logs, "plan begin route=Underworld active=true valid=true"))
    lu.assertTrue(logsContain(logs, "plan row biome=F row=1 routeOrdinal=0 kind=opening room=F_Opening02"))
end

function TestRunPlannerLogic.testRoomRoutingFallsBackWhenPlannedStartingRoomIsIneligible()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local roomRouting = loadRoomRouting(routePlan, {
        RoomData = {
            F_Opening02 = {
                Name = "F_Opening02",
                Starting = true,
            },
        },
        IsRoomEligible = function()
            return false
        end,
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 1,
                routeOrdinal = 0,
                slotKind = "opening",
                isBiomeEntry = true,
                roomKey = "F_Opening02",
                roleKey = "Opening",
                optionKey = "F_Opening02",
                valid = true,
            },
        }),
    })
    local chooseStartingRoomHook
    roomRouting.registerHooks({
        hooks = {
            wrap = function(name, callback)
                if name == "ChooseStartingRoom" then
                    chooseStartingRoomHook = callback
                end
            end,
        },
    }, catalog)

    local baseCalled = false
    local result = chooseStartingRoomHook({
        isEnabled = function()
            return true
        end,
    }, runtime, function(_, args)
        baseCalled = true
        lu.assertEquals(routePlan.get(runtime).routeKey, "Underworld")
        return {
            Name = "Vanilla",
            Args = args,
        }
    end, {}, {
        StartingBiome = "F",
    })

    lu.assertTrue(baseCalled)
    lu.assertEquals(result.Name, "Vanilla")
end

function TestRunPlannerLogic.testRoutePlanDefersDreamDive()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local runtime = runtimeForCatalog(routePlan, catalog)

    local plan = routePlan.refresh(catalog, runtime, {
        IsDreamRun = true,
        CurrentRoom = {
            RoomSetName = "G",
        },
    }, {
        StartingBiome = "G",
    })

    lu.assertFalse(plan.active)
    lu.assertFalse(plan.valid)
    lu.assertEquals(plan.reason, routePlan.REASON_DREAM_DIVE)
    lu.assertNil(plan.routeKey)
    lu.assertNil(plan.snapshot)
end

function TestRunPlannerLogic.testRoutePlanInvalidatesBadRouteSnapshot()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = invalidBiomeSnapshot("F"),
    })

    local plan = routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    lu.assertFalse(plan.active)
    lu.assertFalse(plan.valid)
    lu.assertEquals(plan.reason, routePlan.REASON_INVALID_SNAPSHOT)
    lu.assertEquals(plan.routeKey, "Underworld")
    lu.assertEquals(plan.invalidRows[1].biomeKey, "F")
    lu.assertEquals(plan.invalidRows[1].code, "test_invalid")
end

function TestRunPlannerLogic.testRoutePlanRegistersCacheAndStartNewRunHook()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local runtime = runtimeForCatalog(routePlan, catalog)
    local cacheDefs
    local startNewRunHook
    local moduleRef = {
        cache = {
            define = function(defs)
                cacheDefs = defs
            end,
        },
        hooks = {
            wrap = function(name, callback)
                if name == "StartNewRun" then
                    startNewRunHook = callback
                end
            end,
        },
    }

    routePlan.defineCache(moduleRef)
    routePlan.registerHooks(moduleRef, catalog)

    lu.assertNotNil(cacheDefs.RoutePlan)
    lu.assertEquals(cacheDefs.RoutePlan.domain, "currentRun")
    lu.assertNotNil(startNewRunHook)

    local baseCalled = false
    local result = startNewRunHook({
        isEnabled = function()
            return true
        end,
    }, runtime, function(_, args)
        baseCalled = true
        return {
            CurrentRoom = {
                RoomSetName = args.StartingBiome,
            },
        }
    end, nil, {
        StartingBiome = "N",
    })

    lu.assertTrue(baseCalled)
    lu.assertEquals(result.CurrentRoom.RoomSetName, "N")
    lu.assertEquals(routePlan.get(runtime).routeKey, "Surface")
end

function TestRunPlannerLogic.testLogicAttachDefinesCacheAndHooks()
    local catalog, data = loadCatalog()
    local logic
    withTestImport(function()
        logic = testImport("mods/systems.lua").create({
            data = data,
            catalog = catalog,
        }).logic
    end)

    local cacheDefined = false
    local hookedStartNewRun = false
    local hookedChooseStartingRoom = false
    local hookedChooseNextRoomData = false
    local hookedSetupRoomMultipleEncountersData = false
    local hookedSelectFieldsDoorCageCount = false
    local hookedChooseAvailableNHubDoors = false
    local hookedCheckNSubRoomDoorUnavailable = false
    logic.attach({
        cache = {
            define = function(defs)
                cacheDefined = defs.RoutePlan ~= nil
            end,
        },
        hooks = {
            wrap = function(name)
                if name == "StartNewRun" then
                    hookedStartNewRun = true
                elseif name == "ChooseStartingRoom" then
                    hookedChooseStartingRoom = true
                elseif name == "ChooseNextRoomData" then
                    hookedChooseNextRoomData = true
                elseif name == "SetupRoomMultipleEncountersData" then
                    hookedSetupRoomMultipleEncountersData = true
                elseif name == "SelectFieldsDoorCageCount" then
                    hookedSelectFieldsDoorCageCount = true
                elseif name == "ChooseAvailableN_HubDoors" then
                    hookedChooseAvailableNHubDoors = true
                elseif name == "CheckN_SubRoomDoorUnavailable" then
                    hookedCheckNSubRoomDoorUnavailable = true
                end
            end,
        },
    })

    lu.assertTrue(cacheDefined)
    lu.assertTrue(hookedStartNewRun)
    lu.assertTrue(hookedChooseStartingRoom)
    lu.assertTrue(hookedChooseNextRoomData)
    lu.assertTrue(hookedSetupRoomMultipleEncountersData)
    lu.assertTrue(hookedSelectFieldsDoorCageCount)
    lu.assertTrue(hookedChooseAvailableNHubDoors)
    lu.assertTrue(hookedCheckNSubRoomDoorUnavailable)
end
