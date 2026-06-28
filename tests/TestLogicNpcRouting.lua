local lu = require("luaunit")
local harness = require("tests.support.logic_harness")

-- luacheck: globals TestRunPlannerLogicNpcRouting
TestRunPlannerLogicNpcRouting = {}

local loadCatalog = harness.loadCatalog
local loadNpcRouting = harness.loadNpcRouting

local function loadQuietNpcRouting(routePlan, game)
    game = game or {}
    game.print = function()
    end
    return loadNpcRouting(routePlan, game)
end

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

local function planWithRows(opts)
    opts = opts or {}
    local rooms = opts.rooms or {
        opts.room or plannedRoom(3, 4, "F_Combat04"),
    }
    local biomes = {}
    for _, room in ipairs(rooms) do
        local biomeKey = room.biomeKey or "F"
        biomes[biomeKey] = biomes[biomeKey] or {
            plannedByBiomeDepthCache = {},
        }
        biomes[biomeKey].plannedByBiomeDepthCache[room.biomeDepthCache] = {
            primary = room,
            byRoomKey = {
                [room.roomKey] = {
                    primary = room,
                },
            },
        }
    end
    return {
        layers = {
            npcs = opts.npcsLayer ~= false,
        },
        biomeOrder = opts.biomeOrder,
        biomes = biomes,
        npcs = {
            rows = opts.rows or {},
        },
    }
end

local function target(npcKey, row, encounterName, variantKey)
    return {
        npcKey = npcKey,
        biomeKey = row.biomeKey or "F",
        biomeRouteIndex = row.biomeRouteIndex,
        rowIndex = row.rowIndex,
        routeOrdinal = row.routeOrdinal,
        roomKey = row.roomKey,
        variantKey = variantKey or encounterName,
        encounterName = encounterName,
    }
end

local function targetRow(npcKey, groupKey, row, encounterName, variantKey)
    return {
        rowIndex = 1,
        slotKey = npcKey,
        npcKey = npcKey,
        groupKey = groupKey,
        mode = "Target",
        target = target(npcKey, row, encounterName, variantKey),
    }
end

local function disabledRow(npcKey, groupKey)
    return {
        rowIndex = 1,
        slotKey = npcKey,
        npcKey = npcKey,
        groupKey = groupKey,
        disabled = true,
        mode = "Disabled",
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

local function choose(npcRouting, runtime, catalog, currentRun, room, args)
    local calledArgs
    local result = npcRouting.chooseEncounter(runtime, function(_, baseRoom, baseArgs)
        calledArgs = baseArgs
        return baseArgs and baseArgs.LegalEncounters or baseRoom.LegalEncounters
    end, catalog, currentRun, room, args)
    return result, calledArgs
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingForcesPlannedEncounter()
    local catalog = loadCatalog()
    local room = plannedRoom(3, 4, "F_Combat04")
    local plan = planWithRows({
        room = room,
        rows = {
            targetRow("Artemis", "FieldNpc", room, "ArtemisCombatF"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan)

    local result, calledArgs = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "F_Combat03",
            RoomSetName = "F",
        },
        BiomeDepthCache = 3,
    }, {
        Name = "F_Combat04",
        RoomSetName = "F",
        LegalEncounters = {
            "GenericCombatF",
            "ArtemisCombatF",
            "NemesisCombatF",
        },
    }, {})

    lu.assertEquals(result, { "ArtemisCombatF" })
    lu.assertEquals(calledArgs.LegalEncounters, { "ArtemisCombatF" })
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingSuppressesPlannedNpcGroupAwayFromTarget()
    local catalog = loadCatalog()
    local targetRoom = plannedRoom(3, 4, "F_Combat04")
    local plan = planWithRows({
        room = targetRoom,
        rows = {
            targetRow("Artemis", "FieldNpc", targetRoom, "ArtemisCombatF"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan)

    local result = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "F_Combat01",
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
    }, {
        Name = "F_Combat02",
        RoomSetName = "F",
        LegalEncounters = {
            "GenericCombatF",
            "ArtemisCombatF",
            "ArtemisCombatF2",
            "NemesisCombatF",
            "ArachneCombatF",
        },
    }, {})

    lu.assertEquals(result, {
        "GenericCombatF",
        "ArachneCombatF",
    })
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingReservesFutureArachneFamilyAwayFromTarget()
    local catalog = loadCatalog()
    local earlyRoom = plannedRoom(2, 2, "F_Combat02", "F", 2)
    local targetRoom = plannedRoom(2, 2, "G_Combat02", "G", 12)
    local plan = planWithRows({
        rooms = {
            earlyRoom,
            targetRoom,
        },
        rows = {
            targetRow("Arachne", "ArachneCombat", targetRoom, "ArachneCombatG"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan)

    local result = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "F_Combat01",
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
    }, {
        Name = "F_Combat02",
        RoomSetName = "F",
        LegalEncounters = {
            "GenericCombatF",
            "ArachneCombatF",
            "ArachneCombatG",
        },
    }, {})

    lu.assertEquals(result, {
        "GenericCombatF",
    })
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingDoesNotSuppressArachneAfterPastTarget()
    local catalog = loadCatalog()
    local targetRoom = plannedRoom(2, 2, "F_Combat02", "F", 2)
    local laterRoom = plannedRoom(2, 2, "G_Combat02", "G", 12)
    local plan = planWithRows({
        rooms = {
            targetRoom,
            laterRoom,
        },
        rows = {
            targetRow("Arachne", "ArachneCombat", targetRoom, "ArachneCombatF"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan)

    local result = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "G_Combat01",
            RoomSetName = "G",
        },
        BiomeDepthCache = 1,
    }, {
        Name = "G_Combat02",
        RoomSetName = "G",
        LegalEncounters = {
            "GenericCombatG",
            "ArachneCombatG",
        },
    }, {})

    lu.assertEquals(result, {
        "GenericCombatG",
        "ArachneCombatG",
    })
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingUsesBiomeOrderWhenCurrentRowIsUnplanned()
    local catalog = loadCatalog()
    local targetRoom = plannedRoom(2, 2, "F_Combat02", "F", 2)
    targetRoom.biomeRouteIndex = 1
    local plan = planWithRows({
        biomeOrder = {
            "F",
            "G",
        },
        room = targetRoom,
        rows = {
            targetRow("Arachne", "ArachneCombat", targetRoom, "ArachneCombatF"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan)

    local result = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "G_Combat01",
            RoomSetName = "G",
        },
        BiomeDepthCache = 1,
    }, {
        Name = "G_Combat99",
        RoomSetName = "G",
        LegalEncounters = {
            "GenericCombatG",
            "ArachneCombatG",
        },
    }, {})

    lu.assertEquals(result, {
        "GenericCombatG",
        "ArachneCombatG",
    })
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingSuppressesDisabledNpc()
    local catalog = loadCatalog()
    local room = plannedRoom(3, 4, "F_Combat04")
    local plan = planWithRows({
        room = room,
        rows = {
            disabledRow("Artemis", "FieldNpc"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan)

    local result = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "F_Combat03",
            RoomSetName = "F",
        },
        BiomeDepthCache = 3,
    }, {
        Name = "F_Combat04",
        RoomSetName = "F",
        LegalEncounters = {
            "GenericCombatF",
            "ArtemisCombatF",
            "ArtemisCombatF2",
            "NemesisCombatF",
        },
    }, {})

    lu.assertEquals(result, {
        "GenericCombatF",
        "NemesisCombatF",
    })
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingDoesNotSuppressAfterConfiguredPrefix()
    local catalog = loadCatalog()
    local room = plannedRoom(3, 4, "F_Combat04", "F")
    local plan = planWithRows({
        biomeOrder = {
            "F",
        },
        room = room,
        rows = {
            disabledRow("Artemis", "FieldNpc"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan)
    local args = {
        LegalEncounters = {
            "GenericCombatG",
            "ArtemisCombatG",
        },
    }

    local result, calledArgs = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "G_Combat03",
            RoomSetName = "G",
        },
        BiomeDepthCache = 3,
    }, {
        Name = "G_Combat04",
        RoomSetName = "G",
    }, args)

    lu.assertEquals(result, {
        "GenericCombatG",
        "ArtemisCombatG",
    })
    lu.assertIs(calledArgs, args)
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingFallsBackWhenLayerDisabled()
    local catalog = loadCatalog()
    local room = plannedRoom(3, 4, "F_Combat04")
    local plan = planWithRows({
        npcsLayer = false,
        room = room,
        rows = {
            targetRow("Artemis", "FieldNpc", room, "ArtemisCombatF"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan)

    local result = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "F_Combat03",
            RoomSetName = "F",
        },
        BiomeDepthCache = 3,
    }, {
        Name = "F_Combat04",
        RoomSetName = "F",
        LegalEncounters = {
            "GenericCombatF",
            "ArtemisCombatF",
        },
    }, {})

    lu.assertEquals(result, {
        "GenericCombatF",
        "ArtemisCombatF",
    })
end

function TestRunPlannerLogicNpcRouting.testNpcRoutingDoesNotForceIneligiblePlannedEncounter()
    local catalog = loadCatalog()
    local room = plannedRoom(3, 4, "F_Combat04")
    local plan = planWithRows({
        room = room,
        rows = {
            targetRow("Artemis", "FieldNpc", room, "ArtemisCombatF"),
        },
    })
    local runtime, routePlan = runtimeForPlan(plan)
    local npcRouting = loadQuietNpcRouting(routePlan, {
        EncounterData = {
            ArtemisCombatF = {
                GameStateRequirements = {
                    "blocked",
                },
            },
        },
        IsGameStateEligible = function()
            return false
        end,
    })

    local result = choose(npcRouting, runtime, catalog, {
        CurrentRoom = {
            Name = "F_Combat03",
            RoomSetName = "F",
        },
        BiomeDepthCache = 3,
    }, {
        Name = "F_Combat04",
        RoomSetName = "F",
        LegalEncounters = {
            "GenericCombatF",
            "ArtemisCombatF",
        },
    }, {})

    lu.assertEquals(result, {
        "GenericCombatF",
    })
end
