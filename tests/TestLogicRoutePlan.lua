local lu = require("luaunit")
local harness = require("tests.support.logic_harness")

-- luacheck: globals TestRunPlannerLogicRoutePlan
TestRunPlannerLogicRoutePlan = {}

local testImport = harness.testImport
local withTestImport = harness.withTestImport
local primaryRewardItem = harness.primaryRewardItem
local loadCatalog = harness.loadCatalog
local loadRunState = harness.loadRunState
local loadRoutePlan = harness.loadRoutePlan
local plannedBiomeSnapshot = harness.plannedBiomeSnapshot
local invalidBiomeSnapshot = harness.invalidBiomeSnapshot
local biomeControl = harness.biomeControl
local runtimeWithControls = harness.runtimeWithControls
local runtimeForCatalog = harness.runtimeForCatalog

local function prebossRewardOffers()
    return {
        {
            address = "prebossShop",
            label = "Shop",
            kind = "shop",
            shopProfile = "WorldShop",
            rewardAliasStart = 1,
            rewardAliasCount = 3,
            rewardGeneration = {
                effectTiming = "afterBatch",
            },
            requiredBranchValue = "Shop",
        },
        {
            address = "prebossReward",
            label = "Free Reward",
            kind = "roomStore",
            rewardStore = "RunProgress",
            ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
            rewardAliasStart = 4,
            rewardAliasCount = 2,
            generated = true,
            offerCount = 1,
            requiredBranchValue = "FreeReward",
        },
    }
end

function TestRunPlannerLogicRoutePlan.testRoutePlanSelectsUnderworldForErebusStart()
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

function TestRunPlannerLogicRoutePlan.testRunStateNormalizesCurrentBiomeAndRoute()
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

function TestRunPlannerLogicRoutePlan.testRunStateNormalizesDepthCounters()
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

function TestRunPlannerLogicRoutePlan.testRoutePlanSelectsSurfaceForEphyraStart()
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

function TestRunPlannerLogicRoutePlan.testRoutePlanCompilesRuntimeExecutionPlan()
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
                    rewardSourceCount = 2,
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
    lu.assertEquals(primaryRewardItem(biome.plannedByRowIndex[1]).rewardSourceCount, 2)
    lu.assertEquals(primaryRewardItem(biome.plannedByRowIndex[1]).rewards[2], "ZeusUpgrade")
    lu.assertEquals(primaryRewardItem(biome.plannedByRowIndex[1]).picks[1].value, "ZeusUpgrade")
    lu.assertEquals(biome.plannedByRowIndex[3].features.chaos, true)
end

function TestRunPlannerLogicRoutePlan.testRoutePlanCompilesOnlyConfiguredBiomePrefix()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local controls = {
        RouteGlobalUnderworld = {
            setRouteContext = function()
            end,
            configuredBiomeCount = function()
                return 1
            end,
            isLayerConfigured = function(_, layer)
                return layer == "rewards"
            end,
        },
        RouteF = biomeControl(plannedBiomeSnapshot("F", "FixedLinearRoute", {
            {
                rowIndex = 1,
                routeOrdinal = 1,
                slotKind = "biomeRow",
                roomKey = "F_Combat01",
                roleKey = "Combat",
                valid = true,
            },
        })),
        RouteG = biomeControl(invalidBiomeSnapshot("G")),
    }
    local runtime = runtimeWithControls(routePlan, {
        get = function(controlName)
            return controls[controlName]
        end,
    })

    local plan = routePlan.refresh(catalog, runtime, {
        CurrentRoom = {
            RoomSetName = "F",
        },
    }, {
        StartingBiome = "F",
    })

    lu.assertTrue(plan.active)
    lu.assertTrue(plan.valid)
    lu.assertEquals(plan.executionPlan.biomeOrder, { "F" })
    lu.assertNotNil(plan.executionPlan.biomes.F)
    lu.assertNil(plan.executionPlan.biomes.G)
end

function TestRunPlannerLogicRoutePlan.testExecutionPlanPreservesDisabledNpcRows()
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

function TestRunPlannerLogicRoutePlan.testExecutionPlanPreservesFeatureTargetRoomIdentity()
    local executionPlan = testImport("mods/logic/execution_plan.lua")
    local plan = executionPlan.compile({
        routeKey = "Surface",
        biomes = {},
        features = {
            {
                rows = {
                    {
                        rowIndex = 1,
                        slotKey = "HermesShrine1",
                        featureKey = "surfaceShop",
                        targetKey = "N:4.side1",
                        valid = true,
                        target = {
                            key = "N:4.side1",
                            featureKey = "surfaceShop",
                            biomeKey = "N",
                            rowIndex = 4,
                            targetRowIndex = "4.side1",
                            roomKey = "N_Sub01",
                            parentRoomKey = "N_Combat01",
                            sideIndex = 1,
                        },
                    },
                },
            },
        },
    }, {
        layers = {
            features = true,
        },
    })

    local row = plan.features.byFeatureKey.surfaceShop.rows[1]
    lu.assertEquals(row.target.roomKey, "N_Sub01")
    lu.assertEquals(row.target.parentRoomKey, "N_Combat01")
    lu.assertEquals(row.target.sideIndex, 1)
end

function TestRunPlannerLogicRoutePlan.testRoutePlanKeepsCompositePrebossRewardsOnPrebossMarker()
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
                    roomOfferCount = 2,
                    roleKey = "Preboss",
                    optionKey = "",
                    valid = true,
                    rewardKind = "preboss",
                    rewardOffers = prebossRewardOffers(),
                    rewards = { "RandomLoot", "ArmorBoost", "SpellDrop", "Boon", "ZeusUpgrade" },
                    rewardLoot = { "DemeterUpgrade" },
                    rewardPicks = {
                        {
                            key = "prebossBranch",
                            kind = "prebossBranch",
                            alias = "PrebossBranchKey",
                            value = "FreeReward",
                        },
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

    local biome = plan.executionPlan.biomes.F
    local depthBucket = biome.plannedByBiomeDepthCache[10]
    local row = depthBucket.primary

    lu.assertEquals(#depthBucket.rows, 1)
    lu.assertEquals(row.roleKey, "Preboss")
    lu.assertEquals(row.roomOfferCount, 2)
    lu.assertNil(row.roomKey)
    lu.assertEquals(biome.plannedPrebossRow, row)
    lu.assertNil(depthBucket.byRoomKey.F_PreBoss01)
    lu.assertNil(biome.plannedByRoomKey.F_PreBoss01)
    lu.assertNil(plan.executionPlan.reservedRoomKeys.F_PreBoss01)
    lu.assertEquals(primaryRewardItem(row).kind, "shop")
    lu.assertFalse(primaryRewardItem(row).active)
    lu.assertEquals(primaryRewardItem(row).requiredBranchValue, "Shop")
    lu.assertEquals(row.rewardItems[2].address, "prebossReward")
    lu.assertEquals(row.rewardItems[2].kind, "roomStore")
    lu.assertEquals(row.rewardItems[2].rewards[1], "Boon")
    lu.assertEquals(row.rewardItems[2].rewards[2], "ZeusUpgrade")
    lu.assertTrue(row.rewardItems[2].generated)
    lu.assertEquals(row.rewardItems[2].offerCount, 1)
    lu.assertEquals(row.rewardItems[2].ineligibleRewardTypes, { "Devotion", "RoomMoneyDrop" })
    lu.assertTrue(row.rewardItems[2].active)
    lu.assertEquals(row.rewardItems[2].requiredBranchValue, "FreeReward")
end

function TestRunPlannerLogicRoutePlan.testRoutePlanIndexesPrebossMarkerWithoutRoomReservation()
    local executionPlan = testImport("mods/logic/execution_plan.lua")
    local plan = executionPlan.compile({
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "I",
                adapter = "ClockworkGoalRoute",
                rows = {
                    {
                        rowIndex = 14,
                        biomeDepthCache = 12,
                        slotKind = "preboss",
                        roleKey = "Preboss",
                        valid = true,
                    },
                },
            },
        },
    }, {
        layers = {
            rooms = true,
        },
    })

    local biome = plan.biomes.I
    local depthBucket = biome.plannedByBiomeDepthCache[12]

    lu.assertNil(depthBucket.primary.roomKey)
    lu.assertEquals(depthBucket.primary.roleKey, "Preboss")
    lu.assertEquals(biome.plannedPrebossRow, depthBucket.primary)
    lu.assertNil(biome.plannedByRoomKey.I_PreBoss01)
    lu.assertNil(biome.plannedByRoomKey.I_PreBoss02)
    lu.assertNil(plan.reservedRoomKeys.I_PreBoss01)
    lu.assertNil(plan.reservedRoomKeys.I_PreBoss02)
    lu.assertNil(biome.plannedRoutableByBiomeDepthCache[12])
end

function TestRunPlannerLogicRoutePlan.testRoutePlanDefersDreamDive()
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

function TestRunPlannerLogicRoutePlan.testRoutePlanInvalidatesBadRouteSnapshot()
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

function TestRunPlannerLogicRoutePlan.testRoutePlanRegistersCacheAndStartNewRunHook()
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

function TestRunPlannerLogicRoutePlan.testLogicAttachDefinesCacheAndHooks()
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
    local hookedChooseEncounter = false
    local hookedHandleSecretSpawns = false
    local registeredOnActivate = false
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
                elseif name == "ChooseEncounter" then
                    hookedChooseEncounter = true
                elseif name == "HandleSecretSpawns" then
                    hookedHandleSecretSpawns = true
                end
            end,
        },
        onActivate = function()
            registeredOnActivate = true
        end,
    })

    lu.assertTrue(cacheDefined)
    lu.assertTrue(hookedStartNewRun)
    lu.assertTrue(hookedChooseStartingRoom)
    lu.assertTrue(hookedChooseNextRoomData)
    lu.assertTrue(hookedSetupRoomMultipleEncountersData)
    lu.assertTrue(hookedSelectFieldsDoorCageCount)
    lu.assertTrue(hookedChooseAvailableNHubDoors)
    lu.assertTrue(hookedCheckNSubRoomDoorUnavailable)
    lu.assertTrue(hookedChooseEncounter)
    lu.assertTrue(hookedHandleSecretSpawns)
    lu.assertTrue(registeredOnActivate)
end
