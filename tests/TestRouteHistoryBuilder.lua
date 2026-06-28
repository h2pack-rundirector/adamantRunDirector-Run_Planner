local lu = require("luaunit")
local h = require("tests.support.control_harness")

local historySystem = h.withTestImport(function()
    return h.testImport("mods/route/history/assembly.lua").create()
end)
local routeHistory = historySystem.history
local historyBuilder = historySystem.builder

-- luacheck: globals TestRunPlannerRouteHistoryBuilder
TestRunPlannerRouteHistoryBuilder = {}

local function roomEvents(history)
    return routeHistory.byKind(history, "room")
end

function TestRunPlannerRouteHistoryBuilder.testBuildEmitsOrderedRoomEntriesFromSnapshots()
    local history = historyBuilder.build({
        {
            routeKey = "Underworld",
            controlName = "RouteF",
            biomeKey = "F",
            rows = {
                {
                    rowIndex = 1,
                    routeOrdinal = 1,
                    roomHistoryOrdinal = 1,
                    biomeDepthCache = 0,
                    biomeEncounterDepth = 0,
                    roleKey = "Opening",
                    optionKey = "F_Opening01",
                    roomKey = "F_Opening01",
                },
                {
                    rowIndex = 2,
                    routeOrdinal = 2,
                    roomHistoryOrdinal = 2,
                    biomeDepthCache = 1,
                    biomeEncounterDepth = 1,
                    roleKey = "Combat",
                    optionKey = "F_Combat01",
                    roomKey = "F_Combat01",
                },
            },
        },
        {
            routeKey = "Underworld",
            controlName = "RouteG",
            biomeKey = "G",
            rows = {
                {
                    rowIndex = 1,
                    routeOrdinal = 1,
                    roomHistoryOrdinal = 12,
                    biomeDepthCache = 0,
                    biomeEncounterDepth = 0,
                    roleKey = "Intro",
                    optionKey = "G_Intro",
                    roomKey = "G_Intro",
                },
            },
        },
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 3)
    lu.assertEquals(rooms[1].eventKey, "F_Opening01")
    lu.assertEquals(rooms[2].eventKey, "F_Combat01")
    lu.assertEquals(rooms[3].eventKey, "G_Intro")
    lu.assertEquals(rooms[1].routeKey, "Underworld")
    lu.assertEquals(rooms[3].controlName, "RouteG")
    lu.assertEquals(rooms[2].biomeDepthCache, 1)
end

function TestRunPlannerRouteHistoryBuilder.testBuildEmitsOnlyEnteredEphyraSideRooms()
    local catalog = h.loadCatalog()
    local template = h.loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(h.routeFields({
        { Reward1Key = "SpellDrop" },
        { Reward1Key = "WeaponUpgrade" },
        {},
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat12",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
    }, {
        { ModeKey = "Enabled", Entered = true },
        { ModeKey = "Enabled", Entered = false },
        {},
    }, {
        { Reward1Key = "MaxHealthDrop" },
        {},
        {},
    }), instance)
    local snapshot = control:buildSnapshot()
    snapshot.routeKey = "Surface"

    local history = historyBuilder.build({
        snapshot,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[1].eventKey, "N_Opening01")
    lu.assertEquals(routeHistory.count(history, {
        kind = "room",
    }), #rooms)
    lu.assertEquals(routeHistory.count(history, {
        groupKey = "SideRoom",
    }), 1)

    local sideRoom = routeHistory.byGroupKey(history, "SideRoom")[1]
    lu.assertEquals(sideRoom.eventKey, "N_Sub09")
    lu.assertEquals(sideRoom.sourceKind, "side")
    lu.assertEquals(sideRoom.sourceIndex, 1)
    lu.assertEquals(sideRoom.parentRoomKey, "N_Combat12")
    lu.assertTrue(sideRoom.entered)
    lu.assertTrue(sideRoom.enabled)
    lu.assertEquals(routeHistory.lastEvent(history, "N_Sub10"), nil)
end
