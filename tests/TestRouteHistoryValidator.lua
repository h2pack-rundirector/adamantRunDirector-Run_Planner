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
local historyFeedback = historySystem.feedback
local historyBuilder = historySystem.builder
local historyValidator = historySystem.validator
local valueStates = h.withTestImport(function()
    return h.testImport("mods/route/value_states.lua")
end)

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
        rewardCandidates = fields and fields.rewardCandidates or nil,
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

local function firstFinding(result, kind, field, expected)
    for _, finding in ipairs(result and result.findings or {}) do
        if finding.kind == kind and (field == nil or finding[field] == expected) then
            return finding
        end
    end
    return nil
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

function TestRunPlannerRouteHistoryValidator.testCandidateValidatorEmitsRoomFindings()
    local route = {
        key = "Underworld",
        biomes = { "F" },
    }
    local history, catalog = buildHistory(route, "F", h.loadFixedLinearTemplate(), {
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
    })

    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })

    local finding = firstFinding(result, "roomCandidateInvalid", "roomKey", "F_Story01")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "biome_depth_unavailable")
    lu.assertEquals(finding.axis, "biomeDepthCache")
    lu.assertEquals(finding.biomeKey, "F")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "F", finding.rowIndex, "OptionKey")
    lu.assertEquals(states.F_Story01, valueStates.HIDDEN)
end

function TestRunPlannerRouteHistoryValidator.testCandidateValidatorEmitsSiblingFindings()
    local route = {
        key = "Underworld",
        biomes = { "F" },
    }
    local history, catalog = buildHistory(route, "F", h.loadFixedLinearTemplate(), {
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
    })

    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })

    local finding = firstFinding(result, "siblingCandidateInvalid", "structureKey", "F_Story01")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "biome_depth_unavailable")
    lu.assertEquals(finding.siblingIndex, 1)

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "F", finding.rowIndex, "SiblingStructureKey")
    lu.assertEquals(states.F_Story01, valueStates.HIDDEN)
end

function TestRunPlannerRouteHistoryValidator.testCandidateValidatorEmitsRewardFindings()
    local history = routeHistory.create()
    emitRoom(history, 1, {
        rewardCandidates = {
            {
                kind = "rewardType",
                address = "row",
                rewardClass = "Major",
                rewardStore = "RunProgress",
                rewardTypes = { "TalentDrop" },
            },
        },
    })

    local result = validateHistory(history)

    local finding = firstFinding(result, "rewardCandidateInvalid", "rewardType", "TalentDrop")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "talent_requires_spell")
    lu.assertEquals(finding.rewardClass, "Major")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "F", 1, "Reward2Key")
    lu.assertEquals(states.TalentDrop, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testCandidateValidatorEmitsFieldsCageRewardFindings()
    local history = routeHistory.create()
    emitRoom(history, 1, {
        biomeKey = "H",
        rewardCandidates = {
            {
                kind = "rewardType",
                address = "cage:2",
                rewardStore = "RunProgress",
                rewardTypes = { "TalentDrop" },
            },
        },
    })

    local result = validateHistory(history)

    local finding = firstFinding(result, "rewardCandidateInvalid", "rewardType", "TalentDrop")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.address, "cage:2")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "H", 1, "Reward2Key")
    lu.assertEquals(states.TalentDrop, valueStates.INVALID)
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

function TestRunPlannerRouteHistoryValidator.testClockworkRejectsPrebossBeforeGoalsComplete()
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local result = validate(route, "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "Preboss",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_preboss_too_early")

    local finding = firstFinding(result, "siblingCandidateInvalid", "structureKey", "Preboss")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "clockwork_preboss_too_early")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "I", finding.rowIndex, "SiblingStructureKey")
    lu.assertEquals(states.Preboss, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testClockworkRejectsGeneratedDoorsWithoutGoalBeforeComplete()
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local result = validate(route, "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatReward",
        },
        {
            RouteKindKey = "NonGoal",
            NonGoalKindKey = "RewardCombat",
            OptionKey = "I_Combat04",
            SiblingStructureKey = "CombatReward",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_goal_door_count")

    local finding = firstFinding(result, "siblingCandidateInvalid", "structureKey", "CombatReward")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "clockwork_goal_door_count")
end

function TestRunPlannerRouteHistoryValidator.testClockworkRequiresPrebossAfterGoalsComplete()
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local result = validate(route, "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatReward",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat04",
            SiblingStructureKey = "CombatReward",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat09",
            SiblingStructureKey = "CombatReward",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat10",
            SiblingStructureKey = "CombatReward",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat11",
            SiblingStructureKey = "CombatReward",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat12",
            SiblingStructureKey = "CombatReward",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_preboss_required")

    local finding = firstFinding(result, "siblingCandidateInvalid", "structureKey", "CombatReward")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "clockwork_preboss_required")
end

function TestRunPlannerRouteHistoryValidator.testClockworkEmitsInactiveBoundaryAfterFinalSingleDoorGoal()
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local result = validate(route, "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat02",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat05",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat06",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat07",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat08",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat13",
        },
    })

    lu.assertTrue(result.valid)

    local finding = firstFinding(result, "rowInactiveBoundary", "rowIndex", 6)
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "clockwork_route_complete")

    local feedback = historyFeedback.fromFindings(result.findings)
    lu.assertFalse(historyFeedback.rowInactive(feedback, "I", 6))
    lu.assertTrue(historyFeedback.rowInactive(feedback, "I", 7))
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
