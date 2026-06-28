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

local function fullFErebusRows()
    return {
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxManaDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "RoomMoneyDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
            Reward1Key = "Major",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat05",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            Reward2Key = "MaxManaDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat08",
            Reward1Key = "Major",
            Reward2Key = "RoomMoneyDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat09",
            Reward1Key = "Major",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat10",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            Reward1Key = "Shop",
            Reward2Key = "FreeReward",
        },
    }
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearEmitsDumbSelectedRowsSnapshot()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields({
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
            SiblingRewardClassKey = "Major",
        },
    }), instance)

    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.schema, "selectedRows.v1")
    lu.assertEquals(snapshot.controlName, "RouteF")
    lu.assertEquals(snapshot.biomeKey, "F")
    lu.assertEquals(snapshot.adapter, "fixedLinear")
    lu.assertNil(snapshot.rows[1].valid)
    lu.assertNil(snapshot.rows[1].roomTopology)
    lu.assertNil(snapshot.rows[1].rewardItems)
    lu.assertEquals(snapshot.rows[1].roleKey, "Opening")
    lu.assertEquals(snapshot.rows[1].optionKey, "F_Opening01")
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "F_Combat02")
    lu.assertEquals(snapshot.rows[2].topology.siblings[1].structureKey, "Combat")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[1], "Major")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[2], "MaxHealthDrop")
    lu.assertEquals(snapshot.rows[2].rewards.sibling[1].rewardClassKey, "Major")
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearBuilderResolvesRoomFactsFromDeclarations()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields({
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 4)
    lu.assertEquals(rooms[1].eventKey, "F_Opening01")
    lu.assertEquals(rooms[1].roleKey, "Opening")
    lu.assertEquals(rooms[1].routeOrdinal, 0)
    lu.assertEquals(rooms[1].roomHistoryOrdinal, 1)
    lu.assertEquals(rooms[1].runDepthCache, 2)
    lu.assertEquals(rooms[1].biomeDepthCache, 0)
    lu.assertEquals(rooms[1].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[2].eventKey, "F_Combat02")
    lu.assertEquals(rooms[2].roleKey, "Combat")
    lu.assertEquals(rooms[2].routeOrdinal, 1)
    lu.assertEquals(rooms[2].roomHistoryOrdinal, 2)
    lu.assertEquals(rooms[2].runDepthCache, 3)
    lu.assertEquals(rooms[2].biomeDepthCache, 0)
    lu.assertEquals(rooms[2].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[2].runEncounterDepth, 2)
    lu.assertEquals(rooms[3].eventKey, "Boss")
    lu.assertEquals(rooms[3].sourceKind, "afterBiome")
    lu.assertEquals(rooms[4].eventKey, "F_PostBoss01")
    lu.assertEquals(rooms[4].sourceKind, "afterBiome")
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearBuildsFullDeclaredFErebusSpine()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields(fullFErebusRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 14)
    lu.assertEquals(rooms[1].eventKey, "F_Opening01")
    lu.assertEquals(rooms[1].roleKey, "Opening")
    lu.assertEquals(rooms[2].eventKey, "F_Combat01")
    lu.assertEquals(rooms[11].eventKey, "F_Combat10")
    lu.assertEquals(rooms[12].eventKey, "Preboss")
    lu.assertEquals(rooms[12].sourceKind, "row")
    lu.assertEquals(rooms[12].roleKey, "Preboss")
    lu.assertEquals(rooms[13].eventKey, "Boss")
    lu.assertEquals(rooms[13].sourceKind, "afterBiome")
    lu.assertEquals(rooms[14].eventKey, "F_PostBoss01")
    lu.assertEquals(rooms[14].sourceKind, "afterBiome")
    lu.assertEquals(rooms[14].roomHistoryOrdinal, 14)
end
