local lu = require("luaunit")
local h = require("tests.support.control_harness")
local primaryRewardItem = h.primaryRewardItem
local loadCatalog = h.loadCatalog
local loadFieldsCageTemplate = h.loadFieldsCageTemplate
local loadFieldsCageData = h.loadFieldsCageData
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw
local attachSingleBiomeRouteContext = h.attachSingleBiomeRouteContext
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

function TestRunPlannerFieldsCageRoute.testFieldsCageRuntimeResolvesOnlyConcreteCageCount()
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
                OptionKey = "H_Combat13",
                VariantKey = "TwoRewards",
                Reward1Key = "Boon",
                Reward1LootKey = "HestiaUpgrade",
                Reward2Key = "MaxHealthDrop",
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat09",
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "Boon",
                Reward1LootKey = "HestiaUpgrade",
                Reward2Key = "WeaponUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[2].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "CombatCage2",
            rewardStore = "RunProgress",
            offerCount = 2,
            rewardAddresses = { "cage:1", "cage:2" },
        },
        sibling = {
            structure = "CombatCage2",
            rewardStore = "RunProgress",
            offerCount = 2,
        },
    })
    lu.assertEquals(snapshot.rows[3].variantKey, "TwoRewards")
    lu.assertEquals(snapshot.rows[3].cageRewardCount, 2)
    lu.assertEquals(snapshot.rows[3].roomTopology.selected.structure, "CombatCage2")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageSharedStructureSurvivesWhenRewardsDisabled()
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
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat09",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "CombatCage2",
            },
            {
                RoleKey = "Bridge",
                SiblingStructureKey = "H_MiniBoss02",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "CombatCage2",
            },
            {},
        }), instance)

    control:setRouteContext({
        isLayerConfigured = function(_, _, layer)
            return layer ~= "rewards"
        end,
        markDirty = function()
        end,
    }, "Underworld")

    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[2].exitCount, 2)
    lu.assertEquals(snapshot.rows[2].rewardExitCount, 2)
    lu.assertNil(snapshot.rows[2].rewardKind)
    lu.assertEquals(snapshot.rows[2].rewardItems[1].rewardKind, "vanilla")
    lu.assertNil(snapshot.rows[2].rewardItems[2])
    lu.assertEquals(snapshot.rows[2].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "CombatCage3",
            rewardStore = "RunProgress",
            offerCount = 3,
            rewardAddresses = { "cage:1", "cage:2", "cage:3" },
        },
        sibling = {
            structure = "CombatCage3",
            rewardStore = "RunProgress",
            offerCount = 3,
        },
    })
    lu.assertEquals(snapshot.rows[3].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "CombatCage2",
            rewardStore = "RunProgress",
            offerCount = 2,
            rewardAddresses = { "cage:1", "cage:2" },
        },
        sibling = {
            structure = "CombatCage2",
            rewardStore = "RunProgress",
            offerCount = 2,
        },
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
                SiblingStructureKey = "CombatCage3",
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
    lu.assertEquals(snapshot.rows[1].exitCount, 2)
    lu.assertEquals(snapshot.rows[1].rewardExitCount, 2)
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "none")

    lu.assertEquals(snapshot.rows[2].slotKind, "biomeRow")
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].roomKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].exitCount, 2)
    lu.assertEquals(snapshot.rows[2].rewardExitCount, 2)
    lu.assertEquals(snapshot.rows[2].variantKey, "ThreeRewards")
    lu.assertEquals(snapshot.rows[2].cagePolicyKey, "H_FieldsCageRewards")
    lu.assertEquals(snapshot.rows[2].cageRewardCount, 3)
    lu.assertEquals(snapshot.rows[2].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "CombatCage3",
            rewardStore = "RunProgress",
            offerCount = 3,
            rewardAddresses = { "cage:1", "cage:2", "cage:3" },
        },
        sibling = {
            structure = "CombatCage3",
            rewardStore = "RunProgress",
            offerCount = 3,
        },
    })
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
    lu.assertEquals(snapshot.rows[3].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "CombatCage2",
            rewardStore = "RunProgress",
            offerCount = 2,
            rewardAddresses = { "cage:1", "cage:2" },
        },
        sibling = {
            structure = "CombatCage2",
            rewardStore = "RunProgress",
            offerCount = 2,
        },
    })
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "fieldsCages")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardSourceCount, 2)
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[2].value, "HestiaUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks[3].value, "WeaponUpgrade")

    lu.assertEquals(snapshot.rows[4].roleKey, "Bridge")
    lu.assertEquals(snapshot.rows[4].role.label, "Echo")
    lu.assertEquals(snapshot.rows[4].optionKey, "H_Bridge01")
    lu.assertEquals(snapshot.rows[4].roomKey, "H_Bridge01")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "Bridge",
            offerCount = 0,
        },
        sibling = {
            structure = "Miniboss",
            roomKey = "H_MiniBoss02",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
        },
    })
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardKind, "none")

    lu.assertEquals(snapshot.rows[5].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[5].optionKey, "H_MiniBoss01")
    lu.assertEquals(snapshot.rows[5].roomKey, "H_MiniBoss01")
    lu.assertEquals(snapshot.rows[5].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "Miniboss",
            roomKey = "H_MiniBoss01",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        },
        sibling = {
            structure = "CombatCage2",
            rewardStore = "RunProgress",
            offerCount = 2,
        },
    })
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardKind, "boonSource")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[1].value, "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[6].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[6].slotLabel, "Preboss")
    lu.assertNil(snapshot.rows[6].roomKey)
    lu.assertEquals(snapshot.rows[6].roleKey, "Preboss")
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardKind, "shop")
    lu.assertEquals(snapshot.rows[6].rewardItems[2].address, "prebossReward")
    lu.assertEquals(snapshot.rows[6].rewardItems[2].rewardKind, "roomStore")
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

function TestRunPlannerFieldsCageRoute.testFieldsCageRequiresPickedCageCountForTopology()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                SiblingStructureKey = "CombatCage2",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 3)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_cage_count_required")
    lu.assertEquals(snapshot.rows[3].invalidCode, "fields_cage_count_required")
    lu.assertNil(snapshot.rows[3].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRequiresSiblingStructureForTopology()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = {
            {},
            hCombatTwoRewardRow("H_Combat13"),
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                VariantKey = "TwoRewards",
            },
        }
    local control = template.createRuntime(routeFields(rows), instance)
    local snapshot = control:buildSnapshot()
    local data = loadFieldsCageData()
    local routeRows = fakeRows(rows)

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 3)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_sibling_structure_required")
    lu.assertEquals(snapshot.invalidRows[1].tabKey, "rooms")
    lu.assertEquals(snapshot.invalidRows[1].controlTargets, {
        {
            tabKey = "rooms",
            controlAlias = "SiblingStructureKey",
            state = valueStates.INVALID,
            mode = "selected",
        },
    })
    lu.assertEquals(snapshot.rows[3].invalidCode, "fields_sibling_structure_required")
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, routeRows, 3)[""], valueStates.INVALID)
    lu.assertNil(snapshot.rows[3].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsMismatchedSiblingCombatCageCount()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat09"),
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                VariantKey = "ThreeRewards",
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "Boon",
                Reward1LootKey = "PoseidonUpgrade",
                Reward2Key = "HermesUpgrade",
                Reward3Key = "StackUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 3)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_sibling_combat_cage_count_mismatch")
    lu.assertEquals(snapshot.rows[3].invalidCode, "fields_sibling_combat_cage_count_mismatch")
    lu.assertNil(snapshot.rows[3].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsPreviouslyGeneratedSiblingRoom()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local template = loadFieldsCageTemplate()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = fakeRows({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat04",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "H_MiniBoss01",
                Reward1Key = "Boon",
                Reward1LootKey = "PoseidonUpgrade",
                Reward2Key = "WeaponUpgrade",
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "H_MiniBoss01",
                Reward1Key = "Boon",
                Reward1LootKey = "ApolloUpgrade",
                Reward2Key = "StackUpgrade",
            },
        })

    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 4).H_MiniBoss01, valueStates.HIDDEN)

    instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat04",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "H_MiniBoss01",
                Reward1Key = "Boon",
                Reward1LootKey = "PoseidonUpgrade",
                Reward2Key = "WeaponUpgrade",
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "H_MiniBoss01",
                Reward1Key = "Boon",
                Reward1LootKey = "ApolloUpgrade",
                Reward2Key = "StackUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 4)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_sibling_room_generated")
    lu.assertEquals(snapshot.rows[4].invalidCode, "fields_sibling_room_generated")
    lu.assertNil(snapshot.rows[4].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsUnresolvedForcedTopologyAtDeadline()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Bridge",
                SiblingStructureKey = "CombatCage2",
            },
            hCombatTwoRewardRow("H_Combat06", "ZeusUpgrade"),
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_forced_topology_group_unresolved")
    lu.assertEquals(snapshot.rows[5].invalidCode, "fields_forced_topology_group_unresolved")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsPickThreeMissingForcedBridgePressure()
    local catalog = loadCatalog()
    local data = loadFieldsCageData()
    local template = loadFieldsCageTemplate()
    local instance = data.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local rows = fakeRows({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "ZeusUpgrade",
            },
        })
    local states = data.siblingStructureValueStatesForRow(instance, rows, 4)

    lu.assertEquals(states.CombatCage2, valueStates.INVALID)
    lu.assertNil(states.Bridge)
    lu.assertNil(states.H_MiniBoss02)

    instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "ZeusUpgrade",
            },
            hCombatTwoRewardRow("H_Combat05", "ApolloUpgrade"),
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 4)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_forced_topology_pressure_unresolved")
    lu.assertEquals(snapshot.rows[4].invalidCode, "fields_forced_topology_pressure_unresolved")
    lu.assertNil(snapshot.rows[4].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageAllowsPickThreeBridgeWithCombat()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Bridge",
                SiblingStructureKey = "CombatCage2",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "H_MiniBoss02",
                Reward1Key = "ZeusUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[4].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "Bridge",
            offerCount = 0,
        },
        sibling = {
            structure = "CombatCage2",
            rewardStore = "RunProgress",
            offerCount = 2,
        },
    })
end

function TestRunPlannerFieldsCageRoute.testFieldsCageAllowsPickThreeMinibossPairToMissBridge()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "H_MiniBoss02",
                Reward1Key = "ZeusUpgrade",
            },
            hCombatTwoRewardRow("H_Combat05", "ApolloUpgrade"),
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[4].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "Miniboss",
            roomKey = "H_MiniBoss01",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        },
        sibling = {
            structure = "Miniboss",
            roomKey = "H_MiniBoss02",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
        },
    })
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsLateSingleMinibossTopology()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat09"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Bridge",
                SiblingStructureKey = "H_MiniBoss02",
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "Boon",
                Reward1LootKey = "ApolloUpgrade",
                Reward2Key = "StackUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_forced_topology_group_unresolved")
    lu.assertEquals(snapshot.rows[5].invalidCode, "fields_forced_topology_group_unresolved")
    lu.assertNil(snapshot.rows[5].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageAllowsLatePairedMinibossTopology()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat09"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
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
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[4].roomTopology.sibling.roomKey, "H_MiniBoss02")
    lu.assertEquals(snapshot.rows[5].roomTopology.selected.roomKey, "H_MiniBoss01")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageEarlyPickedMinibossClosesForcedTopologyGroup()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat09"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "Bridge",
                Reward1Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "Boon",
                Reward1LootKey = "HestiaUpgrade",
                Reward2Key = "WeaponUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[5].roomTopology.selected.structure, "CombatCage2")
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsSiblingStructureOutsideDepthWindow()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat09"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss02",
                SiblingStructureKey = "H_MiniBoss01",
                Reward1Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "Bridge",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_sibling_structure_unavailable")
    lu.assertEquals(snapshot.rows[5].invalidCode, "fields_sibling_structure_unavailable")
    lu.assertNil(snapshot.rows[5].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsSiblingStructureMatchingSelectedRoom()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "H_MiniBoss01",
                Reward1Key = "ZeusUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 3)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_sibling_same_room")
    lu.assertEquals(snapshot.rows[3].invalidCode, "fields_sibling_same_room")
    lu.assertNil(snapshot.rows[3].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageAllowsSiblingStructureWithDifferentMinibossRoom()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat09"),
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss01",
                SiblingStructureKey = "H_MiniBoss02",
                Reward1Key = "ZeusUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[3].roomTopology, {
        kind = "fieldsChoice",
        selected = {
            structure = "Miniboss",
            roomKey = "H_MiniBoss01",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        },
        sibling = {
            structure = "Miniboss",
            roomKey = "H_MiniBoss02",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
        },
    })
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsSiblingRoomPlannedElsewhere()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat13"),
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat09",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "H_MiniBoss02",
                Reward1Key = "Boon",
                Reward1LootKey = "HestiaUpgrade",
                Reward2Key = "WeaponUpgrade",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss02",
                SiblingStructureKey = "CombatCage2",
                Reward1Key = "ZeusUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 3)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_sibling_room_planned")
    lu.assertEquals(snapshot.rows[3].invalidCode, "fields_sibling_room_planned")
    lu.assertNil(snapshot.rows[3].roomTopology)
end

function TestRunPlannerFieldsCageRoute.testFieldsCageRejectsMinibossSiblingAfterPickedMiniboss()
    local catalog = loadCatalog()
    local template = loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(routeFields({
            {},
            hCombatTwoRewardRow("H_Combat09"),
            hCombatTwoRewardRow("H_Combat04", "PoseidonUpgrade"),
            {
                RoleKey = "Miniboss",
                OptionKey = "H_MiniBoss02",
                SiblingStructureKey = "Bridge",
                Reward1Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat05",
                VariantKey = "TwoRewards",
                SiblingStructureKey = "H_MiniBoss01",
                Reward1Key = "Boon",
                Reward1LootKey = "HestiaUpgrade",
                Reward2Key = "WeaponUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "fields_sibling_miniboss_after_selected")
    lu.assertEquals(snapshot.rows[5].invalidCode, "fields_sibling_miniboss_after_selected")
    lu.assertNil(snapshot.rows[5].roomTopology)
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
                SiblingStructureKey = "CombatCage3",
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
                SiblingStructureKey = "CombatCage2",
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

function TestRunPlannerFieldsCageRoute.testFieldsCageSiblingValueStatesUseRoomAvailability()
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
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 2).H_MiniBoss01, valueStates.HIDDEN)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 2).H_MiniBoss02, valueStates.HIDDEN)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 2).Bridge, valueStates.HIDDEN)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 2).CombatCage2)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 2).CombatCage3)

    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 3).H_MiniBoss01)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 3).H_MiniBoss02)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 3).Bridge, valueStates.HIDDEN)

    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 4).H_MiniBoss01)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 4).H_MiniBoss02)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 4).Bridge)

    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, unresolvedForceRows, 5).H_MiniBoss01, valueStates.INVALID)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, unresolvedForceRows, 5).H_MiniBoss02, valueStates.INVALID)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, unresolvedForceRows, 5).Bridge, valueStates.HIDDEN)
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
