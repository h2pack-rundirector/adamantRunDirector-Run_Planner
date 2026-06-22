local lu = require("luaunit")
local h = require("tests.support.control_harness")
local primaryRewardItem = h.primaryRewardItem
local loadCatalog = h.loadCatalog
local loadFieldsCageTemplate = h.loadFieldsCageTemplate
local loadFieldsCageData = h.loadFieldsCageData
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local attachSingleBiomeRouteContext = h.attachSingleBiomeRouteContext
local valueStates = dofile("src/mods/route/value_states.lua")

-- luacheck: globals TestRunPlannerFieldsCageRoute
TestRunPlannerFieldsCageRoute = {}

function TestRunPlannerFieldsCageRoute.testFieldsCageStorageMatchesFieldsRouteRows()
    local catalog = loadCatalog()
    local routeData = loadFieldsCageData()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 6)
    lu.assertEquals(instance.routeSlots[1].kind, "fixedBeforeRoute")
    lu.assertEquals(instance.routeSlots[1].label, "Intro")
    lu.assertEquals(instance.routeSlots[1].roomKey, "H_Intro")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
    lu.assertEquals(instance.routeSlots[2].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[2].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[2].label, "Pick 1")
    lu.assertEquals(instance.routeSlots[5].routeOrdinal, 4)
    lu.assertEquals(instance.routeSlots[5].label, "Pick 4")
    lu.assertEquals(instance.routeSlots[6].kind, "fixedAfterRoute")
    lu.assertEquals(instance.routeSlots[6].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[6].roomKey, "H_PreBoss01")
    lu.assertEquals(instance.routeSlots[6].roleKey, "Preboss")
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Miniboss",
        "Bridge",
    })
    lu.assertEquals(instance.roleLabels.Bridge, "Echo")
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")
    lu.assertEquals(instance.optionValuesByRole.Bridge, {
        "H_Bridge01",
    })
    lu.assertEquals(instance.maxCageRewardCount, 3)

    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].minRows, 6)
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].minRows, 6)

    lu.assertEquals(routeData.cageCountLabelsForRole(instance, "Combat"), {
        [""] = "Vanilla",
        TwoRewards = "2 Rewards",
        ThreeRewards = "3 Rewards",
    })
    lu.assertEquals(routeData.cageCountValuesForRow(instance, fakeRows({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat09",
        },
    }), 2, "Combat"), {
        "",
        "TwoRewards",
    })
    lu.assertEquals(routeData.cageCountValuesForRow(instance, fakeRows({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
        },
    }), 2, "Combat"), {
        "",
        "TwoRewards",
        "ThreeRewards",
    })
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
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
                Reward1Key = "Boon",
                Reward1LootKey = "HestiaUpgrade",
                Reward2Key = "WeaponUpgrade",
            },
            {
                RoleKey = "Bridge",
                OptionKey = "",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                Reward1Key = "ZeusUpgrade",
            },
            {},
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "H")
    lu.assertEquals(snapshot.adapter, "fieldsCageRoute")
    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.rows, 6)

    lu.assertEquals(snapshot.rows[1].slotKind, "fixedBeforeRoute")
    lu.assertEquals(snapshot.rows[1].slotLabel, "Intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "H_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "none")

    lu.assertEquals(snapshot.rows[2].slotKind, "biomeRow")
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].roomKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].variantKey, "ThreeRewards")
    lu.assertEquals(snapshot.rows[2].cagePolicyKey, "H_FieldsCageRewards")
    lu.assertEquals(snapshot.rows[2].cageRewardCount, 3)
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardKind, "fieldsCages")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardSourceCount, 3)
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardPicks[1].value, "Boon")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardPicks[2].value, "PoseidonUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardPicks[2].alias, "Reward1LootKey")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardPicks[3].value, "HermesUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardPicks[4].value, "StackUpgrade")

    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[3].optionKey, "H_Combat09")
    lu.assertEquals(snapshot.rows[3].cageRewardCount, 2)
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "fieldsCages")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardSourceCount, 2)
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[2].value, "HestiaUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[3].value, "WeaponUpgrade")

    lu.assertEquals(snapshot.rows[4].roleKey, "Bridge")
    lu.assertEquals(snapshot.rows[4].role.label, "Echo")
    lu.assertEquals(snapshot.rows[4].optionKey, "H_Bridge01")
    lu.assertEquals(snapshot.rows[4].roomKey, "H_Bridge01")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardKind, "none")

    lu.assertEquals(snapshot.rows[5].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[5].optionKey, "H_MiniBoss01")
    lu.assertEquals(snapshot.rows[5].roomKey, "H_MiniBoss01")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardKind, "boonSource")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[1].value, "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[6].slotKind, "fixedAfterRoute")
    lu.assertEquals(snapshot.rows[6].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[6].roomKey, "H_PreBoss01")
    lu.assertEquals(snapshot.rows[6].roleKey, "Preboss")
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardKind, "shop")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRuntimeInvalidatesCageCountAboveMapCapacity()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat09",
                VariantKey = "ThreeRewards",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "cage_count_exceeds_map")
    lu.assertEquals(snapshot.rows[2].invalidCode, "cage_count_exceeds_map")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRuntimeInvalidatesForcedCageRewardsWithoutMap()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "",
                VariantKey = "TwoRewards",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "cage_count_requires_map")
    lu.assertEquals(snapshot.rows[2].invalidCode, "cage_count_requires_map")
end

function TestRunPlannerFieldsCageRoute.testFieldsCagePolicyRejectsDuplicateBoonSourcesInSameCageSet()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat04",
                VariantKey = "ThreeRewards",
                Reward1Key = "Boon",
                Reward1LootKey = "PoseidonUpgrade",
                Reward2Key = "Boon",
                Reward2LootKey = "PoseidonUpgrade",
                Reward3Key = "HermesUpgrade",
            },
        }), instance)
    attachSingleBiomeRouteContext(control, "Underworld", "H")
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_boon_source")
    lu.assertEquals(snapshot.rows[2].invalidCode, "duplicate_boon_source")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRuntimePolicyRejectsDuplicateNonBoonRewards()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local fields = routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat04",
                VariantKey = "TwoRewards",
                Reward1Key = "MaxHealthDrop",
                Reward2Key = "MaxHealthDrop",
            },
        })
    local runtimeControl = template.createRuntime(fields, instance)
    attachSingleBiomeRouteContext(runtimeControl, "Underworld", "H")

    local row = runtimeControl:rowSnapshot(2)
    lu.assertFalse(row.valid)
    lu.assertEquals(row.invalidCode, "duplicate_reward_type")

    local snapshot = runtimeControl:buildSnapshot()
    lu.assertFalse(snapshot.valid)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_reward_type")
    lu.assertEquals(snapshot.rows[2].invalidCode, "duplicate_reward_type")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageValueStatesEchoBeforeThirdPick()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 2).Miniboss, valueStates.HIDDEN)
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 2).Bridge, valueStates.HIDDEN)

    data.fillRoleValues(instance, rows, 3, values)
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 3).Miniboss)
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 3).Bridge, valueStates.HIDDEN)

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 4).Bridge)
end
