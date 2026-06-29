local lu = require("luaunit")
local h = require("tests.support.control_harness")
local importHarness = require("tests.support.import_harness")

local historySystem = h.withTestImport(function()
    return h.testImport("mods/route/history/assembly.lua").create({
        selectedLegalityRules = importHarness.loadSelectedLegalityRules(),
    })
end)
local routeHistory = historySystem.history
local routeLoot = historySystem.loot
local historyBuilder = historySystem.builder
local historyValidator = historySystem.validator

-- luacheck: globals TestRunPlannerRouteHistoryValidator
TestRunPlannerRouteHistoryValidator = {}

local function buildHistory(route, biomeKey, template, rows)
    local catalog = h.loadCatalog()
    local instance = template.prepare({
        name = "Route" .. biomeKey,
        biome = catalog.lookup[biomeKey],
    })
    local control = template.createRuntime(h.routeFields(rows), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()
    return historyBuilder.build({
        route = route,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, requestedBiomeKey)
            if requestedBiomeKey == biomeKey then
                return selectedSnapshot
            end
            return nil
        end,
    }), catalog
end

local function validate(route, biomeKey, template, rows)
    local history, catalog = buildHistory(route, biomeKey, template, rows)
    return historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })
end

local function validateHistory(history)
    return historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = {},
        },
        history = history,
        biomeLookup = {},
    })
end

local function emitRoom(history, roomHistoryOrdinal, fields)
    return routeHistory.emitAt(history, {
        routeKey = "Underworld",
        biomeKey = fields and fields.biomeKey or "F",
        routeBiomeIndex = fields and fields.routeBiomeIndex or 1,
        rowIndex = fields and fields.rowIndex or roomHistoryOrdinal,
        roomHistoryOrdinal = roomHistoryOrdinal,
        runDepthCache = fields and fields.runDepthCache or roomHistoryOrdinal + 1,
        runEncounterDepth = fields and fields.runEncounterDepth or roomHistoryOrdinal,
        biomeDepthCache = fields and fields.biomeDepthCache or roomHistoryOrdinal,
        biomeEncounterDepth = fields and fields.biomeEncounterDepth or roomHistoryOrdinal,
    }, {
        kind = "room",
        eventKey = fields and fields.roomKey or "Room" .. tostring(roomHistoryOrdinal),
        roomKey = fields and fields.roomKey or "Room" .. tostring(roomHistoryOrdinal),
        topology = fields and fields.topology or nil,
        reward = fields and fields.reward or nil,
    })
end

local function emitLoot(history, room, lootType, fields)
    return routeHistory.emitAt(history, room, {
        kind = "loot",
        eventKey = lootType,
        lootType = lootType,
        parentEntry = room,
        parentRoomKey = room.roomKey,
        address = fields and fields.address or "row",
        sourceValues = fields and fields.sourceValues or nil,
        lootName = fields and fields.lootName or nil,
    })
end

function TestRunPlannerRouteHistoryValidator.testValidatorRejectsDuplicateConcreteRoom()
    local route = {
        key = "Underworld",
        biomes = { "F" },
    }
    local result = validate(route, "F", h.loadFixedLinearTemplate(), {
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
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxManaDrop",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "option_limit")
    lu.assertEquals(result.invalids[1].biomeKey, "F")
    lu.assertEquals(result.invalids[1].roomKey, "F_Combat02")
end

function TestRunPlannerRouteHistoryValidator.testValidatorRejectsMissingFieldsBridgeForcePressure()
    local route = {
        key = "Underworld",
        biomes = { "H" },
    }
    local result = validate(route, "H", h.loadFieldsCageTemplate(), {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "TwoRewards",
            Reward1Key = "Boon",
            Reward1LootKey = "PoseidonUpgrade",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat09",
            VariantKey = "TwoRewards",
            SiblingStructureKey = "CombatCage2",
            Reward1Key = "Boon",
            Reward1LootKey = "HestiaUpgrade",
            Reward2Key = "WeaponUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat13",
            VariantKey = "TwoRewards",
            SiblingStructureKey = "H_MiniBoss02",
            Reward1Key = "HermesUpgrade",
            Reward2Key = "StackUpgrade",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "forced_topology_pressure_unresolved")
    lu.assertEquals(result.invalids[1].biomeKey, "H")
    lu.assertEquals(result.invalids[1].roomKey, "H_Combat13")
end

function TestRunPlannerRouteHistoryValidator.testValidatorAcceptsGeneratedFieldsBridge()
    local route = {
        key = "Underworld",
        biomes = { "H" },
    }
    local result = validate(route, "H", h.loadFieldsCageTemplate(), {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "TwoRewards",
            Reward1Key = "Boon",
            Reward1LootKey = "PoseidonUpgrade",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat09",
            VariantKey = "TwoRewards",
            SiblingStructureKey = "CombatCage2",
            Reward1Key = "Boon",
            Reward1LootKey = "HestiaUpgrade",
            Reward2Key = "WeaponUpgrade",
        },
        {
            RoleKey = "Bridge",
            SiblingStructureKey = "H_MiniBoss02",
        },
    })

    lu.assertTrue(result.valid)
end

function TestRunPlannerRouteHistoryValidator.testRewardValidatorRejectsTalentBeforeSpell()
    local history = routeHistory.create()
    local room = emitRoom(history, 1)
    emitLoot(history, room, "TalentDrop")

    local result = validateHistory(history)

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "talent_requires_spell")
    lu.assertEquals(result.invalids[1].rewardType, "TalentDrop")
    lu.assertEquals(result.invalids[1].roomKey, "Room1")
end

function TestRunPlannerRouteHistoryValidator.testRewardValidatorTreatsFieldsCageAsSameBatch()
    local history = routeHistory.create()
    local room = emitRoom(history, 1, {
        roomKey = "H_Combat04",
        biomeKey = "H",
        reward = {
            kind = "fieldsCages",
            rewardStore = "RunProgress",
            sourceCount = 2,
            picks = {
                { rewardType = "SpellDrop" },
                { rewardType = "TalentBigDrop" },
            },
        },
    })
    routeLoot.emitForRoomEntry(history, room)

    local result = validateHistory(history)

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "talent_requires_spell")
    lu.assertEquals(result.invalids[1].rewardType, "TalentBigDrop")
    lu.assertEquals(result.invalids[1].address, "cage:2")
end

function TestRunPlannerRouteHistoryValidator.testRewardValidatorAcceptsTalentAfterPriorSpell()
    local history = routeHistory.create()
    local firstRoom = emitRoom(history, 1)
    emitLoot(history, firstRoom, "SpellDrop")
    local secondRoom = emitRoom(history, 2)
    emitLoot(history, secondRoom, "TalentDrop")

    lu.assertTrue(validateHistory(history).valid)
end

function TestRunPlannerRouteHistoryValidator.testRewardValidatorRejectsDevotionAfterOneExitRoom()
    local history = routeHistory.create()
    local zeusRoom = emitRoom(history, 1)
    emitLoot(history, zeusRoom, "Boon", {
        sourceValues = { "ZeusUpgrade" },
        lootName = "ZeusUpgrade",
    })
    local apolloRoom = emitRoom(history, 2)
    emitLoot(history, apolloRoom, "Boon", {
        sourceValues = { "ApolloUpgrade" },
        lootName = "ApolloUpgrade",
    })
    emitRoom(history, 3, {
        topology = {
            exits = {
                { roomKey = "TrialRoom" },
            },
        },
    })
    local trialRoom = emitRoom(history, 4, {
        roomKey = "TrialRoom",
        runEncounterDepth = 7,
    })
    emitLoot(history, trialRoom, "Devotion", {
        sourceValues = { "ZeusUpgrade", "ApolloUpgrade" },
    })

    local result = validateHistory(history)

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "previous_room_exit_count")
    lu.assertEquals(result.invalids[1].rewardType, "Devotion")
end

function TestRunPlannerRouteHistoryValidator.testRewardValidatorRejectsDevotionSpacing()
    local history = routeHistory.create()
    local zeusRoom = emitRoom(history, 1, {
        biomeKey = "F",
        runDepthCache = 2,
    })
    emitLoot(history, zeusRoom, "Boon", {
        sourceValues = { "ZeusUpgrade" },
        lootName = "ZeusUpgrade",
    })
    local apolloRoom = emitRoom(history, 2, {
        biomeKey = "F",
        runDepthCache = 3,
        topology = {
            exits = {
                { roomKey = "PriorTrialRoom" },
                { roomKey = "OtherRoom" },
            },
        },
    })
    emitLoot(history, apolloRoom, "Boon", {
        sourceValues = { "ApolloUpgrade" },
        lootName = "ApolloUpgrade",
    })
    local priorTrialRoom = emitRoom(history, 3, {
        roomKey = "PriorTrialRoom",
        biomeKey = "F",
        runDepthCache = 4,
        runEncounterDepth = 7,
    })
    emitLoot(history, priorTrialRoom, "Devotion", {
        sourceValues = { "ZeusUpgrade", "ApolloUpgrade" },
    })
    emitRoom(history, 8, {
        biomeKey = "G",
        topology = {
            exits = {
                { roomKey = "TrialRoom" },
                { roomKey = "OtherRoom" },
            },
        },
    })
    local trialRoom = emitRoom(history, 9, {
        roomKey = "TrialRoom",
        biomeKey = "G",
        routeBiomeIndex = 2,
        runDepthCache = 10,
        runEncounterDepth = 7,
    })
    emitLoot(history, trialRoom, "Devotion", {
        sourceValues = { "ZeusUpgrade", "ApolloUpgrade" },
    })

    local result = validateHistory(history)

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "devotion_spacing")
    lu.assertEquals(result.invalids[1].relatedEvents[1].lootType, "Devotion")
end
