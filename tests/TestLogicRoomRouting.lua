local lu = require("luaunit")
local harness = require("tests.support.logic_harness")

-- luacheck: globals TestRunPlannerLogicRoomRouting
TestRunPlannerLogicRoomRouting = {}

local loadCatalog = harness.loadCatalog
local loadRoutePlan = harness.loadRoutePlan
local loadRoomRouting = harness.loadRoomRouting
local logsContain = harness.logsContain
local availableDoorCount = harness.availableDoorCount
local plannedBiomeSnapshot = harness.plannedBiomeSnapshot
local runtimeForCatalog = harness.runtimeForCatalog
local withCurrentRun = harness.withCurrentRun

function TestRunPlannerLogicRoomRouting.testRoomRoutingForcesPlannedLinearRoom()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingExcludesFutureReservedRooms()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingDoesNotDuplicateNormalPlannedRoom()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingForcesPlannedPrebossRoom()
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
                roomOfferCount = 2,
                roleKey = "Preboss",
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingSupportsSummitLinearAdapter()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingSupportsThessalyMultiEncounterAdapter()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingSupportsTartarusClockworkAdapter()
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
                roleKey = "Combat",
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingSupportsFieldsCageAdapter()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingForcesFieldsCageRewardCount()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingClampsFieldsCageRewardCountToRoomMax()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingPrioritizesPlannedEphyraHubDoors()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingSuppressesUnplannedEphyraMinibossDoor()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingDisablesPlannedEphyraSideDoor()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingEnablesPlannedEphyraSideDoor()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingLeavesVanillaEphyraSideDoorToBase()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingForcesThessalyTwoEncounterRoom()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingForcesThessalyThreeEncounterRoom()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingForcesPlannedStartingRoom()
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

function TestRunPlannerLogicRoomRouting.testRoomRoutingFallsBackWhenPlannedStartingRoomIsIneligible()
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
