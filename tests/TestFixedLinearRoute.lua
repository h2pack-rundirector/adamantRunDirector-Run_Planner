local lu = require("luaunit")
local h = require("tests.support.control_harness")
local primaryRewardItem = h.primaryRewardItem
local loadCatalog = h.loadCatalog
local loadFixedLinearTemplate = h.loadFixedLinearTemplate
local loadFixedLinearData = h.loadFixedLinearData
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local attachSingleBiomeRouteContext = h.attachSingleBiomeRouteContext
local valueStates = dofile("src/mods/route/value_states.lua")

-- luacheck: globals TestRunPlannerFixedLinearRoute
TestRunPlannerFixedLinearRoute = {}

function TestRunPlannerFixedLinearRoute.testFixedLinearStorageMatchesRouteRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 13)
    lu.assertEquals(instance.routeSlots[1].routeOrdinal, 0)
    lu.assertEquals(instance.routeSlots[1].kind, "opening")
    lu.assertEquals(instance.routeSlots[1].label, "Opening")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Opening")
    lu.assertEquals(instance.routeSlots[2].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[10].routeOrdinal, 9)
    lu.assertEquals(instance.routeSlots[11].routeOrdinal, 10)
    lu.assertEquals(instance.routeSlots[11].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[11].biomeDepthCacheCost, 1)
    lu.assertEquals(instance.routeSlots[12].routeOrdinal, 11)
    lu.assertEquals(instance.routeSlots[12].biomeDepthCacheCost, 0)
    lu.assertEquals(instance.routeSlots[12].kind, "preboss")
    lu.assertEquals(instance.routeSlots[12].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[12].branchKey, "Shop")
    lu.assertEquals(instance.routeSlots[12].roomHistoryCost, 1)
    lu.assertEquals(instance.routeSlots[12].branchValues, {
        "Shop",
    })
    lu.assertEquals(instance.routeSlots[13].routeOrdinal, 11)
    lu.assertEquals(instance.routeSlots[13].biomeDepthCacheCost, 0)
    lu.assertEquals(instance.routeSlots[13].kind, "preboss")
    lu.assertEquals(instance.routeSlots[13].label, "Preboss Room")
    lu.assertEquals(instance.routeSlots[13].branchKey, "MajorReward")
    lu.assertEquals(instance.routeSlots[13].roomHistoryCost, 0)
    lu.assertEquals(instance.routeSlots[13].branchValues, {
        "MajorReward",
    })
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Story",
        "Fountain",
        "Midshop",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "F_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Fountain, { "F_Reprieve01" })
    lu.assertEquals(instance.optionValuesByRole.Midshop, { "F_Shop01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")

    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 13)
    lu.assertEquals(storage[1].defaultRows, 13)
    lu.assertEquals(storage[1].maxRows, 13)
    lu.assertEquals(storage[1].row[1].key, "RoleKey")
    lu.assertEquals(storage[1].row[1].default, "")
    lu.assertEquals(storage[1].row[2].key, "OptionKey")
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 13)
    lu.assertEquals(storage[2].defaultRows, 13)
    lu.assertEquals(storage[2].maxRows, 13)
    lu.assertEquals(storage[2].row[1].key, "Reward1Key")
    lu.assertEquals(storage[2].row[6].key, "Reward6Key")
    lu.assertEquals(storage[2].row[7].key, "Reward1LootKey")
    lu.assertEquals(storage[2].row[12].key, "Reward6LootKey")
end

function TestRunPlannerFixedLinearRoute.testErebusSpecialRoomsUseSelectionDepthWindow()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})

    lu.assertEquals(instance.routeSlots[4].routeOrdinal, 3)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, rows, 4, "Story"), "F_Story01"))
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 4, "Story").F_Story01, valueStates.HIDDEN)

    lu.assertEquals(instance.routeSlots[5].routeOrdinal, 4)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, rows, 5, "Story"), "F_Story01"))
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 5, "Story").F_Story01, valueStates.HIDDEN)

    lu.assertEquals(instance.routeSlots[6].routeOrdinal, 5)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, rows, 6, "Story"), "F_Story01"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Story").F_Story01)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearEntryMetadataRendersIntroRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local cases = {
        { key = "G", name = "RouteG", rowCount = 10, introRoom = "G_Intro", prebossRow = 9 },
        { key = "P", name = "RouteP", rowCount = 11, introRoom = "P_Intro", prebossRow = 10 },
        { key = "Q", name = "RouteQ", rowCount = 8, introRoom = "Q_Intro", prebossRow = 8 },
    }

    for _, case in ipairs(cases) do
        local instance = template.prepare({
            name = case.name,
            biome = catalog.lookup[case.key],
        })
        lu.assertEquals(instance.routeRowCount, case.rowCount)
        lu.assertEquals(instance.routeSlots[1].routeOrdinal, 0)
        lu.assertEquals(instance.routeSlots[1].kind, "intro")
        lu.assertEquals(instance.routeSlots[1].label, "Intro")
        lu.assertEquals(instance.routeSlots[1].roomKey, case.introRoom)
        lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
        lu.assertEquals(instance.routeSlots[case.prebossRow].kind, "preboss")
    end
end

function TestRunPlannerFixedLinearRoute.testFixedLinearQShopSharedOfferGroupInvalidatesDuplicates()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {
            Reward1Key = "RandomLoot",
            Reward2Key = "RandomLoot",
        },
    }), instance)
    attachSingleBiomeRouteContext(control, "Surface", "Q")
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertFalse(snapshot.rows[8].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[8]).rewardKind, "shop")
    lu.assertEquals(snapshot.rows[8].invalidCode, "duplicate_shop_group_option")
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 8)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_shop_group_option")
end

function TestRunPlannerFixedLinearRoute.testFixedLinearOpeningRowUsesFixedRoomChoice()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            OptionKey = "F_Opening02",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
    })
    local values = {}

    data.fillRoleValues(instance, rows, 1, values)
    lu.assertEquals(values, {
        "Opening",
    })

    data.fillOptionValues(instance, rows, 1, "Opening", values)
    lu.assertEquals(values, {
        "",
        "F_Opening01",
        "F_Opening02",
        "F_Opening03",
    })

    local roleKey, role = data.resolveRole(instance, rows, 1)
    local optionKey, option = data.resolveOption(instance, rows, 1, roleKey)
    lu.assertEquals(roleKey, "Opening")
    lu.assertEquals(role.label, "Opening")
    lu.assertEquals(optionKey, "F_Opening02")
    lu.assertEquals(option.label, "Opening 2")
    lu.assertTrue(data.validateRow(instance, rows, 1).valid)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearPrebossRowsUseBranchChoices()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 12, values)
    lu.assertEquals(values, {
        "Shop",
    })

    data.fillOptionValues(instance, rows, 12, "Shop", values)
    lu.assertEquals(values, {})

    local roleKey, branch = data.resolveRole(instance, rows, 12)
    lu.assertEquals(roleKey, "Shop")
    lu.assertEquals(branch.label, "Preboss Shop")
    lu.assertTrue(data.validateRow(instance, rows, 12).valid)

    data.fillRoleValues(instance, rows, 13, values)
    lu.assertEquals(values, {
        "MajorReward",
    })

    roleKey, branch = data.resolveRole(instance, rows, 13)
    lu.assertEquals(roleKey, "MajorReward")
    lu.assertEquals(branch.label, "Preboss Room")
    lu.assertTrue(data.validateRow(instance, rows, 13).valid)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Combat",
                OptionKey = "Q_Combat03",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "Q_MiniBoss02",
                VariantKey = "Manual",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Missing",
                OptionKey = "Q_MiniBoss03",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "Q")
    lu.assertEquals(snapshot.adapter, "scriptedFixedLinear")
    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "unknown_role")
    lu.assertEquals(snapshot.invalidRows[1].locationLabel, "Summit Depth 4")
    lu.assertEquals(snapshot.rows[1].routeOrdinal, 0)
    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "Q_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Vanilla")
    lu.assertTrue(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[3].routeOrdinal, 2)
    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertTrue(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[4].routeOrdinal, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[4].role.key, "Miniboss")
    lu.assertEquals(snapshot.rows[4].optionKey, "Q_MiniBoss02")
    lu.assertEquals(snapshot.rows[4].option.label, "Brute")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].variantKey, "Manual")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewards[1], "Boon")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewards[2], "ZeusUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardKind, "roomStore")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardPicks, {
        {
            key = "rewardType",
            kind = "rewardType",
            alias = "Reward1Key",
            value = "Boon",
        },
        {
            key = "boonSource",
            kind = "boonSource",
            alias = "Reward2Key",
            value = "ZeusUpgrade",
        },
    })
    lu.assertEquals(snapshot.rows[4].rewardItems[1].address, "row")
    lu.assertEquals(snapshot.rows[4].rewardItems[1].sourceKind, "row")
    lu.assertEquals(snapshot.rows[4].rewardItems[1].rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[4].rewardItems[1].rewards[1], "Boon")
    lu.assertEquals(snapshot.rows[4].rewardItems[1].rewardPicks[2].value, "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[5].roleKey, "Missing")
    lu.assertEquals(snapshot.rows[5].invalidCode, "unknown_role")
    lu.assertFalse(snapshot.rows[5].valid)
    lu.assertEquals(snapshot.rows[5].optionKey, "Q_MiniBoss03")
    lu.assertNil(snapshot.rows[5].option)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeSnapshotsPrebossBranchRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
            {},
            { RoleKey = "" },
            { RoleKey = "" },
            { RoleKey = "Miniboss", OptionKey = "Q_MiniBoss02" },
            { RoleKey = "" },
            { RoleKey = "" },
            { RoleKey = "Miniboss", OptionKey = "Q_MiniBoss03" },
            { RoleKey = "" },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.rows, 8)
    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "Q_Intro")
    lu.assertEquals(snapshot.rows[8].routeOrdinal, 7)
    lu.assertEquals(snapshot.rows[8].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[8].roomKey, "Q_PreBoss01")
    lu.assertEquals(snapshot.rows[8].branchKey, "Shop")
    lu.assertEquals(snapshot.rows[8].roleKey, "Shop")
    lu.assertEquals(snapshot.rows[8].role.label, "Preboss Shop")
    lu.assertTrue(snapshot.rows[8].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[8]).rewardKind, "shop")
    lu.assertEquals(#primaryRewardItem(snapshot.rows[8]).rewardPicks, 0)
end

function TestRunPlannerFixedLinearRoute.testSingleRoomRolesDefaultToConcreteOption()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Story",
                OptionKey = "",
            },
        }), instance)
    local row = control:rowSnapshot(6)

    lu.assertEquals(row.roleKey, "Story")
    lu.assertEquals(row.optionKey, "F_Story01")
    lu.assertEquals(row.option.label, "Arachne")
end

function TestRunPlannerFixedLinearRoute.testFixedLinearValueStatesRolesByRouteRow()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Story"))
    lu.assertTrue(hasValue(values, "Fountain"))
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 2).Story, valueStates.HIDDEN)
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 2).Fountain, valueStates.HIDDEN)
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 2).Midshop, valueStates.HIDDEN)
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 2).Miniboss, valueStates.HIDDEN)

    rows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    })
    data.fillRoleValues(instance, rows, 6, values)
    lu.assertTrue(hasValue(values, "Story"))
    lu.assertTrue(hasValue(values, "Fountain"))
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Story)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Fountain)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Midshop)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Miniboss)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearValueStatesOptionsByRouteRow()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, ""))
    lu.assertTrue(hasValue(values, "F_Combat01"))
    lu.assertTrue(hasValue(values, "F_Combat05"))
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 2, "Combat").F_Combat05, valueStates.INVALID)

    rows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        { RoleKey = "Combat", OptionKey = "F_Combat04" },
    })
    data.fillOptionValues(instance, rows, 6, "Combat", values)
    lu.assertTrue(hasValue(values, "F_Combat05"))
    lu.assertTrue(hasValue(values, "F_Combat09"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").F_Combat05)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 6, "Combat").F_Combat09, valueStates.INVALID)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearValueStatesScriptedExactDepthOptions()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat10"))
    lu.assertTrue(hasValue(values, "Q_Combat11"))
    lu.assertTrue(hasValue(values, "Q_Combat03"))
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 2, "Combat").Q_Combat03, valueStates.HIDDEN)

    data.fillOptionValues(instance, rows, 3, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat03"))
    lu.assertTrue(hasValue(values, "Q_Combat05"))
    lu.assertTrue(hasValue(values, "Q_Combat15"))
    lu.assertTrue(hasValue(values, "Q_Combat10"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat03)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat10, valueStates.HIDDEN)

    data.fillOptionValues(instance, rows, 4, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss05"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 4, "Miniboss").Q_MiniBoss03, valueStates.HIDDEN)

    data.fillOptionValues(instance, rows, 7, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss04"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 7, "Miniboss").Q_MiniBoss03)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 7, "Miniboss").Q_MiniBoss02, valueStates.HIDDEN)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearValueStatesForcedDepthRoles()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 2).Miniboss, valueStates.HIDDEN)

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 4).Combat, valueStates.HIDDEN)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 4).Miniboss)

    data.fillRoleValues(instance, rows, 7, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 7).Combat, valueStates.HIDDEN)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 7).Miniboss)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearForcedDepthUsesBiomeDepthCache()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local biome = {}
    for key, value in pairs(catalog.lookup.Q) do
        biome[key] = value
    end
    biome.slotLayout = {}
    for key, value in pairs(catalog.lookup.Q.slotLayout) do
        biome.slotLayout[key] = value
    end
    biome.slotLayout.biomeDepthCacheStart = 0

    local instance = data.prepare({
        name = "RouteQ",
        biome = biome,
    })
    local rows = fakeRows({})
    local values = {}

    lu.assertEquals(data.rowContext(instance, rows, 4).routeOrdinal, 3)
    lu.assertEquals(data.rowContext(instance, rows, 4).biomeDepthCache, 2)
    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNotNil(data.roleValueStatesForRow(instance, rows, 4).Miniboss)

    lu.assertEquals(data.rowContext(instance, rows, 5).routeOrdinal, 4)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeDepthCache, 3)
    data.fillRoleValues(instance, rows, 5, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNotNil(data.roleValueStatesForRow(instance, rows, 5).Combat)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 5).Miniboss)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeInvalidatesForcedDepthRoles()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
            {
                RoleKey = "",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Combat",
                OptionKey = "Q_Combat01",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 4)
    lu.assertEquals(snapshot.invalidRows[1].code, "forced_depth_role")
    lu.assertEquals(snapshot.rows[4].routeOrdinal, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertFalse(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].invalidCode, "forced_depth_role")
end

function TestRunPlannerFixedLinearRoute.testFixedLinearAvailabilityConsumesPriorOneShotRoles()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Story",
            OptionKey = "F_Story01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
        },
        {
            RoleKey = "Story",
            OptionKey = "F_Story01",
        },
    })
    local values = {}

    data.fillRoleValues(instance, rows, 6, values)
    lu.assertTrue(hasValue(values, "Story"))

    data.fillRoleValues(instance, rows, 7, values)
    lu.assertTrue(hasValue(values, "Story"))
    lu.assertNotNil(data.roleValueStatesForRow(instance, rows, 7).Story)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearAvailabilityChecksPreviousRoomExitRequirement()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local missingExitRows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
    })
    local validExitRows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    })
    local values = {}

    data.fillRoleValues(instance, missingExitRows, 6, values)
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertNotNil(data.roleValueStatesForRow(instance, missingExitRows, 6).Midshop)

    data.fillRoleValues(instance, validExitRows, 6, values)
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertNil(data.roleValueStatesForRow(instance, validExitRows, 6).Midshop)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearReadPassInvalidationRefreshesCachedValues()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rowState = {
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
    }
    local rows = fakeRows(rowState)

    data.beginReadPass(instance)
    local values = data.roleValuesForRow(instance, rows, 6)
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertNotNil(data.roleValueStatesForRow(instance, rows, 6).Midshop)

    rowState[5].OptionKey = "F_Combat02"
    lu.assertNotNil(data.roleValueStatesForRow(instance, rows, 6).Midshop)

    data.invalidateReadPass(instance)
    lu.assertTrue(hasValue(data.roleValuesForRow(instance, rows, 6), "Midshop"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Midshop)
    data.endReadPass(instance)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRowContextUsesSelectionDepthCosts()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
        },
        {
            RoleKey = "Story",
            OptionKey = "F_Story01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
        },
    })

    lu.assertEquals(data.rowContext(instance, rows, 1), {
        rowIndex = 1,
        routeOrdinal = 0,
        biomeDepthCache = 0,
        biomeDepthCacheCost = 0,
        biomeEncounterDepth = 0,
        biomeEncounterDepthMin = 0,
        biomeEncounterDepthMax = 0,
        biomeEncounterDepthCost = 1,
        biomeEncounterDepthCostMin = 1,
        biomeEncounterDepthCostMax = 1,
        roomHistoryCost = 1,
    })
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeDepthCache, 3)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepth, 4)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthMin, 4)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthMax, 4)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCost, 0)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCostMin, 0)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCostMax, 0)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeDepthCache, 4)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepth, 4)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepthMin, 4)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepthMax, 4)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepthCost, 1)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepthCostMin, 1)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepthCostMax, 1)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearAmbiguousEncounterDepthBlocksUnprovenDepthGatedOptions()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat05",
        },
    })

    local context = data.rowContext(instance, rows, 3)
    lu.assertNil(context.biomeEncounterDepth)
    lu.assertEquals(context.biomeEncounterDepthMin, 1)
    lu.assertEquals(context.biomeEncounterDepthMax, 2)
    lu.assertFalse(data.isOptionAvailable(instance, rows, 3, "Combat", "F_Combat05"))

    local validation = data.validateRow(instance, rows, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "encounter_depth_unavailable")
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRowContextUsesOptionDepthCostOverrides()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "Q_Combat10",
        },
        {
            RoleKey = "Combat",
            OptionKey = "Q_Combat03",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "Q_MiniBoss02",
        },
        {
            RoleKey = "Combat",
            OptionKey = "Q_Combat04",
        },
        {
            RoleKey = "Combat",
            OptionKey = "Q_Combat12",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "Q_MiniBoss04",
        },
        {
            RoleKey = "Shop",
        },
    })

    lu.assertEquals(data.rowContext(instance, rows, 7).biomeDepthCache, 6)
    lu.assertEquals(data.rowContext(instance, rows, 7).biomeEncounterDepth, 5)
    lu.assertEquals(data.rowContext(instance, rows, 7).biomeEncounterDepthCost, 0)
    lu.assertEquals(data.rowContext(instance, rows, 8).biomeEncounterDepth, 5)
end

function TestRunPlannerFixedLinearRoute.testMinibossRequiresConcreteOption()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Miniboss",
        },
    })
    local values = {}

    data.fillOptionValues(instance, rows, 6, "Miniboss", values)
    lu.assertEquals(values[1], "F_MiniBoss01")

    local validation = data.validateRow(instance, rows, 6)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "option_required")
end

function TestRunPlannerFixedLinearRoute.testConcreteMinibossOptionUsesLeafDepthCost()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteP",
        biome = catalog.lookup.P,
    })
    local rows = fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "P_MiniBoss01",
        },
    })

    lu.assertTrue(data.validateRow(instance, rows, 5).valid)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCost, 0)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeUsesRouteRewardValidation()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), instance)
    control:setRouteContext({
        rewardRowValidation = function(_, routeKey, biomeKey, rowIndex)
            if routeKey == "Underworld" and biomeKey == "F" and rowIndex == 2 then
                return {
                    valid = false,
                    code = "route_reward",
                    message = "Route reward invalid",
                }
            end
            return nil
        end,
    }, "Underworld")

    local validation = control:rowValidation(2)

    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "route_reward")
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeRoutesRewardValueStateContext()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    }), instance)
    local seen = {}
    control:setRouteContext({
        rewardValueStates = function(
            _,
            routeKey,
            biomeKey,
            rowIndex,
            rewardAddress,
            controlAlias,
            surfaceControl,
            rewardFields,
            rewardContext
        )
            seen.routeKey = routeKey
            seen.biomeKey = biomeKey
            seen.rowIndex = rowIndex
            seen.rewardAddress = rewardAddress
            seen.controlAlias = controlAlias
            seen.surfaceControl = surfaceControl
            seen.rewardFields = rewardFields
            seen.rewardContext = rewardContext
            return {
                Boon = 2,
            }
        end,
    }, "Underworld")

    local rewardContext = {
        rowIndex = 2,
        address = "row",
    }
    local rewardFields = {
        rewardContext = rewardContext,
    }
    local surfaceControl = {
        alias = "Reward1Key",
    }
    local opts = control:rewardDrawOpts({
        hideGenericRewardLabel = true,
    })
    local states = opts.valueStatesForControl(surfaceControl, rewardFields, rewardContext)

    lu.assertEquals(states.Boon, 2)
    lu.assertEquals(seen.routeKey, "Underworld")
    lu.assertEquals(seen.biomeKey, "F")
    lu.assertEquals(seen.rowIndex, 2)
    lu.assertEquals(seen.rewardAddress, "row")
    lu.assertEquals(seen.controlAlias, "Reward1Key")
    lu.assertIs(seen.surfaceControl, surfaceControl)
    lu.assertIs(seen.rewardFields, rewardFields)
    lu.assertIs(seen.rewardContext, rewardContext)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeInvalidatesPreviousRoomExitRequirement()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            { RoleKey = "" },
	            { RoleKey = "Combat", OptionKey = "F_Combat02" },
	            { RoleKey = "Combat", OptionKey = "F_Combat03" },
	            {
                RoleKey = "Combat",
                OptionKey = "F_Combat01",
            },
	            {
	                RoleKey = "Midshop",
	                OptionKey = "F_Shop01",
	            },
	        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "previous_room_exit_count")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertFalse(snapshot.rows[5].valid)
    lu.assertEquals(snapshot.rows[5].invalidCode, "previous_room_exit_count")
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeInvalidatesOutOfRangeAndDuplicateRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            {
	                RoleKey = "",
	            },
	            {
	                RoleKey = "Story",
	                OptionKey = "F_Story01",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Story",
                OptionKey = "F_Story01",
            },
            {
                RoleKey = "Story",
                OptionKey = "F_Story01",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 2)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "biome_depth_unavailable")
    lu.assertEquals(snapshot.invalidRows[2].rowIndex, 7)
    lu.assertEquals(snapshot.invalidRows[2].code, "role_limit")
    lu.assertEquals(snapshot.rows[2].roleKey, "Story")
    lu.assertEquals(snapshot.rows[2].optionKey, "F_Story01")
    lu.assertFalse(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[6].roleKey, "Story")
    lu.assertEquals(snapshot.rows[6].optionKey, "F_Story01")
    lu.assertTrue(snapshot.rows[6].valid)
    lu.assertEquals(snapshot.rows[7].roleKey, "Story")
    lu.assertEquals(snapshot.rows[7].optionKey, "F_Story01")
    lu.assertFalse(snapshot.rows[7].valid)
    lu.assertEquals(snapshot.rows[7].invalidCode, "role_limit")
end
