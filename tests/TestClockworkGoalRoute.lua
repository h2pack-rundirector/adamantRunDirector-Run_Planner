local lu = require("luaunit")
local h = require("tests.support.control_harness")
local loadCatalog = h.loadCatalog
local loadClockworkGoalTemplate = h.loadClockworkGoalTemplate
local loadClockworkGoalData = h.loadClockworkGoalData
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw

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

    lu.assertEquals(instance.routeRowCount, 13)
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
    lu.assertEquals(instance.roleValues, {
        "GoalCombat",
        "RewardCombat",
        "Story",
        "Fountain",
        "Miniboss",
        "Preboss",
    })
    lu.assertEquals(instance.roleLabels.GoalCombat, "Goal")
    lu.assertEquals(instance.roleLabels.RewardCombat, "Reward Combat")
    lu.assertEquals(instance.optionValuesByRole.GoalCombat[1], "I_Combat01")
    lu.assertEquals(instance.optionValuesByRole.RewardCombat[1], "I_Combat01")
    lu.assertEquals(instance.rolesByKey.GoalCombat.reward.kind, "none")
    lu.assertEquals(instance.rolesByKey.RewardCombat.reward.kind, "roomStore")
    lu.assertEquals(instance.rolesByKey.Preboss.reward.kind, "shop")
    lu.assertEquals(instance.rolesByKey.Preboss.reward.shopProfile, "I_WorldShop")
    lu.assertEquals(instance.optionValuesByRole.Story, { "I_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Fountain, { "I_Reprieve01" })
    lu.assertEquals(instance.optionValuesByRole.Miniboss, {
        "I_MiniBoss01",
        "I_MiniBoss02",
    })

    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 13)
    lu.assertEquals(storage[1].defaultRows, 13)
    lu.assertEquals(storage[1].maxRows, 13)
    lu.assertEquals(storage[1].row[1].key, "RouteKindKey")
    lu.assertEquals(storage[1].row[2].key, "NonGoalKindKey")
    lu.assertEquals(storage[1].row[3].key, "OptionKey")
    lu.assertEquals(storage[1].row[4].key, "VariantKey")
    lu.assertEquals(storage[1].row[5].key, "SiblingStructureKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 13)
    lu.assertEquals(storage[2].defaultRows, 13)
    lu.assertEquals(storage[2].maxRows, 13)
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
    lu.assertNil(data.validateRoomTopology(instance, missingForcedStory, 3))

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

    lu.assertNil(data.validateRoomTopology(instance, noNonGoalCapacity, 5))

    local missingStory = fakeRows({
        {},
        goalCombat("I_Combat01"),
        rewardCombat("I_Combat03", "CombatGoal"),
        goalCombat("I_Combat04", "CombatReward"),
        goalCombat("I_Combat09", "CombatReward"),
    })
    lu.assertNil(data.validateRoomTopology(instance, missingStory, 5))
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, missingStory, 5).CombatReward)
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
    lu.assertNil(data.validateRoomTopology(instance, missingMiniboss, 8))
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, missingMiniboss, 8).CombatReward)
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

    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "RewardCombat").I_Combat01)
end


function TestRunPlannerClockworkGoalRoute.testClockworkGoalEmitsDumbSelectedRowsSnapshot()
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
            Reward1Key = "MaxHealthDrop",
        },
    }), instance)

    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.schema, "selectedRows.v1")
    lu.assertEquals(snapshot.controlName, "RouteI")
    lu.assertEquals(snapshot.biomeKey, "I")
    lu.assertEquals(snapshot.adapter, "clockworkGoal")
    lu.assertNil(snapshot.rows[1].valid)
    lu.assertNil(snapshot.rows[1].roomTopology)
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertEquals(snapshot.rows[1].optionKey, "I_Intro")
    lu.assertEquals(snapshot.rows[2].roleKey, "GoalCombat")
    lu.assertEquals(snapshot.rows[2].optionKey, "I_Combat01")
    lu.assertEquals(snapshot.rows[2].routeKindKey, "Goal")
    lu.assertEquals(snapshot.rows[3].roleKey, "RewardCombat")
    lu.assertEquals(snapshot.rows[3].optionKey, "I_Combat03")
    lu.assertEquals(snapshot.rows[3].routeKindKey, "NonGoal")
    lu.assertEquals(snapshot.rows[3].nonGoalKindKey, "RewardCombat")
    lu.assertEquals(snapshot.rows[3].topology.siblings[1].structureKey, "CombatGoal")
    lu.assertEquals(snapshot.rows[3].rewards.row.values[1], "MaxHealthDrop")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalReadSelectedRowsSnapshot()
    local catalog = loadCatalog()
    local template = loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
    }), instance)

    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.schema, "selectedRows.v1")
    lu.assertEquals(snapshot.rows[2].roleKey, "GoalCombat")
    lu.assertEquals(snapshot.rows[2].optionKey, "I_Combat01")
end


function TestRunPlannerClockworkGoalRoute.testClockworkGoalExportsDuplicateTrialRewardGods()
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
    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.rows[3].rewards.row.values[1], "Devotion")
    lu.assertEquals(snapshot.rows[3].rewards.row.values[3], "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[3].rewards.row.values[4], "ZeusUpgrade")
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
    lu.assertTrue(hasValue(data.roleValuesForRow(instance, storyAfterOneExit, 3), "Story"))
    lu.assertNil(data.routeKindValueStatesForRow(instance, storyAfterOneExit, 3).Goal)
    lu.assertNil(data.routeKindValueStatesForRow(instance, storyAfterOneExit, 3).NonGoal)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, storyAfterOneExit, 3, "Story"), "I_Story01"))
    lu.assertNil(data.optionValueStatesForRow(instance, storyAfterOneExit, 3, "Story").I_Story01)

    local rolesAfterTwoExit = data.roleValuesForRow(instance, fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        {},
    }), 3)
    lu.assertTrue(hasValue(rolesAfterTwoExit, "GoalCombat"))
    lu.assertTrue(hasValue(rolesAfterTwoExit, "RewardCombat"))
    lu.assertTrue(hasValue(rolesAfterTwoExit, "Story"))

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
    local finalExtensionOptions = data.optionValuesForRow(instance, finalExtensionTwoExit, 8, "RewardCombat")
    lu.assertTrue(hasValue(finalExtensionOptions, "I_Combat12"))
    lu.assertTrue(hasValue(finalExtensionOptions, "I_Combat13"))
    lu.assertNil(data.optionValueStatesForRow(instance, finalExtensionTwoExit, 8, "RewardCombat").I_Combat13)

    local sixthGoal = fakeRows({
        {},
        { RouteKindKey = "Goal", OptionKey = "I_Combat01" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat03", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat04", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat09", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat10", SiblingStructureKey = "CombatReward" },
        { RouteKindKey = "Goal", OptionKey = "I_Combat11" },
    })
    lu.assertEquals(data.readRoleKey(instance, sixthGoal, 7), "GoalCombat")
    local postGoalRoles = data.roleValuesForRow(instance, sixthGoal, 7)
    lu.assertTrue(hasValue(postGoalRoles, "GoalCombat"))
    lu.assertTrue(hasValue(postGoalRoles, "RewardCombat"))
    lu.assertTrue(hasValue(postGoalRoles, "Story"))
    lu.assertTrue(hasValue(postGoalRoles, "Preboss"))
    lu.assertNil(data.roleValueStatesForRow(instance, sixthGoal, 7).GoalCombat)

end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalRowsStaySelectableAfterFifthGoal()
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

    lu.assertEquals(data.readRoleKey(instance, rows, 7), "Story")
    local roles = data.roleValuesForRow(instance, rows, 7)
    lu.assertTrue(hasValue(roles, "GoalCombat"))
    lu.assertTrue(hasValue(roles, "RewardCombat"))
    lu.assertTrue(hasValue(roles, "Story"))
    lu.assertEquals(data.readRoleKey(instance, rows, 8), "")
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
    instance.routeKey = "Underworld"
    instance.biomeKey = "I"
    instance.routeFeedbackGeneration = 1
    instance.routeFeedback = {
        inactiveAfterRowIndex = 6,
    }
    instance.routeContext = {
        routeGeneration = function()
            return 1
        end,
        blockingHorizon = function()
            return nil
        end,
    }
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
