local lu = require("luaunit")
local h = require("tests.support.control_harness")
local importHarness = require("tests.support.import_harness")

local historySystem = h.withTestImport(function()
    return h.testImport("mods/route/history/assembly.lua").create({
        rewardDomain = importHarness.loadRewardDomain(),
    })
end)
local routeHistory = historySystem.history
local historyBuilder = historySystem.builder
local walker = historySystem.walker

-- luacheck: globals TestRunPlannerRouteHistoryWalker
TestRunPlannerRouteHistoryWalker = {}

local function roomEvents(history)
    return routeHistory.byKind(history, "room")
end

local function findCandidate(candidates, field, expected)
    for _, candidate in ipairs(candidates or {}) do
        if candidate[field] == expected then
            return candidate
        end
    end
    return nil
end

local function assertPhaseEquals(actual, expected)
    lu.assertEquals(actual.biomeDepthCache, expected.biomeDepthCache)
    lu.assertEquals(actual.biomeEncounterDepth, expected.biomeEncounterDepth)
    lu.assertEquals(actual.runEncounterDepth, expected.runEncounterDepth)
    lu.assertEquals(actual.runDepthCache, expected.runDepthCache)
    lu.assertEquals(actual.roomHistoryOrdinal, expected.roomHistoryOrdinal)
end

local function buildTemplateHistory(catalog, routeKey, biomeKey, template, rows, encounterRewardRows)
    local instance = template.prepare({
        name = "Route" .. biomeKey,
        biome = catalog.lookup[biomeKey],
    })
    local control = template.createRuntime(h.routeFields(rows, encounterRewardRows), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()
    return historyBuilder.build({
        route = {
            key = routeKey,
            biomes = { biomeKey },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, requestedBiomeKey)
            if requestedBiomeKey == biomeKey then
                return selectedSnapshot
            end
            return nil
        end,
    })
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
            SiblingStructureKey = "F_Story01",
            Reward1Key = "Major",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat05",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
            SiblingRewardClassKey = "Major",
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
            PrebossBranchKey = "FreeReward",
            Reward4Key = "Boon",
            Reward5Key = "ZeusUpgrade",
        },
    }
end

local function fullHFieldsRows()
    return {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "ThreeRewards",
            Reward1Key = "Boon",
            Reward1LootKey = "PoseidonUpgrade",
            Reward2Key = "HermesUpgrade",
            Reward3Key = "StackUpgrade",
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
        {
            RoleKey = "Miniboss",
            OptionKey = "H_MiniBoss01",
            SiblingStructureKey = "CombatCage2",
            Reward1Key = "ZeusUpgrade",
        },
        {
            PrebossBranchKey = "Shop",
            Reward1Key = "RandomLoot",
            Reward1LootKey = "ApolloUpgrade",
            Reward1StateKey = "Bought",
        },
    }
end

local function oCombatRow(optionKey, variantKey)
    return {
        RoleKey = "Combat",
        OptionKey = optionKey,
        VariantKey = variantKey or "TwoCombats",
    }
end

local function fullOThessalyRows()
    return {
        {},
        oCombatRow("O_Combat01"),
        oCombatRow("O_Combat02", "ThreeCombats"),
        {
            RoleKey = "Story",
            OptionKey = "O_Story01",
        },
        {
            RoleKey = "Fountain",
            OptionKey = "O_Reprieve01",
            Reward1Key = "Minor",
            Reward4Key = "GiftDrop",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "O_MiniBoss02",
            Reward1Key = "ZeusUpgrade",
        },
        oCombatRow("O_Combat05"),
        {
            Reward1Key = "RandomLoot",
            Reward1LootKey = "ApolloUpgrade",
            Reward1StateKey = "Bought",
        },
    }
end

local function fullOThessalyEncounterRewardRows()
    return {
        {
            WheelOffer1Key = "OneChoice",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {},
        {
            WheelOffer1Key = "TwoChoices",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ApolloUpgrade",
        },
        {
            WheelOffer2Key = "TwoChoices",
            Reward1Key = "Minor",
            Reward4Key = "GiftDrop",
        },
        {},
        {},
        {},
        {},
        {},
        {},
        {
            WheelOffer1Key = "OneChoice",
            Reward1Key = "Major",
            Reward2Key = "MaxManaDrop",
        },
    }
end

function TestRunPlannerRouteHistoryWalker.testFixedLinearWalkerRebuildsMigrationCandidateState()
    local catalog = h.loadCatalog()
    local history = buildTemplateHistory(
        catalog,
        "Underworld",
        "F",
        h.loadFixedLinearTemplate(),
        fullFErebusRows()
    )
    local rooms = roomEvents(history)
    local steps = walker.forBiome({
        history = history,
        biome = catalog.lookup.F,
    })

    lu.assertEquals(#steps, 12)
    assertPhaseEquals(steps[1].phases.offer, rooms[1].phases.offer)
    assertPhaseEquals(steps[2].phases.generated, rooms[1].phases.offer)
    lu.assertNotNil(findCandidate(steps[2].candidates.rooms, "roomKey", "F_Combat01"))
    lu.assertNotNil(findCandidate(steps[2].candidates.rooms, "roomKey", "F_Story01"))
    lu.assertNotNil(findCandidate(steps[5].candidates.siblings, "structureKey", "F_Story01"))
    lu.assertEquals(
        findCandidate(steps[6].candidates.siblings, "structureKey", "Combat").rewardBranch,
        "majorMinor"
    )
    lu.assertEquals(#steps[12].candidates.rewards, #rooms[12].rewardCandidates)
    lu.assertEquals(steps[12].candidates.rewards[2].rewardStore, "RunProgress")
end

function TestRunPlannerRouteHistoryWalker.testFieldsCageWalkerRebuildsSiblingAndRewardCandidates()
    local catalog = h.loadCatalog()
    local history = buildTemplateHistory(
        catalog,
        "Underworld",
        "H",
        h.loadFieldsCageTemplate(),
        fullHFieldsRows()
    )
    local rooms = roomEvents(history)
    local steps = walker.forBiome({
        history = history,
        biome = catalog.lookup.H,
    })

    lu.assertEquals(#steps, 6)
    lu.assertNotNil(findCandidate(steps[2].candidates.rooms, "roomKey", "H_Combat04"))
    lu.assertNotNil(findCandidate(steps[2].candidates.siblings, "structureKey", "CombatCage2"))
    lu.assertNotNil(findCandidate(steps[2].candidates.siblings, "structureKey", "CombatCage3"))
    lu.assertEquals(#steps[2].candidates.rewards, #rooms[2].rewardCandidates)
    lu.assertEquals(steps[2].candidates.rewards[1].address, "cage:1")
    lu.assertEquals(steps[2].candidates.rewards[3].address, "cage:3")
end

function TestRunPlannerRouteHistoryWalker.testMultiEncounterWalkerRebuildsEncounterRewardCandidates()
    local catalog = h.loadCatalog()
    local history = buildTemplateHistory(
        catalog,
        "Surface",
        "O",
        h.loadMultiEncounterTemplate(),
        fullOThessalyRows(),
        fullOThessalyEncounterRewardRows()
    )
    local rooms = roomEvents(history)
    local steps = walker.forBiome({
        history = history,
        biome = catalog.lookup.O,
    })

    lu.assertEquals(#steps, 8)
    assertPhaseEquals(steps[3].phases.offer, rooms[3].phases.offer)
    lu.assertEquals(#steps[3].candidates.rewards, #rooms[3].rewardCandidates)
    lu.assertEquals(#steps[3].candidates.variants, #rooms[3].variantCandidates)
    lu.assertEquals(steps[3].candidates.variants[1].key, "TwoCombats")
    lu.assertEquals(steps[3].candidates.variants[2].key, "ThreeCombats")
    lu.assertEquals(steps[3].candidates.variants[2].availableAtBiomeEncounterDepth.min, 2)
    lu.assertEquals(steps[3].candidates.rewards[1].address, "encounter:1")
    lu.assertEquals(steps[3].candidates.rewards[3].address, "encounter:2")
    lu.assertEquals(steps[3].candidates.rewards[4].rewardStore, "MetaProgress")
end
