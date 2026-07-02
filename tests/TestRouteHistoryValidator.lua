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
local formAddress = historySystem.formAddress
local historyFeedback = historySystem.feedback
local historyBuilder = historySystem.builder
local historyValidator = historySystem.validator
local valueStates = h.withTestImport(function()
    return h.testImport("mods/ui/value_states.lua")
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

local function thessalyCombat(optionKey, variantKey)
    return {
        RoleKey = "Combat",
        OptionKey = optionKey,
        VariantKey = variantKey or "TwoCombats",
    }
end

local function ephyraRows()
    return {
        { Reward1Key = "SpellDrop" },
        { Reward1Key = "WeaponUpgrade" },
        {},
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat12",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Story",
            OptionKey = "N_Story01",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "N_MiniBoss02",
            Reward1Key = "AphroditeUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat05",
            Reward1Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat06",
            Reward1Key = "RoomMoneyDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat13",
            Reward1Key = "MaxManaDrop",
        },
        {
            Reward1Key = "RandomLoot",
            Reward1LootKey = "ApolloUpgrade",
            Reward1StateKey = "Bought",
        },
    }
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

function TestRunPlannerRouteHistoryValidator.testThessalyRequiresStoryOrShopByDepthFive()
    local result = validate({
        key = "Surface",
        biomes = { "O" },
    }, "O", h.loadMultiEncounterTemplate(), {
        {},
        thessalyCombat("O_Combat01"),
        thessalyCombat("O_Combat02"),
        thessalyCombat("O_Combat03"),
        thessalyCombat("O_Combat05"),
        thessalyCombat("O_Combat06"),
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "thessaly_story_or_shop_deadline")
    lu.assertNil(result.invalids[1].message)
    lu.assertEquals(result.invalids[1].deadlineRequirementLabel, "Circe or Shop")
    lu.assertEquals(result.invalids[1].deadlineBiomeDepthCache, 5)
    lu.assertEquals(result.invalids[1].rowIndex, 5)
    lu.assertEquals(result.invalids[1].routeOrdinal, 4)

    local feedback = historyFeedback.fromResult({
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.message, "Thessaly requires Circe or Shop by depth 5 (0/1 generated)")
end

function TestRunPlannerRouteHistoryValidator.testThessalyThreeCombatVariantUsesHistoryFeedback()
    local route = {
        key = "Surface",
        biomes = { "O" },
    }
    local result = validate(route, "O", h.loadMultiEncounterTemplate(), {
        {},
        thessalyCombat("O_Combat01", "ThreeCombats"),
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "encounter_depth_unavailable")
    lu.assertEquals(result.invalids[1].targetFinding.kind, "variantCandidateInvalid")
    lu.assertEquals(result.invalids[1].targetFinding.variantKey, "ThreeCombats")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "O", 2, "VariantKey")
    lu.assertEquals(states.ThreeCombats, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testFeedbackColorsSelectedBlankControlTargets()
    local feedback = historyFeedback.fromResult({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        biomeLookup = {
            F = {
                key = "F",
                label = "Erebus",
            },
        },
        findings = {},
        invalids = {
            {
                biomeKey = "F",
                rowIndex = 2,
                routeOrdinal = 2,
                tabKey = "rooms",
                code = "option_required",
                message = "Choose a room",
                completion = true,
                controlTargets = {
                    {
                        tabKey = "rooms",
                        controlAlias = "OptionKey",
                        mode = "selected",
                        state = valueStates.WARNING,
                    },
                },
            },
        },
    })

    local states = historyFeedback.valueStatesForControl(feedback, "F", 2, "OptionKey")
    lu.assertEquals(states[""], valueStates.WARNING)
    lu.assertEquals(feedback.route.primary.locationLabel, "Erebus Row 2")
    lu.assertEquals(feedback.route.primary.message, "Choose a room")
end

function TestRunPlannerRouteHistoryValidator.testRouteFeedbackLabelsChildAndRewardAddresses()
    local catalog = h.loadCatalog()
    local feedback = historyFeedback.fromResult({
        biomeLookup = catalog.lookup,
        invalids = {
            {
                biomeKey = "N",
                rowIndex = 4,
                formAddress = formAddress.child(4, "sideRoom", 1),
                tabKey = "rewards",
                address = "side:1",
                code = "talent_requires_spell",
            },
            {
                biomeKey = "H",
                rowIndex = 1,
                tabKey = "rewards",
                address = "cage:2",
                code = "talent_requires_spell",
            },
            {
                layer = "npcs",
                kind = "npcSelectionInvalid",
                rowIndex = 2,
                npcLabel = "Artemis",
                code = "npc_target_unavailable",
            },
        },
    })

    lu.assertEquals(feedback.route.markers[1].locationLabel, "Ephyra Row 4 Side 1 Reward")
    lu.assertEquals(feedback.route.markers[2].locationLabel, "Fields Row 1 Cage Reward 2")
    lu.assertEquals(feedback.route.markers[3].locationLabel, "NPC Artemis Row 2")
    lu.assertEquals(feedback.route.markers[3].message, "Artemis target is no longer valid")
end

function TestRunPlannerRouteHistoryValidator.testRouteNpcsSnapshotCarriesNpcLabels()
    local catalog = h.loadCatalog()
    local template = h.loadControlTemplates().RouteNpcs
    local instance = template.prepare({
        name = "RouteNpcsUnderworld",
        route = catalog.routes.lookup.Underworld,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local control = template.createRuntime(h.npcFields({
        {
            BiomeKey = "F",
            RowIndex = "4",
            VariantKey = "ArtemisCombatF",
        },
    }), instance)
    local snapshot = control:read("selectedNpcSnapshot")

    lu.assertEquals(snapshot.rows[1].npcKey, "Artemis")
    lu.assertEquals(snapshot.rows[1].npcLabel, "Artemis")
end

function TestRunPlannerRouteHistoryValidator.testRouteFeedbackTranslatesCandidateMessages()
    local feedback = historyFeedback.fromResult({
        invalids = {
            {
                biomeKey = "F",
                rowIndex = 2,
                code = "option_limit",
                targetFinding = {
                    kind = "roomCandidateInvalid",
                    reason = "option_limit",
                    optionKey = "F_Shop01",
                    candidate = {
                        optionLabel = "Midshop",
                    },
                },
            },
            {
                biomeKey = "F",
                rowIndex = 3,
                code = "role_limit",
                targetFinding = {
                    kind = "roomCandidateInvalid",
                    reason = "role_limit",
                    roleKey = "Story",
                    candidate = {
                        roleLabel = "Story",
                    },
                },
            },
            {
                biomeKey = "F",
                rowIndex = 4,
                code = "option_limit",
                targetFinding = {
                    kind = "roomCandidateInvalid",
                    reason = "option_limit",
                    optionKey = "F_Shop01",
                },
            },
            {
                biomeKey = "F",
                rowIndex = 5,
                code = "unexpected_candidate_reason",
            },
        },
    })

    lu.assertEquals(feedback.route.markers[1].message, "Midshop is already generated")
    lu.assertEquals(feedback.route.markers[2].message, "Story is already planned")
    lu.assertEquals(feedback.route.markers[3].message, "Room is already generated")
    lu.assertEquals(feedback.route.markers[4].message, "Selection is not valid")
end

function TestRunPlannerRouteHistoryValidator.testRouteFeedbackRejectsExplicitRouteMessages()
    lu.assertErrorMsgContains(
        "Unexpected explicit route validation message for code: option_limit",
        function()
            historyFeedback.fromResult({
                invalids = {
                    {
                        biomeKey = "F",
                        rowIndex = 2,
                        code = "option_limit",
                        message = "Custom rule message",
                        targetFinding = {
                            kind = "roomCandidateInvalid",
                            reason = "option_limit",
                            optionKey = "F_Shop01",
                            candidate = {
                                optionLabel = "Midshop",
                            },
                        },
                    },
                },
            })
        end
    )
end

function TestRunPlannerRouteHistoryValidator.testRouteFeedbackAllowsRewardLegalityMessages()
    local feedback = historyFeedback.fromResult({
        invalids = {
            {
                biomeKey = "F",
                rowIndex = 2,
                tabKey = "rewards",
                address = "row",
                code = "spell_drop_limit",
                message = "Selene's Gift is already planned earlier in this route",
                messageSource = "rewardLegality",
            },
        },
    })

    lu.assertEquals(
        feedback.route.primary.message,
        "Selene's Gift is already planned earlier in this route"
    )
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
        roleKey = fields and fields.roleKey or nil,
        optionKey = fields and fields.optionKey or nil,
        variantKey = fields and fields.variantKey or nil,
        variantLabel = fields and fields.variantLabel or nil,
        variantAvailability = fields and fields.variantAvailability or nil,
        topology = fields and fields.topology or nil,
        reward = fields and fields.reward or nil,
        roomCandidates = fields and fields.roomCandidates or nil,
        siblingCandidates = fields and fields.siblingCandidates or nil,
        rewardCandidates = fields and fields.rewardCandidates or nil,
        nextRoomTags = fields and fields.nextRoomTags or nil,
        tags = fields and fields.tags or nil,
        source = fields and fields.source or nil,
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
        controlAlias = fields and fields.controlAlias or nil,
        rewardClass = fields and fields.rewardClass or nil,
        rewardStore = fields and fields.rewardStore or nil,
        sourceValues = fields and fields.sourceValues or nil,
        lootName = fields and fields.lootName or nil,
    })
end

local function buildNpcTargets(history, catalog)
    return historySystem.npcCandidates.build({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        history = history,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
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

function TestRunPlannerRouteHistoryValidator.testNpcTargetsComeFromRouteHistoryRooms()
    local catalog = h.loadCatalog()
    local history = routeHistory.create()
    emitRoom(history, 4, {
        biomeKey = "F",
        rowIndex = 4,
        roomKey = "F_Combat04",
        roleKey = "Combat",
        biomeDepthCache = 4,
    })
    local npcTargets = buildNpcTargets(history, catalog)

    lu.assertNotNil(npcTargets.byNpc.Artemis.lookup["F:4:ArtemisCombatF"])

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        history = history,
        biomeLookup = catalog.lookup,
        npcSnapshot = {
            controlName = "RouteNpcsUnderworld",
            routeKey = "Underworld",
            rows = {
                {
                    rowIndex = 1,
                    npcKey = "Artemis",
                    groupKey = "FieldNpc",
                    mode = "Target",
                    biomeKey = "F",
                    targetRowIndex = "4",
                    variantKey = "ArtemisCombatF",
                },
            },
        },
        npcTargets = npcTargets,
        npcs = catalog.npcs,
    })

    lu.assertTrue(result.valid)
end

function TestRunPlannerRouteHistoryValidator.testNpcRequiredMessagesUseNpcLabels()
    local catalog = h.loadCatalog()
    local history = routeHistory.create()
    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        history = history,
        biomeLookup = catalog.lookup,
        npcSnapshot = {
            controlName = "RouteNpcsUnderworld",
            routeKey = "Underworld",
            rows = {
                {
                    rowIndex = 1,
                    npcKey = "Artemis",
                    npcLabel = "Artemis",
                    groupKey = "FieldNpc",
                    mode = "Target",
                },
            },
        },
        npcTargets = {
            byNpc = {},
        },
        npcs = catalog.npcs,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "npc_biome_required")
    lu.assertNil(result.invalids[1].message)

    local feedback = historyFeedback.fromResult({
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.locationLabel, "NPC Artemis Row 1")
    lu.assertEquals(feedback.route.primary.message, "Artemis needs Disabled or a target biome")
end

function TestRunPlannerRouteHistoryValidator.testNpcSpacingMessagesUseNpcLabels()
    local catalog = h.loadCatalog()
    local history = routeHistory.create()
    emitRoom(history, 4, {
        biomeKey = "F",
        rowIndex = 4,
        roomKey = "F_Combat04",
        roleKey = "Combat",
        biomeDepthCache = 4,
    })
    emitRoom(history, 5, {
        biomeKey = "F",
        rowIndex = 5,
        roomKey = "F_Combat05",
        roleKey = "Combat",
        biomeDepthCache = 5,
    })
    local npcTargets = buildNpcTargets(history, catalog)
    lu.assertNotNil(npcTargets.byNpc.Artemis.lookup["F:4:ArtemisCombatF"])
    lu.assertNotNil(npcTargets.byNpc.Nemesis.lookup["F:5:Combat"])

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        history = history,
        biomeLookup = catalog.lookup,
        npcSnapshot = {
            controlName = "RouteNpcsUnderworld",
            routeKey = "Underworld",
            rows = {
                {
                    rowIndex = 1,
                    npcKey = "Artemis",
                    npcLabel = "Artemis",
                    groupKey = "FieldNpc",
                    mode = "Target",
                    biomeKey = "F",
                    targetRowIndex = "4",
                    variantKey = "ArtemisCombatF",
                },
                {
                    rowIndex = 2,
                    npcKey = "Nemesis",
                    npcLabel = "Nemesis",
                    groupKey = "FieldNpc",
                    mode = "Target",
                    biomeKey = "F",
                    targetRowIndex = "5",
                    variantKey = "Combat",
                },
            },
        },
        npcTargets = npcTargets,
        npcs = catalog.npcs,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "npc_spacing")
    lu.assertNil(result.invalids[1].message)

    local feedback = historyFeedback.fromResult({
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.locationLabel, "NPC Nemesis Row 2")
    lu.assertEquals(feedback.route.primary.message, "Nemesis is too close to another planned NPC")
    lu.assertEquals(feedback.route.related[1].locationLabel, "NPC Artemis Row 1")
    lu.assertEquals(feedback.route.related[1].message, "Artemis is too close to another planned NPC")
end

function TestRunPlannerRouteHistoryValidator.testNpcTargetsRejectBannedRoomLoot()
    local catalog = h.loadCatalog()
    local history = routeHistory.create()
    local room = emitRoom(history, 4, {
        biomeKey = "F",
        rowIndex = 4,
        roomKey = "F_Combat04",
        roleKey = "Combat",
        biomeDepthCache = 4,
    })
    emitLoot(history, room, "Boon")

    local npcTargets = buildNpcTargets(history, catalog)

    lu.assertNil(npcTargets.byNpc.Artemis)
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
    lu.assertNil(result.invalids[1].message)

    local catalog = h.loadCatalog()
    local feedback = historyFeedback.fromResult({
        biomeLookup = catalog.lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    local states = historyFeedback.valueStatesForControl(feedback, "F", 3, "OptionKey")
    lu.assertEquals(states.F_Combat02, valueStates.INVALID)
    lu.assertEquals(feedback.route.primary.rowIndex, 3)
    lu.assertEquals(feedback.route.primary.routeOrdinal, 2)
    lu.assertEquals(feedback.route.primary.renderRowIndex, 2)
    lu.assertEquals(feedback.route.primary.renderRouteOrdinal, 1)
    lu.assertEquals(feedback.route.primary.locationLabel, "Erebus Depth 2")
    lu.assertEquals(feedback.route.primary.message, "C02 (2 Exits) is already generated")
end

function TestRunPlannerRouteHistoryValidator.testValidatorRejectsDuplicateCappedRole()
    local history = routeHistory.create()
    emitRoom(history, 1, {
        biomeKey = "N",
        rowIndex = 5,
        roomKey = "N_Story01",
        roleKey = "Story",
        optionKey = "N_Story01",
    })
    emitRoom(history, 2, {
        biomeKey = "N",
        rowIndex = 7,
        roomKey = "N_Story01",
        roleKey = "Story",
        optionKey = "N_Story01",
    })
    local catalog = h.loadCatalog()

    local result = historyValidator.validate({
        route = {
            key = "Surface",
            biomes = { "N" },
        },
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "role_limit")
    lu.assertEquals(result.invalids[1].rowIndex, 7)
    lu.assertNil(result.invalids[1].message)

    local feedback = historyFeedback.fromResult({
        biomeLookup = catalog.lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.message, "Story is already planned")
end

function TestRunPlannerRouteHistoryValidator.testValidatorRejectsMidshopAfterOneExitRoom()
    local history = routeHistory.create()
    emitRoom(history, 4, {
        biomeKey = "F",
        rowIndex = 5,
        roomKey = "F_Combat10",
        roleKey = "Combat",
        optionKey = "F_Combat10",
        topology = {
            selected = { roomKey = "F_Combat10" },
        },
    })
    emitRoom(history, 5, {
        biomeKey = "F",
        rowIndex = 6,
        roomKey = "F_Shop01",
        roleKey = "Midshop",
        optionKey = "F_Shop01",
        biomeDepthCache = 5,
    })
    local catalog = h.loadCatalog()

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "previous_room_exit_count")
    lu.assertNil(result.invalids[1].message)
    lu.assertEquals(result.invalids[1].requiredExitCount, 2)
    lu.assertEquals(result.invalids[1].actualExitCount, 1)
    lu.assertEquals(result.invalids[1].previousEntryLabel, "Combat")
    lu.assertEquals(result.invalids[1].currentEntryLabel, "Midshop")
    lu.assertEquals(result.invalids[1].rowIndex, 6)
    lu.assertEquals(result.invalids[1].roomKey, "F_Shop01")

    local feedback = historyFeedback.fromResult({
        biomeLookup = catalog.lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.message, "Combat exit count is 1; Midshop requires 2")
end

function TestRunPlannerRouteHistoryValidator.testUnknownRouteRequirementFailsContract()
    local history = routeHistory.create()
    emitRoom(history, 1, {
        biomeKey = "X",
        rowIndex = 1,
        roomKey = "X_Room01",
        roleKey = "Room",
        optionKey = "X_Room01",
    })

    lu.assertErrorMsgContains("Unknown route requirement kind: unsupportedRequirement", function()
        historyValidator.validate({
            route = {
                key = "TestRoute",
                biomes = { "X" },
            },
            history = history,
            biomeLookup = {
                X = {
                    key = "X",
                    rolesByKey = {
                        Room = {
                            key = "Room",
                            routeRequirements = {
                                {
                                    kind = "unsupportedRequirement",
                                },
                            },
                        },
                    },
                },
            },
        })
    end)
end

function TestRunPlannerRouteHistoryValidator.testValidatorAcceptsMidshopAfterTwoExitRoom()
    local history = routeHistory.create()
    emitRoom(history, 4, {
        biomeKey = "F",
        rowIndex = 5,
        roomKey = "F_Combat04",
        roleKey = "Combat",
        optionKey = "F_Combat04",
        topology = {
            selected = { roomKey = "F_Combat04" },
            sibling = { roomKey = "F_Combat05" },
        },
    })
    emitRoom(history, 5, {
        biomeKey = "F",
        rowIndex = 6,
        roomKey = "F_Shop01",
        roleKey = "Midshop",
        optionKey = "F_Shop01",
        biomeDepthCache = 5,
    })
    local catalog = h.loadCatalog()

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertTrue(result.valid)
end

function TestRunPlannerRouteHistoryValidator.testValidatorRejectsRoomWithoutPreviousNextRoomTag()
    local history = routeHistory.create()
    emitRoom(history, 4, {
        biomeKey = "P",
        rowIndex = 5,
        roomKey = "P_MiniBoss02",
        roleKey = "Miniboss",
        optionKey = "P_MiniBoss02",
        biomeDepthCache = 4,
    })
    emitRoom(history, 5, {
        biomeKey = "P",
        rowIndex = 6,
        roomKey = "P_Combat02",
        roleKey = "Combat",
        optionKey = "P_Combat02",
        biomeDepthCache = 5,
    })
    local catalog = h.loadCatalog()

    local result = historyValidator.validate({
        route = {
            key = "Surface",
            biomes = { "P" },
        },
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "previous_room_next_tags")
    lu.assertEquals(result.invalids[1].rowIndex, 6)
    lu.assertNil(result.invalids[1].message)

    local feedback = historyFeedback.fromResult({
        biomeLookup = catalog.lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    local states = historyFeedback.valueStatesForControl(feedback, "P", 6, "OptionKey")
    lu.assertEquals(states.P_Combat02, valueStates.INVALID)
    lu.assertEquals(feedback.route.primary.message, "Previous planned room only leads to Outdoor rooms")
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
            OptionKey = "F_Combat02",
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

function TestRunPlannerRouteHistoryValidator.testFixedLinearPickedDoorRoleUsesNextChoiceDepth()
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
    })

    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })
    local feedback = historyFeedback.fromFindings(result.findings)

    local depthThreePickedRoleStates = historyFeedback.valueStatesForControl(feedback, "F", 5, "RoleKey")
    lu.assertEquals(depthThreePickedRoleStates.Story, valueStates.HIDDEN)
end

function TestRunPlannerRouteHistoryValidator.testFixedLinearPickedDoorUsesGeneratedDepthAtMaxBoundary()
    local route = {
        key = "Underworld",
        biomes = { "F" },
    }
    local rows = {
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
    }
    for rowIndex = 2, 11 do
        rows[rowIndex] = {
            RoleKey = "Combat",
            OptionKey = "F_Combat" .. string.format("%02d", rowIndex - 1),
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        }
    end
    local history, catalog = buildHistory(route, "F", h.loadFixedLinearTemplate(), rows)

    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })
    local feedback = historyFeedback.fromFindings(result.findings)

    local generatedAtMaxRoleStates = historyFeedback.valueStatesForControl(feedback, "F", 10, "RoleKey")
    local generatedAfterMaxRoleStates = historyFeedback.valueStatesForControl(feedback, "F", 11, "RoleKey")
    lu.assertNil(generatedAtMaxRoleStates and generatedAtMaxRoleStates.Fountain)
    lu.assertEquals(generatedAfterMaxRoleStates.Fountain, valueStates.HIDDEN)
end

function TestRunPlannerRouteHistoryValidator.testCandidateValidatorEmitsEncounterDepthRoomFindings()
    local history = routeHistory.create()
    emitRoom(history, 3, {
        biomeKey = "F",
        rowIndex = 3,
        roomKey = "F_Combat02",
        roleKey = "Combat",
        optionKey = "F_Combat02",
        biomeEncounterDepth = 3,
        roomCandidates = {
            {
                roleKey = "Combat",
                optionKey = "F_Combat05",
                roomKey = "F_Combat05",
                optionAvailability = {
                    biomeEncounterDepth = { min = 4 },
                },
                availabilityContext = {
                    biomeEncounterDepth = 3,
                },
            },
        },
    })

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = {},
        },
        history = history,
        biomeLookup = {},
    })

    local finding = firstFinding(result, "roomCandidateInvalid", "roomKey", "F_Combat05")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "encounter_depth_unavailable")
    lu.assertEquals(finding.axis, "biomeEncounterDepth")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "F", 3, "OptionKey")
    lu.assertEquals(states.F_Combat05, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testCandidateAvailabilityRequiresExplicitContext()
    local history = routeHistory.create()
    emitRoom(history, 3, {
        biomeKey = "F",
        rowIndex = 3,
        roomKey = "F_Story01",
        roleKey = "Story",
        optionKey = "F_Story01",
        biomeDepthCache = 3,
        roomCandidates = {
            {
                roleKey = "Story",
                optionKey = "F_Story01",
                roomKey = "F_Story01",
                optionAvailability = {
                    biomeDepthCache = { min = 4 },
                },
            },
        },
    })

    lu.assertErrorMsgContains("candidate availabilityContext is required", function()
        validateHistory(history)
    end)
end

function TestRunPlannerRouteHistoryValidator.testSelectedRoomCandidateInvalidBlocksRoute()
    local history = routeHistory.create()
    emitRoom(history, 3, {
        biomeKey = "F",
        rowIndex = 3,
        roomKey = "F_Story01",
        roleKey = "Story",
        optionKey = "F_Story01",
        biomeDepthCache = 3,
        roomCandidates = {
            {
                roleKey = "Story",
                optionKey = "F_Story01",
                roomKey = "F_Story01",
                optionAvailability = {
                    biomeDepthCache = { min = 4 },
                },
                availabilityContext = {
                    biomeDepthCache = 3,
                },
                targetRowIndex = 3,
            },
        },
    })

    local result = validateHistory(history)

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "biome_depth_unavailable")
    lu.assertEquals(result.invalids[1].rowIndex, 3)
    lu.assertEquals(result.invalids[1].targetFinding.kind, "roomCandidateInvalid")
    lu.assertEquals(result.invalids[1].targetFinding.roomKey, "F_Story01")
end

function TestRunPlannerRouteHistoryValidator.testSelectedCandidateUsesFormAddressNotLastRowEntry()
    local history = routeHistory.create()
    routeHistory.emitAt(history, {
        routeKey = "Surface",
        biomeKey = "N",
        routeBiomeIndex = 1,
        rowIndex = 4,
        formAddress = formAddress.row(4),
        roomHistoryOrdinal = 4,
        biomeDepthCache = 3,
    }, {
        kind = "room",
        eventKey = "N_Combat12",
        roomKey = "N_Combat12",
        roleKey = "Combat",
        optionKey = "N_Combat12",
        roomCandidates = {
            {
                roleKey = "Combat",
                optionKey = "N_Combat12",
                roomKey = "N_Combat12",
                optionAvailability = {
                    biomeDepthCache = { min = 4 },
                },
                availabilityContext = {
                    biomeDepthCache = 3,
                },
            },
        },
    })
    routeHistory.emitAt(history, {
        routeKey = "Surface",
        biomeKey = "N",
        routeBiomeIndex = 1,
        rowIndex = 4,
        formAddress = formAddress.child(4, "sideRoom", 1),
        roomHistoryOrdinal = 5,
        biomeDepthCache = 4,
    }, {
        kind = "room",
        eventKey = "N_Sub09",
        roomKey = "N_Sub09",
        roleKey = "SideRoom",
    })
    routeHistory.emitAt(history, {
        routeKey = "Surface",
        biomeKey = "N",
        routeBiomeIndex = 1,
        rowIndex = 4,
        formAddress = formAddress.child(4, "hubReturn"),
        roomHistoryOrdinal = 6,
        biomeDepthCache = 5,
    }, {
        kind = "room",
        eventKey = "N_Hub",
        roomKey = "N_Hub",
        roleKey = "Hub",
    })

    local result = validateHistory(history)

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "biome_depth_unavailable")
    lu.assertEquals(result.invalids[1].roomKey, "N_Combat12")
    lu.assertEquals(result.invalids[1].formAddress, formAddress.row(4))
end

function TestRunPlannerRouteHistoryValidator.testHubGeneratedDoorOfferUsesHubTimingForRewardLegality()
    local rows = ephyraRows()
    rows[4].Reward1Key = "SpellDrop"
    local route = {
        key = "Surface",
        biomes = { "N" },
    }
    local history, catalog = buildHistory(route, "N", h.loadHubPylonTemplate(), rows)

    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "spell_drop_limit")
    lu.assertEquals(result.invalids[1].rowIndex, 4)
    lu.assertEquals(result.invalids[1].roomHistoryOrdinal, 3)
    lu.assertEquals(result.invalids[1].entry.timing, "generatedOffer")
    lu.assertEquals(result.invalids[1].entry.eventSourceKind, "hubGeneratedDoor")
    lu.assertEquals(result.invalids[1].entry.parentEntry.roomKey, "N_Hub")
    lu.assertEquals(result.invalids[1].entry.parentRoomKey, "N_Combat12")

    local feedback = historyFeedback.fromResult({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.locationLabel, "Ephyra Row 4 Generated Offer Rewards")
end

function TestRunPlannerRouteHistoryValidator.testHubGeneratedDoorAcquisitionDoesNotRevalidateRewardLegality()
    local rows = ephyraRows()
    rows[1].Reward1Key = "MaxHealthDrop"
    rows[4].Reward1Key = "SpellDrop"
    rows[7].Reward1Key = "SpellDrop"
    local route = {
        key = "Surface",
        biomes = { "N" },
    }
    local history, catalog = buildHistory(route, "N", h.loadHubPylonTemplate(), rows)

    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertTrue(result.valid)
    lu.assertEquals(routeHistory.lootEntries(history, "SpellDrop")[1].legalityValidatedBy, "hubGeneratedOffer")
    lu.assertEquals(routeHistory.lootEntries(history, "SpellDrop")[2].legalityValidatedBy, "hubGeneratedOffer")
end

function TestRunPlannerRouteHistoryValidator.testEarlierSelectedCandidateInvalidBeatsLaterRewardInvalid()
    local history = routeHistory.create()
    emitRoom(history, 3, {
        biomeKey = "F",
        rowIndex = 3,
        roomKey = "F_Story01",
        roleKey = "Story",
        optionKey = "F_Story01",
        biomeDepthCache = 3,
        roomCandidates = {
            {
                roleKey = "Story",
                optionKey = "F_Story01",
                roomKey = "F_Story01",
                optionAvailability = {
                    biomeDepthCache = { min = 4 },
                },
                availabilityContext = {
                    biomeDepthCache = 3,
                },
                targetRowIndex = 3,
            },
        },
    })
    local lateRoom = emitRoom(history, 9, {
        biomeKey = "F",
        rowIndex = 9,
        roomKey = "F_Combat09",
        roleKey = "Combat",
        optionKey = "F_Combat09",
    })
    emitLoot(history, lateRoom, "TalentDrop")

    local result = validateHistory(history)

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "biome_depth_unavailable")
    lu.assertEquals(result.invalids[1].rowIndex, 3)
end

function TestRunPlannerRouteHistoryValidator.testCandidateValidatorEmitsRoleCapFindings()
    local history = routeHistory.create()
    emitRoom(history, 1, {
        biomeKey = "F",
        rowIndex = 1,
        roomKey = "F_Story01",
        roleKey = "Story",
        optionKey = "F_Story01",
    })
    emitRoom(history, 2, {
        biomeKey = "F",
        rowIndex = 2,
        roomKey = "F_Combat01",
        roleKey = "Combat",
        optionKey = "F_Combat01",
        roomCandidates = {
            {
                roleKey = "Story",
                optionKey = "F_Story01",
                roomKey = "F_Story01",
                maxSelectionsPerBiome = 1,
            },
        },
    })

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = {},
        },
        history = history,
        biomeLookup = {},
    })

    local finding = firstFinding(result, "roomCandidateInvalid", "roleKey", "Story")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "role_limit")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "F", 2, "RoleKey")
    lu.assertEquals(states.Story, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testCandidateValidatorEmitsOptionCapFindings()
    local history = routeHistory.create()
    emitRoom(history, 1, {
        biomeKey = "F",
        rowIndex = 1,
        roomKey = "F_Combat02",
        roleKey = "Combat",
        optionKey = "F_Combat02",
    })
    emitRoom(history, 2, {
        biomeKey = "F",
        rowIndex = 2,
        roomKey = "F_Combat03",
        roleKey = "Combat",
        optionKey = "F_Combat03",
        roomCandidates = {
            {
                roleKey = "Combat",
                optionKey = "F_Combat02",
                roomKey = "F_Combat02",
                optionMaxCreationsThisRun = 1,
            },
        },
    })

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = {},
        },
        history = history,
        biomeLookup = {},
    })

    local finding = firstFinding(result, "roomCandidateInvalid", "roomKey", "F_Combat02")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "option_limit")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "F", 2, "OptionKey")
    lu.assertEquals(states.F_Combat02, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testCandidateValidatorEmitsNextRoomTagFindings()
    local route = {
        key = "Surface",
        biomes = { "P" },
    }
    local history, catalog = buildHistory(route, "P", h.loadFixedLinearTemplate(), {
        {},
        { RoleKey = "Combat", OptionKey = "P_Combat05" },
        { RoleKey = "Combat", OptionKey = "P_Combat06" },
        { RoleKey = "Combat", OptionKey = "P_Combat11" },
        { RoleKey = "Miniboss", OptionKey = "P_MiniBoss02" },
        { RoleKey = "Combat", OptionKey = "P_Combat13" },
    })
    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })

    local finding = nil
    for _, candidateFinding in ipairs(result.findings) do
        if candidateFinding.kind == "roomCandidateInvalid"
            and candidateFinding.roomKey == "P_Combat02"
            and candidateFinding.reason == "previous_room_next_tags"
        then
            finding = candidateFinding
            break
        end
    end
    lu.assertNotNil(finding)

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "P", 6, "OptionKey")
    lu.assertEquals(states.P_Combat02, valueStates.INVALID)
    lu.assertNil(states.P_Combat13)
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
            OptionKey = "F_Combat02",
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

function TestRunPlannerRouteHistoryValidator.testSelectedSiblingCannotUsePickedNextRoom()
    local history = routeHistory.create()
    emitRoom(history, 1, {
        rowIndex = 1,
        roomKey = "F_Opening01",
        roleKey = "Opening",
        optionKey = "F_Opening01",
        topology = {
            exits = {
                {
                    branch = "picked",
                    roomKey = "F_Combat01",
                },
            },
        },
    })
    emitRoom(history, 2, {
        rowIndex = 2,
        roomKey = "F_Combat01",
        roleKey = "Combat",
        optionKey = "F_Combat01",
        source = {
            topology = {
                siblings = {
                    {
                        structureKey = "F_Combat02",
                    },
                },
            },
        },
        topology = {
            exits = {
                {
                    branch = "picked",
                    roomKey = "F_Combat02",
                },
                {
                    branch = "sibling",
                    siblingIndex = 1,
                    structureKey = "F_Combat02",
                    roomKey = "F_Combat02",
                },
            },
        },
        siblingCandidates = {
            {
                siblingIndex = 1,
                structureKey = "F_Combat02",
                roomKey = "F_Combat02",
            },
        },
    })
    emitRoom(history, 3, {
        rowIndex = 3,
        roomKey = "F_Combat02",
        roleKey = "Combat",
        optionKey = "F_Combat02",
    })

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        history = history,
        biomeLookup = {},
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "sibling_room_planned")
    lu.assertNil(result.invalids[1].message)
    lu.assertNil(result.invalids[1].targetFinding.message)
    lu.assertEquals(result.invalids[1].rowIndex, 2)

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    lu.assertEquals(feedback.route.primary.message, "Other Door room is already planned on this route")
    local states = historyFeedback.valueStatesForControl(feedback, "F", 2, "SiblingStructureKey")
    lu.assertEquals(states.F_Combat02, valueStates.INVALID)
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
    lu.assertEquals(finding.message, "Path of Stars rewards require an earlier Selene's Gift")
    lu.assertEquals(finding.messageSource, "rewardLegality")
    lu.assertEquals(finding.rewardClass, "Major")

    local feedback = historyFeedback.fromFindings(result.findings)
    local states = historyFeedback.valueStatesForControl(feedback, "F", 1, "Reward2Key", "row")
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
    local states = historyFeedback.valueStatesForControl(feedback, "H", 1, "Reward2Key", "cage:2")
    lu.assertEquals(states.TalentDrop, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testRewardFeedbackScopesStatesByAddress()
    local history = routeHistory.create()
    emitRoom(history, 1, {
        rewardCandidates = {
            {
                kind = "rewardType",
                address = "row",
                rewardStore = "RunProgress",
                rewardTypes = { "TalentDrop" },
            },
            {
                kind = "rewardType",
                address = "side:1",
                rewardStore = "RunProgress",
                rewardTypes = { "MinorTalentDrop" },
            },
        },
    })

    local result = validateHistory(history)
    local feedback = historyFeedback.fromFindings(result.findings)
    local rowStates = historyFeedback.valueStatesForControl(feedback, "F", 1, "Reward1Key", "row")
    local sideStates = historyFeedback.valueStatesForControl(feedback, "F", 1, "Reward1Key", "side:1")

    lu.assertEquals(rowStates.TalentDrop, valueStates.INVALID)
    lu.assertNil(rowStates.MinorTalentDrop)
    lu.assertEquals(sideStates.MinorTalentDrop, valueStates.INVALID)
    lu.assertNil(sideStates.TalentDrop)
end

function TestRunPlannerRouteHistoryValidator.testSelectedRewardInvalidPreservesControlTarget()
    local history = routeHistory.create()
    local room = emitRoom(history, 1)
    emitLoot(history, room, "TalentDrop", {
        address = "row",
        controlAlias = "Reward2Key",
        rewardClass = "Major",
        rewardStore = "RunProgress",
    })

    local result = validateHistory(history)
    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].controlAlias, "Reward2Key")
    lu.assertEquals(result.invalids[1].rewardClass, "Major")

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    local states = historyFeedback.valueStatesForControl(feedback, "F", 1, "Reward2Key", "row")
    lu.assertEquals(states.TalentDrop, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testPickedVariantDepthUsesCatalogMessage()
    local history = routeHistory.create()
    emitRoom(history, 2, {
        biomeKey = "H",
        rowIndex = 2,
        roomKey = "H_Combat04",
        roleKey = "Combat",
        optionKey = "H_Combat04",
        variantKey = "ThreeRewards",
        variantLabel = "3 Slots",
        variantAvailability = { exact = 3 },
        biomeDepthCache = 2,
        biomeEncounterDepth = 2,
    })
    local catalog = h.loadCatalog()

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = { "H" },
        },
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "variant_encounter_depth_unavailable")
    lu.assertNil(result.invalids[1].message)

    local feedback = historyFeedback.fromResult({
        biomeLookup = catalog.lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.message, "3 Slots is not valid at this encounter depth")
    local states = historyFeedback.valueStatesForControl(feedback, "H", 2, "VariantKey")
    lu.assertEquals(states.ThreeRewards, valueStates.INVALID)
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
    lu.assertNil(result.invalids[1].message)
    lu.assertEquals(result.invalids[1].topologyForceLabel, "Echo")
    lu.assertEquals(result.invalids[1].generatedCount, 0)
    lu.assertEquals(result.invalids[1].requiredGeneratedCount, 2)
    lu.assertEquals(result.invalids[1].biomeKey, "H")
    lu.assertEquals(result.invalids[1].roomKey, "H_Combat09")

    local feedback = historyFeedback.fromResult({
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.message, "Echo was not generated by depth 3 (0/2 force-window doors generated)")
end

function TestRunPlannerRouteHistoryValidator.testForceGroupUsesDeclarationLabelMessage()
    local catalog = h.loadCatalog()
    local history = routeHistory.create()
    emitRoom(history, 6, {
        biomeKey = "F",
        rowIndex = 6,
        roomKey = "F_Combat06",
        roleKey = "Combat",
        optionKey = "F_Combat06",
        biomeDepthCache = 6,
        biomeEncounterDepth = 6,
        topology = {
            exits = {
                {
                    branch = "picked",
                    roomKey = "F_Combat06",
                },
                {
                    branch = "sibling",
                    siblingIndex = 1,
                    roomKey = "F_Combat07",
                },
            },
        },
    })

    local result = historyValidator.validate({
        route = {
            key = "Underworld",
            biomes = { "F" },
        },
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "forced_topology_group_unresolved")
    lu.assertNil(result.invalids[1].message)
    lu.assertEquals(result.invalids[1].topologyGroupKey, "F_Shop")
    lu.assertEquals(result.invalids[1].topologyGroupLabel, "Midshop")
    lu.assertEquals(result.invalids[1].deadlineBiomeDepthCache, 6)
    lu.assertEquals(result.invalids[1].generatedCount, 0)
    lu.assertEquals(result.invalids[1].requiredGeneratedCount, 1)

    local feedback = historyFeedback.fromResult({
        biomeLookup = catalog.lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertEquals(feedback.route.primary.message, "Midshop generated 0/1 required doors by depth 6")
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
            SiblingStructureKey = "Bridge",
            Reward1Key = "Boon",
            Reward1LootKey = "HestiaUpgrade",
            Reward2Key = "WeaponUpgrade",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "H_MiniBoss01",
            SiblingStructureKey = "H_MiniBoss02",
            Reward1Key = "Boon",
            Reward1LootKey = "DemeterUpgrade",
        },
    })

    lu.assertTrue(result.valid)
end

function TestRunPlannerRouteHistoryValidator.testValidatorRejectsMismatchedFieldsCombatCageCounts()
    local route = {
        key = "Underworld",
        biomes = { "H" },
    }
    local result = validate(route, "H", h.loadFieldsCageTemplate(), {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "ThreeRewards",
            SiblingStructureKey = "CombatCage2",
            Reward1Key = "Boon",
            Reward1LootKey = "PoseidonUpgrade",
            Reward2Key = "StackUpgrade",
            Reward3Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat09",
            VariantKey = "TwoRewards",
            SiblingStructureKey = "Bridge",
            Reward1Key = "Boon",
            Reward1LootKey = "HestiaUpgrade",
            Reward2Key = "WeaponUpgrade",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "H_MiniBoss01",
            SiblingStructureKey = "H_MiniBoss02",
            Reward1Key = "Boon",
            Reward1LootKey = "DemeterUpgrade",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "fields_sibling_combat_cage_count_mismatch")
    lu.assertNil(result.invalids[1].message)
    lu.assertEquals(result.invalids[1].targetFinding.structureKey, "CombatCage2")
    lu.assertNil(result.invalids[1].targetFinding.message)

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    lu.assertEquals(feedback.route.primary.message, "Other Door combat reward count must match Picked Door")
    local states = historyFeedback.valueStatesForControl(feedback, "H", 2, "SiblingStructureKey")
    lu.assertEquals(states.CombatCage2, valueStates.INVALID)
    lu.assertNil(states.CombatCage3)
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
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat04",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_preboss_too_early")
    lu.assertNil(result.invalids[1].message)
    lu.assertEquals(result.invalids[1].targetFinding.structureKey, "Preboss")
    lu.assertNil(result.invalids[1].targetFinding.message)

    local finding = firstFinding(result, "siblingCandidateInvalid", "structureKey", "Preboss")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "clockwork_preboss_too_early")
    lu.assertNil(finding.message)

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    lu.assertEquals(
        feedback.route.primary.message,
        "Tartarus Preboss cannot appear before Clockwork goals are complete"
    )
    local states = historyFeedback.valueStatesForControl(feedback, "I", finding.rowIndex, "SiblingStructureKey")
    lu.assertEquals(states.Preboss, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testClockworkRejectsPickedPrebossBeforeGoalsComplete()
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
            RouteKindKey = "Preboss",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_preboss_too_early")
    lu.assertNil(result.invalids[1].message)
    lu.assertEquals(result.invalids[1].targetFinding.clockworkControl, "routeKind")
    lu.assertEquals(result.invalids[1].targetFinding.clockworkValue, "Preboss")
    lu.assertNil(result.invalids[1].targetFinding.message)

    local feedback = historyFeedback.fromResult({
        route = route,
        biomeLookup = h.loadCatalog().lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertEquals(
        feedback.route.primary.message,
        "Tartarus Preboss cannot appear before Clockwork goals are complete"
    )
    local states = historyFeedback.valueStatesForControl(feedback, "I", 2, "RouteKindKey")
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
    lu.assertNil(result.invalids[1].message)

    local finding = firstFinding(result, "siblingCandidateInvalid", "structureKey", "CombatReward")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "clockwork_goal_door_count")
    lu.assertNil(finding.message)

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    lu.assertEquals(
        feedback.route.primary.message,
        "Tartarus generated doors need exactly one Goal Room before Clockwork goals are complete"
    )
end

function TestRunPlannerRouteHistoryValidator.testClockworkRequiresSingleDoorGoalBeforeComplete()
    local catalog = h.loadCatalog()
    local history = routeHistory.create()
    emitRoom(history, 2, {
        biomeKey = "I",
        rowIndex = 2,
        roomKey = "I_Story01",
        roleKey = "Story",
        optionKey = "I_Story01",
        topology = {
            exits = {},
        },
    })
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_single_door_goal_required")
    lu.assertNil(result.invalids[1].message)
    lu.assertNil(result.invalids[1].targetFinding.message)

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    lu.assertEquals(
        feedback.route.primary.message,
        "Tartarus single doors need Goal Room before Clockwork goals are complete"
    )
end

function TestRunPlannerRouteHistoryValidator.testClockworkFeedbackMapsNonGoalKindFinding()
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local history, catalog = buildHistory(route, "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat02",
        },
        {
            RouteKindKey = "NonGoal",
            NonGoalKindKey = "Story",
            OptionKey = "I_Story01",
        },
    })
    local result = historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_goal_door_count")

    local feedback = historyFeedback.fromResult({
        route = route,
        biomeLookup = catalog.lookup,
        findings = result.findings,
        invalids = result.invalids,
    })
    local states = historyFeedback.valueStatesForControl(feedback, "I", 2, "NonGoalKindKey")
    lu.assertEquals(states.Story, valueStates.INVALID)
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
            SiblingStructureKey = "I_Story01",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat10",
            SiblingStructureKey = "I_MiniBoss01",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat11",
            SiblingStructureKey = "I_MiniBoss02",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat12",
            SiblingStructureKey = "CombatReward",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_preboss_required")
    lu.assertNil(result.invalids[1].message)

    local finding = firstFinding(result, "roomCandidateInvalid", "clockworkValue", "Goal")
    lu.assertNotNil(finding)
    lu.assertEquals(finding.reason, "clockwork_preboss_required")
    lu.assertNil(finding.message)

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    lu.assertEquals(feedback.route.primary.message, "Tartarus post-goal doors need Preboss")
end

function TestRunPlannerRouteHistoryValidator.testClockworkNeedsPickedPrebossAfterFinalSingleDoorGoal()
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local result = validate(route, "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "I_Story01",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat04",
            SiblingStructureKey = "I_MiniBoss01",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat09",
            SiblingStructureKey = "I_MiniBoss02",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat10",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat11",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat12",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "clockwork_preboss_required")
    lu.assertEquals(result.invalids[1].rowIndex, 6)
end

function TestRunPlannerRouteHistoryValidator.testClockworkPickedPrebossEndsRoute()
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
            SiblingStructureKey = "I_Story01",
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
            RouteKindKey = "Preboss",
        },
        {
            RouteKindKey = "NonGoal",
            NonGoalKindKey = "Story",
            OptionKey = "I_Story01",
        },
    })

    lu.assertTrue(result.valid)
    lu.assertNil(firstFinding(result, "rowInactiveBoundary", "rowIndex", 7))
end

function TestRunPlannerRouteHistoryValidator.testClockworkAllowsNonGoalGoalThenGoalRewardBeforePreboss()
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local result = validate(route, "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat04",
            SiblingStructureKey = "I_Story01",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat09",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat10",
            SiblingStructureKey = "CombatGoal",
        },
        {
            RouteKindKey = "NonGoal",
            NonGoalKindKey = "Miniboss",
            OptionKey = "I_MiniBoss02",
        },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat11",
            SiblingStructureKey = "CombatReward",
        },
        {
            RouteKindKey = "Preboss",
        },
    })

    lu.assertTrue(result.valid)
end

function TestRunPlannerRouteHistoryValidator.testClockworkTopologyUsesPickedNextRoomAsSelectedDoor()
    local route = {
        key = "Underworld",
        biomes = { "I" },
    }
    local history = buildHistory(route, "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatGoal",
        },
        {
            RouteKindKey = "NonGoal",
            NonGoalKindKey = "Story",
            OptionKey = "I_Story01",
        },
    })

    local rowTwo
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        if entry.biomeKey == "I" and entry.rowIndex == 2 then
            rowTwo = entry
            break
        end
    end

    lu.assertNotNil(rowTwo)
    lu.assertEquals(rowTwo.topology.selected.structure, "Story")
    lu.assertEquals(rowTwo.topology.selected.roomKey, "I_Story01")
    lu.assertEquals(rowTwo.topology.sibling.structure, "GoalCombat")
    lu.assertTrue(rowTwo.topology.sibling.isClockworkGoal)
end

function TestRunPlannerRouteHistoryValidator.testRewardValidatorRejectsTalentBeforeSpell()
    local history = routeHistory.create()
    local room = emitRoom(history, 1)
    emitLoot(history, room, "TalentDrop")

    local result = validateHistory(history)

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "talent_requires_spell")
    lu.assertEquals(result.invalids[1].message, "Path of Stars rewards require an earlier Selene's Gift")
    lu.assertEquals(result.invalids[1].messageSource, "rewardLegality")
    lu.assertEquals(result.invalids[1].rewardType, "TalentDrop")
    lu.assertEquals(result.invalids[1].roomKey, "Room1")

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    lu.assertEquals(feedback.route.primary.message, "Path of Stars rewards require an earlier Selene's Gift")
    local states = historyFeedback.valueStatesForControl(feedback, "F", 1, "Reward1Key", "row")
    lu.assertEquals(states.TalentDrop, valueStates.INVALID)
end

function TestRunPlannerRouteHistoryValidator.testUnknownSelectedLegalityRequirementFailsContract()
    local localHistorySystem = h.withTestImport(function()
        return h.testImport("mods/route/history/assembly.lua").create({
            selectedLegalityRules = {
                {
                    targets = { "TalentDrop" },
                    requirements = {
                        {
                            kind = "unsupportedSelectedRequirement",
                        },
                    },
                },
            },
        })
    end)
    local history = localHistorySystem.history.create()
    local room = localHistorySystem.history.emit(history, {
        kind = "room",
        eventKey = "Room1",
        roomKey = "Room1",
        biomeKey = "F",
        rowIndex = 1,
    })
    localHistorySystem.history.emitAt(history, room, {
        kind = "loot",
        eventKey = "TalentDrop",
        lootType = "TalentDrop",
        parentEntry = room,
        parentRoomKey = room.roomKey,
        address = "row",
    })

    lu.assertErrorMsgContains(
        "Unknown selected-legality requirement kind: unsupportedSelectedRequirement",
        function()
            localHistorySystem.validator.validate({
                route = {
                    key = "Underworld",
                    biomes = {},
                },
                history = history,
                biomeLookup = {},
            })
        end
    )
end

function TestRunPlannerRouteHistoryValidator.testRewardValidatorTreatsFieldsCageAsSameBatch()
    local history = routeHistory.create()
    local room = emitRoom(history, 1, {
        roomKey = "H_Combat04",
        biomeKey = "H",
        reward = {
            kind = "fieldsCages",
            rewardStore = "RunProgress",
            sameExitRewardCount = 2,
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

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    local states = historyFeedback.valueStatesForControl(feedback, "H", 1, "Reward2Key", "cage:2")
    lu.assertEquals(states.TalentBigDrop, valueStates.INVALID)
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
    lu.assertEquals(result.invalids[1].messageSource, "rewardLegality")
    lu.assertEquals(result.invalids[1].rewardType, "Devotion")

    local feedback = historyFeedback.fromFindings(result.findings, result.invalids)
    lu.assertEquals(feedback.route.primary.message, "Trial requires a two-exit previous room")
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

    local feedback = historyFeedback.fromResult({
        route = {
            key = "Underworld",
            biomes = { "F", "G" },
        },
        findings = result.findings,
        invalids = result.invalids,
    })
    lu.assertFalse(feedback.route.valid)
    lu.assertEquals(feedback.route.primary.code, "devotion_spacing")
    lu.assertEquals(feedback.route.primary.markerKind, "primary")
    lu.assertEquals(feedback.route.related[1].lootType, "Devotion")
    lu.assertEquals(feedback.route.related[1].markerKind, "related")
    lu.assertEquals(#feedback.route.markers, 2)
end

function TestRunPlannerRouteHistoryValidator.testErebusTopologyControlsAreActiveAtFirstGeneratedRoom()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local history = buildHistory(catalog.routes.lookup.Underworld, "F", template, {
        {
            RoleKey = "Opening",
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
        },
    })

    local feedback = historyFeedback.fromResult({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        history = history,
        findings = {},
        invalids = {},
    })

    lu.assertEquals(routeHistory.byKind(history, "room")[2].biomeDepthCache, 1)
    lu.assertTrue(feedback.byBiome.F[2].topology.active)
    lu.assertTrue(feedback.byBiome.F[2].topology.controlsActive)
end
