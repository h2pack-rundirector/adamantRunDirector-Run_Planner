local lu = require("luaunit")
local harness = require("tests.support.logic_harness")

-- luacheck: globals TestRunPlannerLogicFeatureRouting
TestRunPlannerLogicFeatureRouting = {}

local loadFeatureRouting = harness.loadFeatureRouting

local function plannedRoom(rowIndex, biomeDepthCache, roomKey, biomeKey, routeOrdinal)
    return {
        rowIndex = rowIndex,
        routeOrdinal = routeOrdinal or biomeDepthCache,
        biomeDepthCache = biomeDepthCache,
        roomKey = roomKey,
        biomeKey = biomeKey or "F",
        roleKey = "Combat",
    }
end

local function planWithFeatures(opts)
    opts = opts or {}
    local rooms = opts.rooms or {
        opts.room or plannedRoom(3, 4, "F_Combat04"),
    }
    local biomes = {}
    for _, room in ipairs(rooms) do
        local biomeKey = room.biomeKey or "F"
        biomes[biomeKey] = biomes[biomeKey] or {
            plannedByBiomeDepthCache = {},
            plannedByRoomKey = {},
        }
        biomes[biomeKey].plannedByBiomeDepthCache[room.biomeDepthCache] = {
            primary = room,
            byRoomKey = {
                [room.roomKey] = {
                    primary = room,
                },
            },
        }
        biomes[biomeKey].plannedByRoomKey[room.roomKey] = {
            primary = room,
        }
    end
    return {
        layers = {
            features = opts.featuresLayer ~= false,
        },
        biomes = biomes,
        features = {
            byFeatureKey = opts.byFeatureKey or {},
        },
    }
end

local function featureRow(featureKey, row, targetOverrides)
    local target = {
        featureKey = featureKey,
        biomeKey = row.biomeKey or "F",
        rowIndex = row.rowIndex,
        targetRowIndex = tostring(row.rowIndex),
        roomKey = row.roomKey,
    }
    for key, value in pairs(targetOverrides or {}) do
        target[key] = value
    end
    return {
        rowIndex = 1,
        slotKey = featureKey,
        featureKey = featureKey,
        targetKey = tostring(target.biomeKey) .. ":" .. tostring(target.targetRowIndex),
        target = target,
    }
end

local function runtimeForPlan(plan)
    return {}, {
        get = function()
            return {
                active = true,
                valid = true,
                executionPlan = plan,
            }
        end,
    }
end

local function quietFeatureRouting(routePlan)
    return loadFeatureRouting(routePlan, {
        print = function()
        end,
    })
end

function TestRunPlannerLogicFeatureRouting.testFeatureRoutingForcesPlannedChaosGate()
    local row = plannedRoom(3, 4, "F_Combat04")
    local plan = planWithFeatures({
        room = row,
        byFeatureKey = {
            chaos = {
                rows = {
                    featureRow("chaos", row),
                },
            },
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local featureRouting = quietFeatureRouting(routePlan)
    local currentRun = {
        CurrentRoom = {
            Name = "F_Combat04",
            RoomSetName = "F",
        },
        BiomeDepthCache = 4,
    }

    local baseCalled = false
    featureRouting.handleSecretSpawns(runtime, function()
        baseCalled = true
    end, currentRun)

    lu.assertTrue(baseCalled)
    lu.assertTrue(currentRun.CurrentRoom.ForceSecretDoor)
end

function TestRunPlannerLogicFeatureRouting.testFeatureRoutingSuppressesNaturalChaosAwayFromTarget()
    local targetRow = plannedRoom(5, 6, "F_Combat06")
    local currentRow = plannedRoom(3, 4, "F_Combat04")
    local plan = planWithFeatures({
        rooms = {
            currentRow,
            targetRow,
        },
        byFeatureKey = {
            chaos = {
                rows = {
                    featureRow("chaos", targetRow),
                },
            },
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local featureRouting = quietFeatureRouting(routePlan)
    local currentRun = {
        CurrentRoom = {
            Name = "F_Combat04",
            RoomSetName = "F",
            SecretChanceSuccess = true,
        },
        BiomeDepthCache = 4,
    }

    featureRouting.prepareRoomFeatures(runtime, currentRun)

    lu.assertFalse(currentRun.CurrentRoom.SecretChanceSuccess)
    lu.assertNil(currentRun.CurrentRoom.ForceSecretDoor)
end

function TestRunPlannerLogicFeatureRouting.testFeatureRoutingForcesWellAndSuppressesSurfaceIndependently()
    local row = plannedRoom(3, 4, "G_Combat04", "G")
    local surfaceTarget = plannedRoom(4, 5, "O_Combat05", "O")
    local plan = planWithFeatures({
        rooms = {
            row,
            surfaceTarget,
        },
        byFeatureKey = {
            wellShop = {
                rows = {
                    featureRow("wellShop", row),
                },
            },
            surfaceShop = {
                rows = {
                    featureRow("surfaceShop", surfaceTarget),
                },
            },
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local featureRouting = quietFeatureRouting(routePlan)
    local currentRun = {
        CurrentRoom = {
            Name = "G_Combat04",
            RoomSetName = "G",
            WellShopChanceSuccess = false,
            SurfaceShopChanceSuccess = true,
        },
        BiomeDepthCache = 4,
    }

    featureRouting.prepareRoomFeatures(runtime, currentRun)

    lu.assertTrue(currentRun.CurrentRoom.ForceWellShop)
    lu.assertFalse(currentRun.CurrentRoom.SurfaceShopChanceSuccess)
end

function TestRunPlannerLogicFeatureRouting.testFeatureRoutingLeavesVanillaWhenLayerDisabled()
    local row = plannedRoom(3, 4, "F_Combat04")
    local plan = planWithFeatures({
        featuresLayer = false,
        room = row,
        byFeatureKey = {
            chaos = {
                rows = {
                    featureRow("chaos", row),
                },
            },
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local featureRouting = quietFeatureRouting(routePlan)
    local currentRun = {
        CurrentRoom = {
            Name = "F_Combat04",
            RoomSetName = "F",
            SecretChanceSuccess = true,
        },
        BiomeDepthCache = 4,
    }

    featureRouting.prepareRoomFeatures(runtime, currentRun)

    lu.assertTrue(currentRun.CurrentRoom.SecretChanceSuccess)
    lu.assertNil(currentRun.CurrentRoom.ForceSecretDoor)
end

function TestRunPlannerLogicFeatureRouting.testFeatureRoutingCanTargetEphyraSideRooms()
    local parentRow = plannedRoom(4, 1, "N_Combat01", "N")
    local plan = planWithFeatures({
        rooms = {
            parentRow,
        },
        byFeatureKey = {
            surfaceShop = {
                rows = {
                    featureRow("surfaceShop", parentRow, {
                        targetRowIndex = "4.side1",
                        roomKey = "N_Sub01",
                        parentRoomKey = "N_Combat01",
                        sideIndex = 1,
                    }),
                },
            },
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local featureRouting = quietFeatureRouting(routePlan)
    local currentRun = {
        CurrentRoom = {
            Name = "N_Sub01",
            RoomSetName = "N_SubRooms",
            SurfaceShopChanceSuccess = false,
        },
        RoomHistory = {
            {
                Name = "N_Combat01",
                RoomSetName = "N",
            },
        },
        BiomeDepthCache = 2,
    }

    featureRouting.prepareRoomFeatures(runtime, currentRun)

    lu.assertTrue(currentRun.CurrentRoom.ForceSurfaceShop)
end
