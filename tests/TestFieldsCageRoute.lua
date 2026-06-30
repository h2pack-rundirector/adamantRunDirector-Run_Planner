local lu = require("luaunit")
local h = require("tests.support.control_harness")
local loadCatalog = h.loadCatalog
local loadFieldsCageTemplate = h.loadFieldsCageTemplate
local loadFieldsCageData = h.loadFieldsCageData
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw
local valueStates = dofile("src/mods/route/value_states.lua")

-- luacheck: globals TestRunPlannerFieldsCageRoute
TestRunPlannerFieldsCageRoute = {}

local function hCombatTwoRewardRow(optionKey, lootKey)
    return {
        RoleKey = "Combat",
        OptionKey = optionKey,
        VariantKey = "TwoRewards",
        SiblingStructureKey = "CombatCage2",
        Reward1Key = "Boon",
        Reward1LootKey = lootKey or "HestiaUpgrade",
        Reward2Key = "MaxHealthDrop",
    }
end

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
    lu.assertEquals(instance.routeSlots[6].kind, "preboss")
    lu.assertEquals(instance.routeSlots[6].label, "Preboss")
    lu.assertNil(instance.routeSlots[6].roomKey)
    lu.assertEquals(instance.routeSlots[6].roleKey, "Preboss")
    lu.assertEquals(instance.roleValues, {
        "Combat",
        "Miniboss",
        "Bridge",
    })
    lu.assertEquals(instance.roleLabels.Bridge, "Echo")
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "H_Combat01")
    lu.assertEquals(instance.optionValuesByRole.Bridge, {
        "H_Bridge01",
    })
    lu.assertEquals(instance.maxCageRewardCount, 3)

    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].minRows, 6)
    lu.assertEquals(storage[1].row[4].key, "SiblingStructureKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].minRows, 6)

    lu.assertEquals(routeData.cageCountLabelsForRole(instance, "Combat"), {
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
        "TwoRewards",
    })
    lu.assertEquals(routeData.cageCountValuesForRow(instance, fakeRows({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
        },
    }), 2, "Combat"), {
        "TwoRewards",
        "ThreeRewards",
    })
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingStructureRendersInRoomsView()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(2, "RoleKey"):write("Combat")
    fields.Rooms:get(2, "OptionKey"):write("H_Combat04")
    fields.Rooms:get(2, "VariantKey"):write("TwoRewards")
    fields.Rooms:get(3, "RoleKey"):write("Combat")
    fields.Rooms:get(3, "OptionKey"):write("H_Combat04")
    fields.Rooms:get(3, "VariantKey"):write("TwoRewards")
    local control = template.createUi(fields, instance)
    local draw = noOpDraw()
    local roomSiblingDropdownCount = 0
    local rewardSiblingDropdownCount = 0

    draw.widgets.dropdown = function(_, opts)
        if hasValue(opts.values or {}, "CombatCage2") and hasValue(opts.values or {}, "H_MiniBoss01") then
            roomSiblingDropdownCount = roomSiblingDropdownCount + 1
        end
        return false
    end
    template.views.rooms(draw, control, instance)

    draw.widgets.dropdown = function(_, opts)
        if hasValue(opts.values or {}, "CombatCage2") and hasValue(opts.values or {}, "H_MiniBoss01") then
            rewardSiblingDropdownCount = rewardSiblingDropdownCount + 1
        end
        return false
    end
    template.views.rewards(draw, control, instance)

    lu.assertEquals(roomSiblingDropdownCount, 1)
    lu.assertEquals(rewardSiblingDropdownCount, 0)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingStructureIsImplicitAtFirstPick()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(2, "RoleKey"):write("Combat")
    fields.Rooms:get(2, "OptionKey"):write("H_Combat04")
    fields.Rooms:get(2, "VariantKey"):write("TwoRewards")
    local control = template.createUi(fields, instance)
    local draw = noOpDraw()
    local siblingDropdownCount = 0

    draw.widgets.dropdown = function(_, opts)
        if hasValue(opts.values or {}, "CombatCage2") and hasValue(opts.values or {}, "H_MiniBoss01") then
            siblingDropdownCount = siblingDropdownCount + 1
        end
        return false
    end
    template.views.rooms(draw, control, instance)

    lu.assertEquals(siblingDropdownCount, 0)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingCountUsesPhysicalExits()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = fakeRows({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "ThreeRewards",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "ThreeRewards",
        },
    })

    lu.assertEquals(data.activeSiblingStructureCount(instance, rows, 3), 1)
end


function TestRunPlannerFieldsCageRoute.testFieldsCageEmitsDumbSelectedRowsSnapshot()
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
                SiblingStructureKey = "CombatCage3",
                Reward1Key = "Boon",
                Reward1LootKey = "PoseidonUpgrade",
                Reward2Key = "HermesUpgrade",
                Reward3Key = "StackUpgrade",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "ZeusUpgrade",
            },
        }), instance)

    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.schema, "selectedRows.v1")
    lu.assertEquals(snapshot.controlName, "RouteH")
    lu.assertEquals(snapshot.biomeKey, "H")
    lu.assertEquals(snapshot.adapter, "fieldsCageRoute")
    lu.assertNil(snapshot.rows[1].valid)
    lu.assertNil(snapshot.rows[1].roomTopology)
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertEquals(snapshot.rows[1].optionKey, "H_Intro")
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].variantKey, "ThreeRewards")
    lu.assertEquals(snapshot.rows[2].topology.siblings[1].structureKey, "CombatCage3")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[1], "Boon")
    lu.assertEquals(snapshot.rows[2].rewards.row.loot[1], "PoseidonUpgrade")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[2], "HermesUpgrade")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[3], "StackUpgrade")
    lu.assertEquals(snapshot.rows[3].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[3].optionKey, "H_MiniBoss01")
    lu.assertEquals(snapshot.rows[3].topology.siblings[1].structureKey, "CombatCage2")
    lu.assertEquals(snapshot.rows[3].rewards.row.values[1], "ZeusUpgrade")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageReadSelectedRowsSnapshot()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
        }), instance)

    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.schema, "selectedRows.v1")
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "H_Combat13")
    lu.assertEquals(snapshot.rows[2].variantKey, "TwoRewards")
end





















function TestRunPlannerFieldsCageRoute.testFieldsCageExportsDuplicateBoonSourcesInSameCageSet()
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
                SiblingStructureKey = "CombatCage3",
                Reward1Key = "Boon",
                Reward1LootKey = "PoseidonUpgrade",
                Reward2Key = "Boon",
                Reward2LootKey = "PoseidonUpgrade",
                Reward3Key = "HermesUpgrade",
            },
        }), instance)
    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.rows[2].rewards.row.values[1], "Boon")
    lu.assertEquals(snapshot.rows[2].rewards.row.loot[1], "PoseidonUpgrade")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[2], "Boon")
    lu.assertEquals(snapshot.rows[2].rewards.row.loot[2], "PoseidonUpgrade")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageExportsDuplicateNonBoonRewards()
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
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "MaxHealthDrop",
                Reward2Key = "MaxHealthDrop",
            },
        })
    local runtimeControl = template.createRuntime(fields, instance)
    local snapshot = runtimeControl:buildSelectedRowsSnapshot()
    lu.assertEquals(snapshot.rows[2].rewards.row.values[1], "MaxHealthDrop")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[2], "MaxHealthDrop")
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
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 2).Miniboss)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 2).Bridge)

    data.fillRoleValues(instance, rows, 3, values)
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 3).Miniboss)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 3).Bridge)

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Bridge"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 4).Bridge)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingValueStatesUseTopologyRules()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = fakeRows({})
    local unresolvedForceRows = fakeRows({
        {},
        hCombatTwoRewardRow("H_Combat13"),
        hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
        hCombatTwoRewardRow("H_Combat05", "ApolloUpgrade"),
    })

    lu.assertTrue(data.siblingStructureStatus(instance, rows, 2).valid)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 2).H_MiniBoss01)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 2).H_MiniBoss02)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 2).Bridge)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 2).CombatCage2)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 2).CombatCage3)

    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 3).H_MiniBoss01)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 3).H_MiniBoss02)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 3).Bridge)

    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 4).H_MiniBoss01)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 4).H_MiniBoss02)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 4).Bridge)

    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, unresolvedForceRows, 5).H_MiniBoss01, valueStates.INVALID)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, unresolvedForceRows, 5).H_MiniBoss02, valueStates.INVALID)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, unresolvedForceRows, 5).Bridge, valueStates.INVALID)
    lu.assertEquals(data.siblingStructureStatus(instance, rows, 6).code, "biome_depth_unavailable")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingValueStatesMarkMismatchedCombatCageCount()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local threeRewardRows = fakeRows({
        {},
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "ThreeRewards",
        },
    })
    local twoRewardRows = fakeRows({
        {},
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "TwoRewards",
        },
    })

    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, threeRewardRows, 3).CombatCage2, valueStates.INVALID)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, threeRewardRows, 3).CombatCage3)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, twoRewardRows, 3).CombatCage2)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, twoRewardRows, 3).CombatCage3, valueStates.INVALID)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingValueStatesMarkUnresolvedForcedTopology()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = fakeRows({
        {},
        hCombatTwoRewardRow("H_Combat13"),
        hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
        hCombatTwoRewardRow("H_Combat05", "ApolloUpgrade"),
        {
            RoleKey = "Miniboss",
            OptionKey = "H_MiniBoss01",
        },
    })

    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 5).CombatCage2, valueStates.INVALID)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 5).CombatCage3, valueStates.INVALID)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 5).H_MiniBoss02)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingValueStatesHidePlannedTopologyRooms()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = fakeRows({
        {},
        {},
        {},
        {
            RoleKey = "Miniboss",
            OptionKey = "H_MiniBoss02",
        },
    })

    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 3).H_MiniBoss01)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 3).H_MiniBoss02, valueStates.HIDDEN)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 5).H_MiniBoss01, valueStates.HIDDEN)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 5).H_MiniBoss02, valueStates.HIDDEN)
end
