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

local function loadCatalog()
    local data = dofile("src/mods/data.lua")
    return data.loadCatalog(testImport), data
end

local function loadRewardLegality()
    return testImport("mods/route/reward_legality.lua", nil, {
        routeRules = testImport("mods/rewards/route_rules.lua"),
        timeline = testImport("mods/route/timeline.lua"),
    })
end

local function loadRoutePlan()
    return testImport("mods/logic/route_plan.lua", nil, {
        executionPlan = testImport("mods/logic/execution_plan.lua"),
        routeContext = testImport("mods/route/run_context.lua", nil, {
            rewardLegality = loadRewardLegality(),
            timeline = testImport("mods/route/timeline.lua"),
        }),
    })
end

local function loadRoomRouting(routePlan, game)
    return testImport("mods/logic/room_routing.lua", nil, {
        routePlan = routePlan,
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
        rows = rows,
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
        controlsByName["Route" .. biome.key] = biomeControl(snapshots[biome.key] or validBiomeSnapshot(biome.key))
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
    lu.assertEquals(biome.plannedByRowIndex[1].reward.kind, "roomStore")
    lu.assertEquals(biome.plannedByRowIndex[1].reward.rewards[2], "ZeusUpgrade")
    lu.assertEquals(biome.plannedByRowIndex[1].reward.picks[1].value, "ZeusUpgrade")
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
    lu.assertEquals(room.byBranchKey.MajorReward.reward.rewards[1], "Boon")
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
    local _, data = loadCatalog()
    local bound
    withTestImport(function()
        bound = testImport("mods/logic.lua").bind(data)
    end)

    local cacheDefined = false
    local hookedStartNewRun = false
    local hookedChooseStartingRoom = false
    local hookedChooseNextRoomData = false
    bound.attach({
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
                end
            end,
        },
    })

    lu.assertTrue(cacheDefined)
    lu.assertTrue(hookedStartNewRun)
    lu.assertTrue(hookedChooseStartingRoom)
    lu.assertTrue(hookedChooseNextRoomData)
end
