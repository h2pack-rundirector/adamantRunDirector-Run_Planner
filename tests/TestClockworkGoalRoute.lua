local lu = require("luaunit")
local h = require("tests.support.control_harness")
local primaryRewardItem = h.primaryRewardItem
local loadCatalog = h.loadCatalog
local loadClockworkGoalTemplate = h.loadClockworkGoalTemplate
local loadClockworkGoalData = h.loadClockworkGoalData
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw
local attachSingleBiomeRouteContext = h.attachSingleBiomeRouteContext
local valueStates = dofile("src/mods/route/value_states.lua")

-- luacheck: globals TestRunPlannerClockworkGoalRoute
TestRunPlannerClockworkGoalRoute = {}

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function tartarusBiomeWithForcedGroups(biome, forcedGroups)
    local copy = shallowCopy(biome)
    local topology = shallowCopy(biome.roomTopology)
    topology.forcedGroups = forcedGroups
    copy.roomTopology = topology
    return copy
end

local function goalCombat(optionKey, siblingKey)
    return {
        RouteKindKey = "Goal",
        OptionKey = optionKey,
        SiblingStructureKey = siblingKey,
    }
end

local function rewardCombat(optionKey, siblingKey)
    return {
        RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
        OptionKey = optionKey,
        Reward1Key = "MaxHealthDrop",
        SiblingStructureKey = siblingKey,
    }
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalStorageMatchesTartarusRouteRows()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 14)
    lu.assertEquals(instance.routeSlots[1].routeOrdinal, 0)
    lu.assertEquals(instance.routeSlots[1].kind, "intro")
    lu.assertEquals(instance.routeSlots[1].label, "Intro")
    lu.assertEquals(instance.routeSlots[1].roomKey, "I_Intro")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
    lu.assertEquals(instance.routeSlots[2].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[2].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[2].label, "Step 1")
    lu.assertEquals(instance.routeSlots[13].routeOrdinal, 12)
    lu.assertEquals(instance.routeSlots[13].label, "Step 12")
    lu.assertEquals(instance.routeSlots[14].kind, "preboss")
    lu.assertEquals(instance.routeSlots[14].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[14].roleKey, "Preboss")
    lu.assertNil(instance.routeSlots[14].roomKey)
    lu.assertEquals(instance.roleValues, {
        "GoalCombat",
        "RewardCombat",
        "Story",
        "Fountain",
        "Miniboss",
    })
    lu.assertEquals(instance.roleLabels.GoalCombat, "Goal")
    lu.assertEquals(instance.roleLabels.RewardCombat, "Reward Combat")
    lu.assertEquals(instance.optionValuesByRole.GoalCombat[1], "I_Combat01")
    lu.assertEquals(instance.optionValuesByRole.RewardCombat[1], "I_Combat01")
    lu.assertEquals(instance.rolesByKey.GoalCombat.reward.kind, "none")
    lu.assertEquals(instance.rolesByKey.RewardCombat.reward.kind, "roomStore")
    lu.assertEquals(instance.optionValuesByRole.Story, { "I_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Fountain, { "I_Reprieve01" })
    lu.assertEquals(instance.optionValuesByRole.Miniboss, {
        "I_MiniBoss01",
        "I_MiniBoss02",
    })

    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 14)
    lu.assertEquals(storage[1].defaultRows, 14)
    lu.assertEquals(storage[1].maxRows, 14)
    lu.assertEquals(storage[1].row[1].key, "RouteKindKey")
    lu.assertEquals(storage[1].row[2].key, "NonGoalKindKey")
    lu.assertEquals(storage[1].row[3].key, "OptionKey")
    lu.assertEquals(storage[1].row[4].key, "VariantKey")
    lu.assertEquals(storage[1].row[5].key, "SiblingStructureKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 14)
    lu.assertEquals(storage[2].defaultRows, 14)
    lu.assertEquals(storage[2].maxRows, 14)
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalTopologyModelsGeneratedSiblingDoor()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local template = loadClockworkGoalTemplate()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rows = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatGoal",
            Reward1Key = "MaxHealthDrop",
        },
    })

    lu.assertEquals(data.maxSiblingStructureCount(instance), 1)
    lu.assertEquals(data.activeSiblingStructureCount(instance, rows, 2), 0)
    lu.assertEquals(data.activeSiblingStructureCount(instance, rows, 3), 1)
    lu.assertTrue(data.validateRoomTopology(instance, rows, 3) == nil)

    instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatGoal",
            Reward1Key = "MaxHealthDrop",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[3].roomTopology, {
        kind = "clockworkSiblingChoice",
        selected = {
            structure = "RewardCombat",
            roomKey = "I_Combat03",
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        },
        sibling = {
            structure = "GoalCombat",
            isClockworkGoal = true,
            offerCount = 0,
        },
    })
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalTopologyRequiresExactlyOneGoalDoor()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local noGoal = template.createRuntime(routeFields({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatReward",
            Reward1Key = "MaxHealthDrop",
        },
    }), instance):buildSnapshot()

    lu.assertFalse(noGoal.valid)
    lu.assertEquals(noGoal.rows[3].invalidCode, "clockwork_sibling_goal_door_count")

    instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local twoGoals = template.createRuntime(routeFields({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatGoal",
        },
    }), instance):buildSnapshot()

    lu.assertFalse(twoGoals.valid)
    lu.assertEquals(twoGoals.rows[3].invalidCode, "clockwork_sibling_goal_door_count")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalTopologyRequiresPrebossDoorAfterGoals()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local goalSiblingAfterGoals = fakeRows({
        {},
        goalCombat("I_Combat01"),
        goalCombat("I_Combat03", "CombatReward"),
        goalCombat("I_Combat04", "I_Story01"),
        goalCombat("I_Combat09", "CombatReward"),
        goalCombat("I_Combat10", "CombatReward"),
        rewardCombat("I_Combat11", "CombatGoal"),
    })
    local validation = data.validateRoomTopology(instance, goalSiblingAfterGoals, 7)

    lu.assertEquals(data.priorGoalCount(instance, goalSiblingAfterGoals, 7), 5)
    lu.assertEquals(validation.code, "clockwork_sibling_preboss_required")
    lu.assertEquals(
        data.siblingStructureValueStatesForRow(instance, goalSiblingAfterGoals, 7).CombatGoal,
        valueStates.INVALID
    )
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, goalSiblingAfterGoals, 7).Preboss)

    local prebossSiblingAfterGoals = fakeRows({
        {},
        goalCombat("I_Combat01"),
        goalCombat("I_Combat03", "CombatReward"),
        goalCombat("I_Combat04", "I_Story01"),
        goalCombat("I_Combat09", "CombatReward"),
        goalCombat("I_Combat10", "CombatReward"),
        rewardCombat("I_Combat11", "Preboss"),
    })

    lu.assertNil(data.validateRoomTopology(instance, prebossSiblingAfterGoals, 7))
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalTopologyRequiresGoalAfterSingleExitRoom()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local nonGoalAfterSingleExit = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat02" },
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "Story",
            OptionKey = "I_Story01",
        },
    })
    local validation = data.validateRoomTopology(instance, nonGoalAfterSingleExit, 3)

    lu.assertEquals(validation.code, "clockwork_single_door_goal_required")

    local template = loadClockworkGoalTemplate()
    instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local goalAfterSingleExit = template.createRuntime(routeFields({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat02" },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
        },
    }), instance):buildSnapshot()

    lu.assertTrue(goalAfterSingleExit.valid)
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalForcePressureUsesNonGoalDoorCapacity()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local biome = tartarusBiomeWithForcedGroups(catalog.lookup.I, {
        {
            key = "I_Story",
            candidates = { "I_Story01" },
            generatedCapacityKind = "sourceSiblingCount",
            forceAtBiomeDepthMax = 2,
        },
    })
    local instance = data.prepare({
        name = "RouteI",
        biome = biome,
    })
    local noNonGoalCapacity = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat02" },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
        },
    })

    lu.assertNil(data.validateRoomTopology(instance, noNonGoalCapacity, 3))

    local missingForcedStory = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatReward",
        },
    })
    local validation = data.validateRoomTopology(instance, missingForcedStory, 3)

    lu.assertEquals(validation.code, "clockwork_forced_topology_group_unresolved")

    local siblingStory = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "Goal",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "I_Story01",
        },
    })

    lu.assertNil(data.validateRoomTopology(instance, siblingStory, 3))
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalLiveStoryForcePressureUsesSiblingCapacity()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local noNonGoalCapacity = fakeRows({
        {},
        goalCombat("I_Combat01"),
        rewardCombat("I_Combat03", "CombatGoal"),
        goalCombat("I_Combat05", "CombatReward"),
        goalCombat("I_Combat06"),
    })

    lu.assertEquals(data.rowContext(instance, noNonGoalCapacity, 5).biomeDepthCache, 4)
    lu.assertNil(data.validateRoomTopology(instance, noNonGoalCapacity, 5))

    local missingStory = fakeRows({
        {},
        goalCombat("I_Combat01"),
        rewardCombat("I_Combat03", "CombatGoal"),
        goalCombat("I_Combat04", "CombatReward"),
        goalCombat("I_Combat09", "CombatReward"),
    })
    local validation = data.validateRoomTopology(instance, missingStory, 5)

    lu.assertEquals(validation.code, "clockwork_forced_topology_group_unresolved")
    lu.assertEquals(
        data.siblingStructureValueStatesForRow(instance, missingStory, 5).CombatReward,
        valueStates.INVALID
    )
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, missingStory, 5).I_Story01)

    local siblingStory = fakeRows({
        {},
        goalCombat("I_Combat01"),
        rewardCombat("I_Combat03", "CombatGoal"),
        goalCombat("I_Combat04", "CombatReward"),
        goalCombat("I_Combat09", "I_Story01"),
    })

    lu.assertNil(data.validateRoomTopology(instance, siblingStory, 5))

    local selectedStory = fakeRows({
        {},
        goalCombat("I_Combat01"),
        rewardCombat("I_Combat03", "CombatGoal"),
        goalCombat("I_Combat04", "CombatReward"),
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "Story",
            OptionKey = "I_Story01",
            SiblingStructureKey = "CombatGoal",
        },
    })

    lu.assertNil(data.validateRoomTopology(instance, selectedStory, 5))
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalLiveMinibossForcePressureUsesSiblingCapacity()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local missingMiniboss = fakeRows({
        {},
        goalCombat("I_Combat01"),
        rewardCombat("I_Combat03", "CombatGoal"),
        goalCombat("I_Combat04", "I_Story01"),
        rewardCombat("I_Combat09", "CombatGoal"),
        goalCombat("I_Combat10", "CombatReward"),
        rewardCombat("I_Combat11", "CombatGoal"),
        goalCombat("I_Combat12", "CombatReward"),
    })
    local validation = data.validateRoomTopology(instance, missingMiniboss, 8)

    lu.assertEquals(data.rowContext(instance, missingMiniboss, 8).biomeDepthCache, 7)
    lu.assertEquals(validation.code, "clockwork_forced_topology_group_unresolved")
    lu.assertEquals(
        data.siblingStructureValueStatesForRow(instance, missingMiniboss, 8).CombatReward,
        valueStates.INVALID
    )
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, missingMiniboss, 8).I_MiniBoss01)

    local siblingMiniboss = fakeRows({
        {},
        goalCombat("I_Combat01"),
        rewardCombat("I_Combat03", "CombatGoal"),
        goalCombat("I_Combat04", "I_Story01"),
        rewardCombat("I_Combat09", "CombatGoal"),
        goalCombat("I_Combat10", "CombatReward"),
        rewardCombat("I_Combat11", "CombatGoal"),
        goalCombat("I_Combat12", "I_MiniBoss01"),
    })

    lu.assertNil(data.validateRoomTopology(instance, siblingMiniboss, 8))

    local priorPickedMiniboss = fakeRows({
        {},
        goalCombat("I_Combat01"),
        rewardCombat("I_Combat03", "CombatGoal"),
        goalCombat("I_Combat04", "I_Story01"),
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "Miniboss",
            OptionKey = "I_MiniBoss01",
            SiblingStructureKey = "CombatGoal",
        },
        rewardCombat("I_Combat09", "CombatGoal"),
        goalCombat("I_Combat10", "CombatReward"),
        goalCombat("I_Combat11", "CombatReward"),
    })

    lu.assertNil(data.validateRoomTopology(instance, priorPickedMiniboss, 8))
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalTopologyRequiresSiblingDoorWhenGenerated()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
            OptionKey = "I_Combat03",
            Reward1Key = "MaxHealthDrop",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertFalse(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[3].invalidCode, "clockwork_sibling_structure_required")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalForcesFirstRouteRowFromDeclaration()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local blankFirstStep = fakeRows({
        {},
        {},
    })
    local staleFirstStep = fakeRows({
        {},
        { RouteKindKey = "NonGoal", NonGoalKindKey = "Story", OptionKey = "I_Story01", Reward1Key = "MaxHealthDrop" },
    })

    lu.assertEquals(data.readRoleKey(instance, blankFirstStep, 2), "GoalCombat")
    lu.assertEquals(data.readRoleKey(instance, staleFirstStep, 2), "GoalCombat")
    lu.assertEquals(data.roleValuesForRow(instance, blankFirstStep, 2), {
        "GoalCombat",
    })
    lu.assertEquals(data.optionValuesForRow(instance, blankFirstStep, 2, "Story"), {})
    lu.assertEquals(data.optionValuesForRow(instance, blankFirstStep, 2, "GoalCombat")[1], "I_Combat01")
    local rewardContext = data.rewardContext(instance, blankFirstStep, 2, instance.rolesByKey.GoalCombat)
    lu.assertEquals(rewardContext.kind, "none")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalPreservesPartialNonGoalRouteKind()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rows = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "NonGoal" },
    })

    lu.assertEquals(data.readRouteKind(instance, rows, 3), "NonGoal")
    lu.assertEquals(data.readRoleKey(instance, rows, 3), "")
    lu.assertEquals(data.nonGoalKindValuesForRow(instance), {
        "RewardCombat",
        "Story",
        "Fountain",
        "Miniboss",
    })
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalCombatRoomsCannotRepeatAcrossGoalAndExtension()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rows = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat01" },
    })

    lu.assertTrue(data.validateRow(instance, rows, 2).valid)
    local validation = data.validateRow(instance, rows, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "option_limit")
    lu.assertEquals(
        data.optionValueStatesForRow(instance, rows, 3, "RewardCombat").I_Combat01,
        valueStates.INVALID
    )
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields({
            {},
            { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
            {
                RouteKindKey = "NonGoal", NonGoalKindKey = "Story",
                OptionKey = "I_Story01",
                SiblingStructureKey = "CombatGoal",
            },
            {
                RouteKindKey = "Goal",
                OptionKey = "I_Combat03",
            },
            {
                RouteKindKey = "NonGoal", NonGoalKindKey = "Miniboss",
                OptionKey = "I_MiniBoss01",
                SiblingStructureKey = "CombatGoal",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
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
                RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
                OptionKey = "I_Combat10",
                SiblingStructureKey = "CombatGoal",
                Reward1Key = "MaxHealthDrop",
            },
            {
                RouteKindKey = "Goal",
                OptionKey = "I_Combat11",
                SiblingStructureKey = "CombatReward",
            },
            {
                RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
                OptionKey = "I_Combat12",
                SiblingStructureKey = "Preboss",
                Reward1Key = "MaxHealthDrop",
            },
            {
                RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
                OptionKey = "I_Combat15",
                SiblingStructureKey = "Preboss",
                Reward1Key = "MaxHealthDrop",
            },
            {
                RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
                OptionKey = "I_Combat23",
                SiblingStructureKey = "Preboss",
                Reward1Key = "MaxHealthDrop",
            },
            {},
            {},
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "I")
    lu.assertEquals(snapshot.adapter, "clockworkGoal")
    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(snapshot.clockwork.goalCount, 5)
    lu.assertEquals(snapshot.clockwork.requiredGoals, 5)
    lu.assertEquals(snapshot.clockwork.nonGoalRewardCount, 5)
    lu.assertEquals(snapshot.clockwork.maxNonGoalRewards, 6)
    lu.assertEquals(snapshot.clockwork.storyCount, 1)
    lu.assertEquals(#snapshot.rows, 14)

    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "I_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertEquals(snapshot.rows[1].exitCount, 1)
    lu.assertEquals(snapshot.rows[1].rewardExitCount, 0)
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "none")
    lu.assertTrue(snapshot.rows[1].valid)

    lu.assertEquals(snapshot.rows[2].slotKind, "biomeRow")
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "GoalCombat")
    lu.assertEquals(snapshot.rows[2].optionKey, "I_Combat01")
    lu.assertEquals(snapshot.rows[2].roomKey, "I_Combat01")
    lu.assertEquals(snapshot.rows[2].exitCount, 2)
    lu.assertEquals(snapshot.rows[2].rewardExitCount, 1)
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardKind, "none")
    lu.assertTrue(snapshot.rows[2].countsGoal)
    lu.assertFalse(snapshot.rows[2].countsNonGoalReward)

    lu.assertEquals(snapshot.rows[3].roleKey, "Story")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "none")
    lu.assertFalse(snapshot.rows[3].countsGoal)
    lu.assertFalse(snapshot.rows[3].countsNonGoalReward)

    lu.assertEquals(snapshot.rows[5].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[5].optionKey, "I_MiniBoss01")
    lu.assertEquals(snapshot.rows[5].roomKey, "I_MiniBoss01")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardKind, "boonSource")
    lu.assertFalse(snapshot.rows[5].countsGoal)
    lu.assertTrue(snapshot.rows[5].countsNonGoalReward)
    lu.assertTrue(snapshot.rows[5].valid)

    lu.assertEquals(snapshot.rows[14].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[14].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[14].roleKey, "Preboss")
    lu.assertNil(snapshot.rows[14].roomKey)
    lu.assertNil(snapshot.rows[14].exitCount)
    lu.assertNil(snapshot.rows[14].rewardExitCount)
    lu.assertEquals(primaryRewardItem(snapshot.rows[14]).rewardKind, "shop")
    lu.assertTrue(snapshot.rows[14].valid)
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalCombatCanSelectDevotionRewardSurface()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatGoal",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ApolloUpgrade",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[3].roleKey, "RewardCombat")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "roomStore")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[1].key, "rewardType")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[1].value, "Devotion")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[2].key, "lootAName")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[2].value, "ZeusUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[3].key, "lootBName")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[3].value, "ApolloUpgrade")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalInvalidatesDuplicateTrialRewardGods()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat",
            OptionKey = "I_Combat03",
            SiblingStructureKey = "CombatGoal",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ZeusUpgrade",
        },
    }), instance)
    attachSingleBiomeRouteContext(control, "Underworld", "I")
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertFalse(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[3].invalidCode, "duplicate_devotion_god")
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 3)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_devotion_god")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalValidationModelsCountersAndSidePaths()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })

    local storyAfterOneExit = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat02" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "Story", OptionKey = "I_Story01", SiblingStructureKey = "CombatGoal" },
    })
    local validation = data.validateRow(instance, storyAfterOneExit, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")
    lu.assertTrue(hasValue(data.roleValuesForRow(instance, storyAfterOneExit, 3), "Story"))
    lu.assertNotNil(data.roleValueStatesForRow(instance, storyAfterOneExit, 3).Story)
    lu.assertNil(data.routeKindValueStatesForRow(instance, storyAfterOneExit, 3).Goal)
    lu.assertEquals(data.routeKindValueStatesForRow(instance, storyAfterOneExit, 3).NonGoal, valueStates.INVALID)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, storyAfterOneExit, 3, "Story"), "I_Story01"))
    lu.assertNotNil(data.optionValueStatesForRow(instance, storyAfterOneExit, 3, "Story").I_Story01)

    local extensionAfterOneExit = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat02" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat03", Reward1Key = "MaxHealthDrop" },
    })
    validation = data.validateRow(instance, extensionAfterOneExit, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")

    local rolesAfterTwoExit = data.roleValuesForRow(instance, fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {},
    }), 3)
    lu.assertTrue(hasValue(rolesAfterTwoExit, "GoalCombat"))
    lu.assertTrue(hasValue(rolesAfterTwoExit, "RewardCombat"))
    lu.assertTrue(hasValue(rolesAfterTwoExit, "Story"))

    local seventhExtension = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat03", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat04", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat09", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat10", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat11", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat12", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat18", Reward1Key = "MaxHealthDrop" },
    })
    validation = data.validateRow(instance, seventhExtension, 9)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")

    local finalExtensionTwoExit = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat03", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat04", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat09", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat10", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat11", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat12", Reward1Key = "MaxHealthDrop" },
    })
    validation = data.validateRow(instance, finalExtensionTwoExit, 8)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "option_unavailable")
    local finalExtensionOptions = data.optionValuesForRow(instance, finalExtensionTwoExit, 8, "RewardCombat")
    lu.assertTrue(hasValue(finalExtensionOptions, "I_Combat12"))
    lu.assertTrue(hasValue(finalExtensionOptions, "I_Combat13"))
    lu.assertNotNil(data.optionValueStatesForRow(instance, finalExtensionTwoExit, 8, "RewardCombat").I_Combat12)
    lu.assertNil(data.optionValueStatesForRow(instance, finalExtensionTwoExit, 8, "RewardCombat").I_Combat13)

    local finalExtensionOneExit = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat03", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat04", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat09", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat10", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat11", Reward1Key = "MaxHealthDrop" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat13", Reward1Key = "MaxHealthDrop" },
    })
    validation = data.validateRow(instance, finalExtensionOneExit, 8)
    lu.assertTrue(validation.valid)

    local sixthGoal = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat03", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat04", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat09", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat10", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat11" },
    })
    validation = data.validateRow(instance, sixthGoal, 7)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_goal_limit")
    lu.assertEquals(data.readRoleKey(instance, sixthGoal, 7), "GoalCombat")
    local postGoalRoles = data.roleValuesForRow(instance, sixthGoal, 7)
    lu.assertTrue(hasValue(postGoalRoles, "GoalCombat"))
    lu.assertTrue(hasValue(postGoalRoles, "RewardCombat"))
    lu.assertTrue(hasValue(postGoalRoles, "Story"))
    lu.assertNotNil(data.roleValueStatesForRow(instance, sixthGoal, 7).GoalCombat)

    local missingGoal = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat03" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat04" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat09" },
        {},
    })
    validation = data.validateRow(instance, missingGoal, 14)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_goal_count")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalActiveVanillaRowsAreInvalid()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rows = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat03" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat04" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {},
    })

    local validation = data.validateRow(instance, rows, 12)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "role_required")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalAllowsPostGoalExtensionBehindTwoExitRoom()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local template = loadClockworkGoalTemplate()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rowData = {
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "Story", OptionKey = "I_Story01", SiblingStructureKey = "CombatGoal" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat03" },
        {
            RouteKindKey = "NonGoal", NonGoalKindKey = "Miniboss",
            OptionKey = "I_MiniBoss01",
            SiblingStructureKey = "CombatGoal",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
        { RouteKindKey = "Goal", OptionKey = "I_Combat04", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat09", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat10", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "RewardCombat", OptionKey = "I_Combat13", Reward1Key = "MaxHealthDrop", SiblingStructureKey = "Preboss" },
        {},
        {},
        {},
        {},
        {},
        {},
        {},
    }
    local rows = fakeRows(rowData)

    lu.assertEquals(data.readRoleKey(instance, rows, 9), "RewardCombat")
    lu.assertFalse(data.isInactiveRouteRow(instance, rows, 9))
    lu.assertTrue(data.validateRow(instance, rows, 9).valid)
    local postGoalRoles = data.roleValuesForRow(instance, rows, 9)
    lu.assertTrue(hasValue(postGoalRoles, "GoalCombat"))
    lu.assertTrue(hasValue(postGoalRoles, "RewardCombat"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 9).RewardCombat)
    lu.assertTrue(hasValue(postGoalRoles, "Story"))

    lu.assertEquals(data.readRoleKey(instance, rows, 10), "Vanilla")
    lu.assertEquals(data.roleValuesForRow(instance, rows, 10), { "Vanilla" })
    lu.assertTrue(data.validateRow(instance, rows, 10).valid)
    lu.assertTrue(data.isInactiveRouteRow(instance, rows, 10))
    lu.assertFalse(data.isInactiveRouteRow(instance, rows, 14))
    lu.assertEquals(data.countGoals(instance, rows), 5)
    lu.assertEquals(data.countNonGoals(instance, rows), 2)
    lu.assertEquals(data.countStories(instance, rows), 1)
    lu.assertTrue(data.validateRow(instance, rows, 14).valid)

    instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields(rowData), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.clockwork.goalCount, 5)
    lu.assertEquals(snapshot.clockwork.nonGoalRewardCount, 2)
    lu.assertEquals(snapshot.clockwork.storyCount, 1)
    lu.assertEquals(snapshot.rows[9].roleKey, "RewardCombat")
    lu.assertTrue(snapshot.rows[9].valid)
    lu.assertEquals(snapshot.rows[10].roleKey, "Vanilla")
    lu.assertTrue(snapshot.rows[14].valid)
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalTerminatesAfterOneExitFifthGoal()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rows = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat03" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat04" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat09" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat02" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "Story", OptionKey = "I_Story01" },
        {},
    })

    lu.assertEquals(data.readRoleKey(instance, rows, 7), "Vanilla")
    lu.assertEquals(data.roleValuesForRow(instance, rows, 7), { "Vanilla" })
    lu.assertTrue(data.validateRow(instance, rows, 7).valid)
    lu.assertTrue(data.isInactiveRouteRow(instance, rows, 7))
    lu.assertEquals(data.countGoals(instance, rows), 5)
    lu.assertEquals(data.countStories(instance, rows), 0)
    lu.assertTrue(data.validateRow(instance, rows, 14).valid)
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalRoomViewHidesInactiveRows()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local fields = routeUiFields(template.storage(instance))
    local rowData = {
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat03" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat04" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat09" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat02" },
        { RouteKindKey = "NonGoal", NonGoalKindKey = "Story", OptionKey = "I_Story01" },
    }
    for rowIndex, row in ipairs(rowData) do
        for alias, value in pairs(row) do
            if string.match(alias, "^Reward") then
                fields.Rewards:get(rowIndex, alias):write(value)
            else
                fields.Rooms:get(rowIndex, alias):write(value)
            end
        end
    end

    local control = template.createUi(fields, instance)
    local draw = noOpDraw()
    local rendered = {}
    draw.imgui.Text = function(text)
        rendered[tostring(text)] = true
    end

    template.views.rooms(draw, control, instance)

    lu.assertTrue(rendered.Intro)
    lu.assertTrue(rendered["Step 5"])
    lu.assertNil(rendered["Step 6"])
    lu.assertNil(rendered["Step 12"])
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalRewardViewDoesNotRenderGoalAsReward()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(2, "RoleKey"):write("GoalCombat")
    fields.Rooms:get(2, "OptionKey"):write("I_Combat01")

    local control = template.createUi(fields, instance)
    local draw = noOpDraw()
    local rendered = {}
    draw.imgui.Text = function(text)
        rendered[tostring(text)] = true
    end

    template.views.rewards(draw, control, instance)

    lu.assertNil(rendered["Clockwork Goal"])
end
