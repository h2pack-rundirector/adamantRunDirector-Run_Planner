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

-- luacheck: globals TestRunPlannerFieldsCageRoute
TestRunPlannerFieldsCageRoute = {}

local function hCombatTwoRewardRow(optionKey, lootKey)
    return {
        RoleKey = "Combat",
        OptionKey = optionKey,
        VariantKey = "TwoRewards",
        OtherDoorKey = "CombatCage2",
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
    lu.assertEquals(storage[1].row[4].key, "OtherDoorKey")
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

function TestRunPlannerFieldsCageRoute.testFieldsCageOtherDoorRendersInRoomsView()
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

    lu.assertEquals(roomSiblingDropdownCount, 2)
    lu.assertEquals(rewardSiblingDropdownCount, 0)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRoomsViewEditsNextPickedDoor()
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
    fields.Rooms:get(3, "OptionKey"):write("H_Combat05")
    fields.Rooms:get(3, "VariantKey"):write("TwoRewards")
    local control = template.createUi(fields, instance)
    local row3RoleField = fields.Rooms:get(3, "RoleKey")
    local row3OptionField = fields.Rooms:get(3, "OptionKey")
    local row3VariantField = fields.Rooms:get(3, "VariantKey")
    local row3SiblingField = fields.Rooms:get(3, "OtherDoorKey")
    local row3RoleDropdowns = 0
    local row3OptionDropdowns = 0
    local row3VariantDropdowns = 0
    local row3SiblingDropdowns = 0
    local draw = noOpDraw()

    draw.widgets.dropdown = function(field)
        if field == row3RoleField then
            row3RoleDropdowns = row3RoleDropdowns + 1
        elseif field == row3OptionField then
            row3OptionDropdowns = row3OptionDropdowns + 1
        elseif field == row3VariantField then
            row3VariantDropdowns = row3VariantDropdowns + 1
        elseif field == row3SiblingField then
            row3SiblingDropdowns = row3SiblingDropdowns + 1
        end
        return false
    end

    template.views.rooms(draw, control, instance)

    lu.assertEquals(row3RoleDropdowns, 1)
    lu.assertEquals(row3OptionDropdowns, 1)
    lu.assertEquals(row3VariantDropdowns, 1)
    lu.assertEquals(row3SiblingDropdowns, 1)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRoomsViewShowsMinibossOptionsForPickedDoor()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(2, "RoleKey"):write("Miniboss")
    local control = template.createUi(fields, instance)
    local row2OptionField = fields.Rooms:get(2, "OptionKey")
    local optionValues
    local draw = noOpDraw()

    draw.widgets.dropdown = function(field, opts)
        if field == row2OptionField then
            optionValues = opts.values
        end
        return false
    end

    template.views.rooms(draw, control, instance)

    lu.assertEquals(optionValues, {
        "H_MiniBoss01",
        "H_MiniBoss02",
    })
end

function TestRunPlannerFieldsCageRoute.testFieldsCageOtherDoorUsesCurrentRoomExits()
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

    lu.assertEquals(siblingDropdownCount, 1)
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

    lu.assertEquals(data.activeOtherDoorCount(instance, rows, 2), 1)
    lu.assertEquals(data.activeOtherDoorCount(instance, rows, 3), 1)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageTerminalCombatRequiresCageCount()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat04"),
            hCombatTwoRewardRow("H_Combat05"),
            hCombatTwoRewardRow("H_Combat06"),
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat07",
                Reward1Key = "Boon",
                Reward1LootKey = "DemeterUpgrade",
            },
        }), instance)

    local completion = control:read("completion")

    lu.assertFalse(completion.valid)
    lu.assertEquals(completion.completionInvalidRows[1].rowIndex, 5)
    lu.assertEquals(completion.completionInvalidRows[1].code, "fields_cage_count_required")
    lu.assertEquals(completion.completionInvalidRows[1].message, "Choose Picked Door reward count")
    lu.assertEquals(completion.completionInvalidRows[1].controlTargets[1].controlAlias, "VariantKey")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageTerminalRowDoesNotExportHiddenSibling()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat04"),
            hCombatTwoRewardRow("H_Combat05"),
            hCombatTwoRewardRow("H_Combat06"),
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat07",
                VariantKey = "TwoRewards",
                OtherDoorKey = "CombatCage3",
                Reward1Key = "Boon",
                Reward1LootKey = "DemeterUpgrade",
                Reward2Key = "StackUpgrade",
            },
        }), instance)

    local completion = control:read("completion")
    local snapshot = control:read("selectedNodesSnapshot")

    lu.assertTrue(completion.valid)
    lu.assertNil(snapshot.nodes[5].nextChoices.otherDoors)
end



function TestRunPlannerFieldsCageRoute.testFieldsCageEmitsSelectedNodesSnapshot()
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
                OtherDoorKey = "CombatCage3",
                Reward1Key = "Boon",
                Reward1LootKey = "PoseidonUpgrade",
                Reward2Key = "HermesUpgrade",
                Reward3Key = "StackUpgrade",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                OtherDoorKey = "CombatCage2",
                Reward1Key = "ZeusUpgrade",
            },
        }), instance)

    local snapshot = control:buildSelectedNodesSnapshot()

    lu.assertEquals(snapshot.schema, "selectedNodes.v1")
    lu.assertEquals(snapshot.controlName, "RouteH")
    lu.assertEquals(snapshot.biomeKey, "H")
    lu.assertEquals(snapshot.adapter, "fieldsCageRoute")

    lu.assertEquals(snapshot.nodes[1].currentRoom.roleKey, "Intro")
    lu.assertEquals(snapshot.nodes[1].currentRoom.optionKey, "H_Intro")
    lu.assertEquals(snapshot.nodes[1].currentRoom.formAddress, { rowIndex = 1 })
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.targetRowIndex, 2)
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.roleKey, "Combat")
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.optionKey, "H_Combat04")
    lu.assertNil(snapshot.nodes[1].nextChoices.otherDoors)

    lu.assertEquals(snapshot.nodes[2].currentRoom.roleKey, "Combat")
    lu.assertEquals(snapshot.nodes[2].currentRoom.optionKey, "H_Combat04")
    lu.assertEquals(snapshot.nodes[2].currentRoom.variantKey, "ThreeRewards")
    lu.assertEquals(snapshot.nodes[2].currentRoom.formAddress, { rowIndex = 2 })
    lu.assertEquals(snapshot.nodes[2].nextChoices.picked.targetRowIndex, 3)
    lu.assertEquals(snapshot.nodes[2].nextChoices.picked.roleKey, "Miniboss")
    lu.assertEquals(snapshot.nodes[2].nextChoices.picked.optionKey, "H_MiniBoss01")
    lu.assertEquals(snapshot.nodes[2].nextChoices.otherDoors[1], {
        doorIndex = 1,
        structureKey = "CombatCage3",
        formAddress = {
            rowIndex = 2,
            childKind = "otherDoor",
            childIndex = 1,
        },
    })
    lu.assertEquals(snapshot.nodes[2].rewards.row.values[1], "Boon")
    lu.assertEquals(snapshot.nodes[2].rewards.row.loot[1], "PoseidonUpgrade")
    lu.assertEquals(snapshot.nodes[2].rewards.row.values[2], "HermesUpgrade")
    lu.assertEquals(snapshot.nodes[2].rewards.row.values[3], "StackUpgrade")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageReadSelectedNodesSnapshot()
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

    local snapshot = control:read("selectedNodesSnapshot")

    lu.assertEquals(snapshot.schema, "selectedNodes.v1")
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.roleKey, "Combat")
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.optionKey, "H_Combat13")
    lu.assertEquals(snapshot.nodes[2].currentRoom.variantKey, "TwoRewards")
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
                OtherDoorKey = "CombatCage3",
                Reward1Key = "Boon",
                Reward1LootKey = "PoseidonUpgrade",
                Reward2Key = "Boon",
                Reward2LootKey = "PoseidonUpgrade",
                Reward3Key = "HermesUpgrade",
            },
        }), instance)
    local snapshot = control:read("selectedNodesSnapshot")

    lu.assertEquals(snapshot.nodes[2].rewards.row.values[1], "Boon")
    lu.assertEquals(snapshot.nodes[2].rewards.row.loot[1], "PoseidonUpgrade")
    lu.assertEquals(snapshot.nodes[2].rewards.row.values[2], "Boon")
    lu.assertEquals(snapshot.nodes[2].rewards.row.loot[2], "PoseidonUpgrade")
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
                OtherDoorKey = "CombatCage2",
                Reward1Key = "MaxHealthDrop",
                Reward2Key = "MaxHealthDrop",
            },
        })
    local runtimeControl = template.createRuntime(fields, instance)
    local snapshot = runtimeControl:read("selectedNodesSnapshot")
    lu.assertEquals(snapshot.nodes[2].rewards.row.values[1], "MaxHealthDrop")
    lu.assertEquals(snapshot.nodes[2].rewards.row.values[2], "MaxHealthDrop")
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

    lu.assertTrue(data.otherDoorStatus(instance, rows, 2).valid)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 2).H_MiniBoss01)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 2).H_MiniBoss02)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 2).Bridge)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 2).CombatCage2)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 2).CombatCage3)

    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 3).H_MiniBoss01)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 3).H_MiniBoss02)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 3).Bridge)

    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 4).H_MiniBoss01)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 4).H_MiniBoss02)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 4).Bridge)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingValueStatesDoNotOwnCombatCageCountMatching()
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

    lu.assertNil(data.otherDoorValueStatesForRow(instance, threeRewardRows, 3).CombatCage2)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, threeRewardRows, 3).CombatCage3)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, twoRewardRows, 3).CombatCage2)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, twoRewardRows, 3).CombatCage3)
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

    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 5).CombatCage2)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 5).CombatCage3)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 5).H_MiniBoss02)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingValueStatesDoNotOwnPlannedTopologyRooms()
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

    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 3).H_MiniBoss01)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 3).H_MiniBoss02)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 5).H_MiniBoss01)
    lu.assertNil(data.otherDoorValueStatesForRow(instance, rows, 5).H_MiniBoss02)
end
