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

-- luacheck: globals TestRunPlannerClockworkGoalRoute
TestRunPlannerClockworkGoalRoute = {}

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
    lu.assertEquals(instance.routeSlots[14].roomOptions[1].key, "I_PreBoss01")
    lu.assertEquals(instance.routeSlots[14].roomOptions[2].key, "I_PreBoss02")
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Goal",
        "ExtensionCombat",
        "Story",
        "Fountain",
        "Miniboss",
    })
    lu.assertEquals(instance.roleLabels.Goal, "Goal Room")
    lu.assertEquals(instance.optionValuesByRole.Goal[1], "")
    lu.assertEquals(instance.optionValuesByRole.Goal[2], "I_Combat01")
    lu.assertNil(instance.rolesByKey.Goal.mapOptions[1].reward)
    lu.assertEquals(instance.optionValuesByRole.ExtensionCombat[1], "")
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
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 14)
    lu.assertEquals(storage[2].defaultRows, 14)
    lu.assertEquals(storage[2].maxRows, 14)
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
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat01" },
    })

    lu.assertEquals(data.readRoleKey(instance, blankFirstStep, 2), "Goal")
    lu.assertEquals(data.readRoleKey(instance, staleFirstStep, 2), "Goal")
    lu.assertEquals(data.roleValuesForRow(instance, blankFirstStep, 2), {
        "Goal",
    })
    lu.assertEquals(data.optionValuesForRow(instance, blankFirstStep, 2, "ExtensionCombat"), {})
    lu.assertEquals(data.optionValuesForRow(instance, blankFirstStep, 2, "Goal")[2], "I_Combat01")
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
            { RoleKey = "Goal", OptionKey = "I_Combat01" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03", Reward1Key = "MaxHealthDrop" },
            { RoleKey = "Goal", OptionKey = "I_Combat04" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat09" },
            { RoleKey = "Goal", OptionKey = "I_Combat10" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat11" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat12" },
            { RoleKey = "Goal", OptionKey = "I_Combat15" },
            { RoleKey = "Goal", OptionKey = "I_Combat18" },
            { RoleKey = "ExtensionCombat", OptionKey = "I_Combat21" },
            { RoleKey = "Story", OptionKey = "I_Story01" },
            {},
            {},
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "I")
    lu.assertEquals(snapshot.adapter, "clockworkGoal")
    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(snapshot.clockwork.goalCount, 5)
    lu.assertEquals(snapshot.clockwork.requiredGoalRewards, 5)
    lu.assertEquals(snapshot.clockwork.nonGoalRewardCount, 5)
    lu.assertEquals(snapshot.clockwork.maxNonGoalRewards, 6)
    lu.assertEquals(snapshot.clockwork.storyCount, 1)
    lu.assertEquals(#snapshot.rows, 14)

    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "I_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "none")
    lu.assertTrue(snapshot.rows[1].valid)

    lu.assertEquals(snapshot.rows[2].slotKind, "biomeRow")
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Goal")
    lu.assertEquals(snapshot.rows[2].optionKey, "I_Combat01")
    lu.assertEquals(snapshot.rows[2].roomKey, "I_Combat01")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardKind, "fixedReward")
    lu.assertTrue(snapshot.rows[2].countsGoalReward)
    lu.assertFalse(snapshot.rows[2].countsNonGoalReward)

    lu.assertEquals(snapshot.rows[3].roleKey, "ExtensionCombat")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "roomStore")
    lu.assertFalse(snapshot.rows[3].countsGoalReward)
    lu.assertTrue(snapshot.rows[3].countsNonGoalReward)
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[1].value, "MaxHealthDrop")

    lu.assertEquals(snapshot.rows[12].roleKey, "Story")
    lu.assertEquals(snapshot.rows[12].optionKey, "I_Story01")
    lu.assertEquals(snapshot.rows[12].roomKey, "I_Story01")
    lu.assertEquals(primaryRewardItem(snapshot.rows[12]).rewardKind, "none")
    lu.assertFalse(snapshot.rows[12].countsGoalReward)
    lu.assertFalse(snapshot.rows[12].countsNonGoalReward)
    lu.assertTrue(snapshot.rows[12].valid)

    lu.assertEquals(snapshot.rows[14].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[14].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[14].roleKey, "Preboss")
    lu.assertEquals(snapshot.rows[14].roomOptions[1].key, "I_PreBoss01")
    lu.assertEquals(snapshot.rows[14].roomOptions[2].key, "I_PreBoss02")
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
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        {
            RoleKey = "ExtensionCombat",
            OptionKey = "I_Combat03",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ApolloUpgrade",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[3].roleKey, "ExtensionCombat")
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
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        {
            RoleKey = "ExtensionCombat",
            OptionKey = "I_Combat03",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ZeusUpgrade",
        },
    }), instance)
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
        { RoleKey = "Goal", OptionKey = "I_Combat02" },
        { RoleKey = "Story", OptionKey = "I_Story01" },
    })
    local validation = data.validateRow(instance, storyAfterOneExit, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")
    lu.assertTrue(hasValue(data.roleValuesForRow(instance, storyAfterOneExit, 3), "Story"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, storyAfterOneExit, 3).Story)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, storyAfterOneExit, 3, "Story"), "I_Story01"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, storyAfterOneExit, 3, "Story").I_Story01)

    local extensionAfterOneExit = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat02" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03" },
    })
    validation = data.validateRow(instance, extensionAfterOneExit, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")

    local rolesAfterTwoExit = data.roleValuesForRow(instance, fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        {},
    }), 3)
    lu.assertTrue(hasValue(rolesAfterTwoExit, "ExtensionCombat"))
    lu.assertTrue(hasValue(rolesAfterTwoExit, "Story"))

    local seventhExtension = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat04" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat09" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat10" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat11" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat12" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat18" },
    })
    validation = data.validateRow(instance, seventhExtension, 9)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_previous_extension_choice")

    local finalExtensionTwoExit = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat04" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat09" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat10" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat11" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat12" },
    })
    validation = data.validateRow(instance, finalExtensionTwoExit, 8)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "option_unavailable")
    local finalExtensionOptions = data.optionValuesForRow(instance, finalExtensionTwoExit, 8, "ExtensionCombat")
    lu.assertTrue(hasValue(finalExtensionOptions, "I_Combat12"))
    lu.assertTrue(hasValue(finalExtensionOptions, "I_Combat13"))
    lu.assertNotNil(data.optionValueColorsForRow(instance, finalExtensionTwoExit, 8, "ExtensionCombat").I_Combat12)
    lu.assertNil(data.optionValueColorsForRow(instance, finalExtensionTwoExit, 8, "ExtensionCombat").I_Combat13)

    local finalExtensionOneExit = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat03" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat04" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat09" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat10" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat11" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat13" },
    })
    validation = data.validateRow(instance, finalExtensionOneExit, 8)
    lu.assertTrue(validation.valid)

    local sixthGoal = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Goal", OptionKey = "I_Combat10" },
        { RoleKey = "Goal", OptionKey = "I_Combat11" },
    })
    validation = data.validateRow(instance, sixthGoal, 7)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_goal_limit")
    lu.assertEquals(data.readRoleKey(instance, sixthGoal, 7), "Goal")
    local postGoalRoles = data.roleValuesForRow(instance, sixthGoal, 7)
    lu.assertTrue(hasValue(postGoalRoles, "Goal"))
    lu.assertTrue(hasValue(postGoalRoles, "Story"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, sixthGoal, 7).Goal)

    local missingGoal = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        {},
    })
    validation = data.validateRow(instance, missingGoal, 14)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_goal_count")
end

function TestRunPlannerClockworkGoalRoute.testClockworkGoalLateVanillaRowIsValidButCanInvalidatePreboss()
    local catalog = loadCatalog()
    local data = loadClockworkGoalData()
    local instance = data.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local rows = fakeRows({
        {},
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
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

    lu.assertTrue(data.validateRow(instance, rows, 12).valid)
    lu.assertTrue(data.validateRow(instance, rows, 13).valid)

    local validation = data.validateRow(instance, rows, 14)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "clockwork_goal_count")
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
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Goal", OptionKey = "I_Combat10" },
        { RoleKey = "Story", OptionKey = "I_Story01" },
        { RoleKey = "ExtensionCombat", OptionKey = "I_Combat12", Reward1Key = "MaxHealthDrop" },
        {},
        {},
        {},
        {},
        {},
        {},
        {},
    }
    local rows = fakeRows(rowData)

    lu.assertEquals(data.readRoleKey(instance, rows, 7), "Story")
    lu.assertFalse(data.isInactiveRouteRow(instance, rows, 7))
    lu.assertTrue(data.validateRow(instance, rows, 7).valid)
    local postGoalRoles = data.roleValuesForRow(instance, rows, 7)
    lu.assertTrue(hasValue(postGoalRoles, "Goal"))
    lu.assertNotNil(data.roleValueColorsForRow(instance, rows, 7).Goal)
    lu.assertTrue(hasValue(postGoalRoles, "Story"))

    lu.assertEquals(data.readRoleKey(instance, rows, 8), "Vanilla")
    lu.assertEquals(data.roleValuesForRow(instance, rows, 8), { "Vanilla" })
    lu.assertTrue(data.validateRow(instance, rows, 8).valid)
    lu.assertTrue(data.isInactiveRouteRow(instance, rows, 8))
    lu.assertFalse(data.isInactiveRouteRow(instance, rows, 14))
    lu.assertEquals(data.countGoals(instance, rows), 5)
    lu.assertEquals(data.countNonGoals(instance, rows), 0)
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
    lu.assertEquals(snapshot.clockwork.nonGoalRewardCount, 0)
    lu.assertEquals(snapshot.clockwork.storyCount, 1)
    lu.assertEquals(snapshot.rows[7].roleKey, "Story")
    lu.assertTrue(snapshot.rows[7].valid)
    lu.assertEquals(snapshot.rows[8].roleKey, "Vanilla")
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
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Goal", OptionKey = "I_Combat02" },
        { RoleKey = "Story", OptionKey = "I_Story01" },
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
        { RoleKey = "Goal", OptionKey = "I_Combat01" },
        { RoleKey = "Goal", OptionKey = "I_Combat03" },
        { RoleKey = "Goal", OptionKey = "I_Combat04" },
        { RoleKey = "Goal", OptionKey = "I_Combat09" },
        { RoleKey = "Goal", OptionKey = "I_Combat02" },
        { RoleKey = "Story", OptionKey = "I_Story01" },
    }
    for rowIndex, row in ipairs(rowData) do
        for alias, value in pairs(row) do
            fields.Rooms:get(rowIndex, alias):write(value)
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
