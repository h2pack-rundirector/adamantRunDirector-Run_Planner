local lu = require("luaunit")
local h = require("tests.support.control_harness")
local primaryRewardItem = h.primaryRewardItem
local loadCatalog = h.loadCatalog
local loadFixedLinearTemplate = h.loadFixedLinearTemplate
local loadFixedLinearData = h.loadFixedLinearData
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw
local attachSingleBiomeRouteContext = h.attachSingleBiomeRouteContext
local valueStates = dofile("src/mods/route/value_states.lua")

-- luacheck: globals TestRunPlannerFixedLinearRoute
TestRunPlannerFixedLinearRoute = {}

local function drawRoomsWithOptionChange(template, control, instance, nextOptionKey)
    local draw = noOpDraw()
    draw.widgets.dropdown = function(field, opts)
        if hasValue(opts.values or {}, nextOptionKey) then
            field:write(nextOptionKey)
            return true
        end
        return false
    end
    template.views.rooms(draw, control, instance)
end

local function fOpeningRow()
    return { OptionKey = "F_Opening01" }
end

local function fCombatRow(optionKey, rewardKey, siblingKey)
    return {
        RoleKey = "Combat",
        OptionKey = optionKey,
        Reward1Key = rewardKey,
        SiblingStructureKey = siblingKey,
    }
end

local function qCombatRow(optionKey)
    return {
        RoleKey = "Combat",
        OptionKey = optionKey,
    }
end

local function qMinibossRow(optionKey)
    return {
        RoleKey = "Miniboss",
        OptionKey = optionKey,
    }
end

function TestRunPlannerFixedLinearRoute.testFixedLinearStorageMatchesRouteRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 12)
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
    lu.assertEquals(instance.routeSlots[12].label, "Preboss")
    lu.assertEquals(instance.routeSlots[12].roleKey, "Preboss")
    lu.assertEquals(instance.routeSlots[12].roomHistoryCost, 1)
    lu.assertEquals(instance.roleValues, {
        "Combat",
        "Story",
        "Fountain",
        "Midshop",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "F_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Fountain, { "F_Reprieve01" })
    lu.assertEquals(instance.optionValuesByRole.Midshop, { "F_Shop01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "F_Combat01")

    lu.assertEquals(#storage, 2)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 12)
    lu.assertEquals(storage[1].defaultRows, 12)
    lu.assertEquals(storage[1].maxRows, 12)
    lu.assertEquals(storage[1].row[1].key, "RoleKey")
    lu.assertEquals(storage[1].row[1].default, "")
    lu.assertEquals(storage[1].row[2].key, "OptionKey")
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(storage[1].row[4].key, "SiblingStructureKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 12)
    lu.assertEquals(storage[2].defaultRows, 12)
    lu.assertEquals(storage[2].maxRows, 12)
    lu.assertEquals(storage[2].row[1].key, "Reward1Key")
    lu.assertEquals(storage[2].row[6].key, "Reward6Key")
    lu.assertEquals(storage[2].row[7].key, "Reward1LootKey")
    lu.assertEquals(storage[2].row[12].key, "Reward6LootKey")
    lu.assertEquals(storage[2].row[13].key, "SiblingRewardClassKey")

    instance = template.prepare({
        name = "RouteG",
        biome = catalog.lookup.G,
    })
    storage = template.storage(instance)
    lu.assertEquals(storage[1].row[4].key, "SiblingStructureKey")
    lu.assertEquals(storage[1].row[5].key, "SiblingStructure2Key")
    lu.assertEquals(storage[2].row[13].key, "SiblingRewardClassKey")
    lu.assertEquals(storage[2].row[14].key, "Sibling2RewardClassKey")

    instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    storage = template.storage(instance)
    lu.assertEquals(#storage[1].row, 3)
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(#storage[2].row, 12)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearSiblingRewardBranchPlumbingFollowsTopologyBranch()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local template = loadFixedLinearTemplate()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat08", "Major"),
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
        },
    })

    lu.assertTrue(data.shouldDrawSiblingRewardClass(instance, rows, 6, 1))
    lu.assertEquals(data.siblingRewardClassValues(instance), { "Major", "Minor" })
    lu.assertEquals(data.siblingRewardClassLabels(instance), {
        Major = "Major",
        Minor = "Minor",
    })
    lu.assertEquals(data.siblingRewardClassAlias(instance, 1), "SiblingRewardClassKey")
    lu.assertEquals(data.siblingRewardClassAlias(instance, 2), "Sibling2RewardClassKey")

    instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(5, "RoleKey"):write("Combat")
    fields.Rooms:get(5, "OptionKey"):write("F_Combat08")
    fields.Rooms:get(6, "RoleKey"):write("Combat")
    fields.Rooms:get(6, "OptionKey"):write("F_Combat06")
    fields.Rooms:get(6, "SiblingStructureKey"):write("Combat")
    local siblingRewardField = fields.Rewards:get(6, "SiblingRewardClassKey")
    local control = template.createUi(fields, instance)
    local draw = noOpDraw()

    draw.widgets.dropdown = function(field, opts)
        if field == siblingRewardField then
            lu.assertTrue(hasValue(opts.values or {}, "Major"))
            lu.assertTrue(hasValue(opts.values or {}, "Minor"))
            field:write("Major")
            return true
        end
        return false
    end
    template.views.rewards(draw, control, instance)

    lu.assertEquals(fields.Rewards:read(6, "SiblingRewardClassKey"), "Major")

    control = template.createRuntime(routeFields({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat08", "Major"),
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
            Reward1Key = "Major",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[6].roomTopology.sibling, {
        structure = "Combat",
        rewardStore = "RunProgress",
        rewardClass = "Major",
        rewardBranch = "majorMinor",
        offerCount = 1,
    })
end

function TestRunPlannerFixedLinearRoute.testFixedLinearSiblingTopologyExportsSelectedAndSiblingDoors()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local template = loadFixedLinearTemplate()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat08", "Major"),
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            SiblingStructureKey = "F_Story01",
            Reward1Key = "Major",
        },
    })

    lu.assertTrue(data.shouldDrawSiblingStructure(instance, rows, 6))
    lu.assertEquals(data.siblingStructureValues(instance), {
        "",
        "Combat",
        "F_Story01",
        "F_Shop01",
        "F_Reprieve01",
        "F_MiniBoss01",
        "F_MiniBoss02",
        "F_MiniBoss03",
    })
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 6).F_Story01)

    instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat08", "Major"),
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            SiblingStructureKey = "F_Story01",
            Reward1Key = "Major",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[6].roomTopology, {
        kind = "fixedLinearSiblingChoice",
        selected = {
            structure = "Combat",
            roomKey = "F_Combat06",
            rewardStore = "RunProgress",
            rewardClass = "Major",
            offerCount = 1,
            rewardAddresses = { "row" },
        },
        sibling = {
            structure = "Story",
            roomKey = "F_Story01",
            offerCount = 0,
        },
        siblings = {
            {
                structure = "Story",
                roomKey = "F_Story01",
                offerCount = 0,
            },
        },
    })
end

function TestRunPlannerFixedLinearRoute.testFixedLinearTopologyRejectsPreviouslyGeneratedSiblingRoom()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local template = loadFixedLinearTemplate()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat08", "Major"),
        fCombatRow("F_Combat06", "Major", "F_Story01"),
        fCombatRow("F_Combat07", "Major", "F_Story01"),
    })

    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 7).F_Story01, valueStates.HIDDEN)

    instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat08", "Major"),
        fCombatRow("F_Combat06", "Major", "F_Story01"),
        fCombatRow("F_Combat07", "Major", "F_Story01"),
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 7)
    lu.assertEquals(snapshot.invalidRows[1].code, "fixed_sibling_room_generated")
    lu.assertEquals(snapshot.rows[7].invalidCode, "fixed_sibling_room_generated")
end

function TestRunPlannerFixedLinearRoute.testOceanusThreeExitRoomsExportTwoSiblingDoors()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local template = loadFixedLinearTemplate()
    local instance = data.prepare({
        name = "RouteG",
        biome = catalog.lookup.G,
    })
    local rows = fakeRows({
        {},
        { RoleKey = "Combat", OptionKey = "G_Combat01", Reward1Key = "Major" },
        { RoleKey = "Combat", OptionKey = "G_Combat04", Reward1Key = "Major" },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat02",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat03",
            SiblingStructureKey = "G_Story01",
            SiblingStructure2Key = "G_Shop01",
            Reward1Key = "Major",
        },
    })

    lu.assertEquals(data.activeSiblingStructureCount(instance, rows, 4), 1)
    lu.assertEquals(data.activeSiblingStructureCount(instance, rows, 5), 2)
    lu.assertTrue(data.shouldDrawSiblingStructure(instance, rows, 5, 1))
    lu.assertTrue(data.shouldDrawSiblingStructure(instance, rows, 5, 2))
    lu.assertFalse(data.shouldDrawSiblingStructure(instance, rows, 5, 3))
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 5, 1).G_Story01)
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, rows, 5, 2).G_Shop01)
    lu.assertEquals(data.siblingStructureValueStatesForRow(instance, rows, 5, 2).G_Story01, valueStates.HIDDEN)

    local mismatchRows = fakeRows({
        {},
        {},
        {},
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat02",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
            Reward1Key = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat03",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
            Sibling2RewardClassKey = "Minor",
            Reward1Key = "Major",
        },
    })
    lu.assertNil(data.siblingStructureValueStatesForRow(instance, mismatchRows, 5, 2).Combat)

    instance = template.prepare({
        name = "RouteG",
        biome = catalog.lookup.G,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RoleKey = "Combat", OptionKey = "G_Combat01", Reward1Key = "Major" },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat04",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat02",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat03",
            SiblingStructureKey = "G_Story01",
            SiblingStructure2Key = "G_Shop01",
            Reward1Key = "Major",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[5].roomTopology.siblings, {
        {
            structure = "Story",
            roomKey = "G_Story01",
            offerCount = 0,
        },
        {
            structure = "Midshop",
            roomKey = "G_Shop01",
            offerCount = 0,
        },
    })
end

function TestRunPlannerFixedLinearRoute.testFixedLinearTopologyInvalidatesMissingSiblingStructure()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteG",
        biome = catalog.lookup.G,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RoleKey = "Combat", OptionKey = "G_Combat01", Reward1Key = "Major" },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat04",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat02",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat03",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "fixed_sibling_structure_required")
    lu.assertEquals(snapshot.rows[5].invalidCode, "fixed_sibling_structure_required")
end

function TestRunPlannerFixedLinearRoute.testFixedLinearTopologyExportsMismatchedSiblingRewardBranches()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteG",
        biome = catalog.lookup.G,
    })
    local control = template.createRuntime(routeFields({
        {},
        { RoleKey = "Combat", OptionKey = "G_Combat01", Reward1Key = "Major" },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat04",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
            Reward1Key = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat02",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
            Reward1Key = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "G_Combat03",
            SiblingStructureKey = "Combat",
            SiblingStructure2Key = "Combat",
            SiblingRewardClassKey = "Major",
            Sibling2RewardClassKey = "Minor",
            Reward1Key = "Major",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[5].roomTopology.siblings, {
        {
            structure = "Combat",
            rewardStore = "RunProgress",
            rewardClass = "Major",
            rewardBranch = "majorMinor",
            offerCount = 1,
        },
        {
            structure = "Combat",
            rewardStore = "MetaProgress",
            rewardClass = "Minor",
            rewardBranch = "majorMinor",
            offerCount = 1,
        },
    })
end

function TestRunPlannerFixedLinearRoute.testFixedLinearTopologyEnforcesForcedDoorPressure()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat09", "Major"),
        fCombatRow("F_Combat04", "Major"),
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            SiblingStructureKey = "F_Shop01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            SiblingStructureKey = "Combat",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat13",
            Reward1Key = "Major",
            SiblingStructureKey = "Combat",
        },
    }), instance)
    attachSingleBiomeRouteContext(control, "Underworld", "F")
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 8)
    lu.assertEquals(snapshot.invalidRows[1].code, "fixed_forced_topology_group_unresolved")
    lu.assertEquals(snapshot.rows[8].invalidCode, "fixed_forced_topology_group_unresolved")

    instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    control = template.createRuntime(routeFields({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat09", "Major"),
        fCombatRow("F_Combat04", "Major"),
        {
            RoleKey = "Miniboss",
            OptionKey = "F_MiniBoss01",
            SiblingStructureKey = "F_Shop01",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            SiblingStructureKey = "F_Shop01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat13",
            Reward1Key = "Major",
            SiblingStructureKey = "Combat",
        },
    }), instance)
    attachSingleBiomeRouteContext(control, "Underworld", "F")
    snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)

    instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    control = template.createRuntime(routeFields({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat09", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat06", "Major", "F_Shop01"),
        fCombatRow("F_Combat07", "Major", "Combat"),
        {
            RoleKey = "Miniboss",
            OptionKey = "F_MiniBoss01",
            SiblingStructureKey = "Combat",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
    }), instance)
    attachSingleBiomeRouteContext(control, "Underworld", "F")
    snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 8)
    lu.assertEquals(snapshot.invalidRows[1].code, "fixed_forced_topology_group_unresolved")
    lu.assertEquals(snapshot.rows[8].invalidCode, "fixed_forced_topology_group_unresolved")

    instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    control = template.createRuntime(routeFields({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat09", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat06", "Major", "F_Shop01"),
        fCombatRow("F_Combat07", "Major", "Combat"),
        {
            RoleKey = "Miniboss",
            OptionKey = "F_MiniBoss01",
            SiblingStructureKey = "F_MiniBoss02",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
        },
    }), instance)
    attachSingleBiomeRouteContext(control, "Underworld", "F")
    snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearRewardRatioSummaryCountsMajorMinorChoices()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = {
        {},
        { RoleKey = "Combat", Reward1Key = "Minor" },
        { RoleKey = "Combat", Reward1Key = "Major" },
        { RoleKey = "Fountain" },
    }
    local control = template.createRuntime(routeFields(rows), instance)
    local summary = control:rewardRatioSummary()

    lu.assertEquals(summary.targetMetaProgress, 0.315)
    lu.assertEquals(summary.totalCount, 3)
    lu.assertEquals(summary.minorCount, 1)
    lu.assertEquals(summary.majorCount, 1)
    lu.assertEquals(summary.unsetCount, 1)
    lu.assertEquals(
        summary.text,
        "Expected Minor/Major: 31.5% / 68.5%    Current Minor/Major: 50.0% / 50.0% (2/3 set, 1 vanilla)"
    )

    rows[2].Reward1Key = "Major"
    control:invalidateReadPass()
    summary = control:rewardRatioSummary()
    lu.assertEquals(summary.minorCount, 0)
    lu.assertEquals(summary.majorCount, 2)
    lu.assertEquals(summary.unsetCount, 1)
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
        { key = "G", name = "RouteG", rowCount = 9, introRoom = "G_Intro", prebossRow = 9 },
        { key = "P", name = "RouteP", rowCount = 10, introRoom = "P_Intro", prebossRow = 10 },
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
        qCombatRow("Q_Combat10"),
        qCombatRow("Q_Combat03"),
        qMinibossRow("Q_MiniBoss02"),
        qCombatRow("Q_Combat01"),
        qCombatRow("Q_Combat12"),
        qMinibossRow("Q_MiniBoss03"),
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

function TestRunPlannerFixedLinearRoute.testFixedLinearCombatRoomsCannotRepeatInOneBiome()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local template = loadFixedLinearTemplate()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rowData = {
        fOpeningRow(),
        { RoleKey = "Combat", OptionKey = "F_Combat06" },
        { RoleKey = "Combat", OptionKey = "F_Combat06" },
    }
    local rows = fakeRows(rowData)

    lu.assertTrue(data.validateRow(instance, rows, 2).valid)
    local validation = data.validateRow(instance, rows, 3)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "option_limit")
    lu.assertEquals(
        data.optionValueStatesForRow(instance, rows, 3, "Combat").F_Combat06,
        valueStates.INVALID
    )

    instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields(rowData), instance)
    attachSingleBiomeRouteContext(control, "Underworld", "F")
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertEquals(snapshot.rows[3].invalidCode, "option_limit")
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 3)
    lu.assertEquals(snapshot.invalidRows[1].code, "option_limit")
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

function TestRunPlannerFixedLinearRoute.testFixedLinearPrebossRowUsesFixedRoomChoice()
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
        "Preboss",
    })

    data.fillOptionValues(instance, rows, 12, "Preboss", values)
    lu.assertEquals(values, {})

    local roleKey, role = data.resolveRole(instance, rows, 12)
    lu.assertEquals(roleKey, "Preboss")
    lu.assertEquals(role.label, "Preboss")
    lu.assertTrue(data.validateRow(instance, rows, 12).valid)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearPreservesRewardsWhenRoomOptionKeepsSurface()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(2, "RoleKey"):write("Combat")
    fields.Rooms:get(2, "OptionKey"):write("F_Combat02")
    fields.Rewards:get(2, "Reward1Key"):write("Major")
    fields.Rewards:get(2, "Reward2Key"):write("MaxHealthDrop")
    local control = template.createUi(fields, instance)

    drawRoomsWithOptionChange(template, control, instance, "F_Combat03")

    lu.assertEquals(fields.Rooms:read(2, "OptionKey"), "F_Combat03")
    lu.assertEquals(fields.Rewards:read(2, "Reward1Key"), "Major")
    lu.assertEquals(fields.Rewards:read(2, "Reward2Key"), "MaxHealthDrop")
end

function TestRunPlannerFixedLinearRoute.testFixedLinearResetsRewardsWhenRoomOptionChangesSurface()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(2, "RoleKey"):write("Combat")
    fields.Rooms:get(2, "OptionKey"):write("F_Combat05")
    fields.Rewards:get(2, "Reward1Key"):write("Major")
    fields.Rewards:get(2, "Reward2Key"):write("Devotion")
    fields.Rewards:get(2, "Reward5Key"):write("ZeusUpgrade")
    fields.Rewards:get(2, "Reward6Key"):write("ApolloUpgrade")
    local control = template.createUi(fields, instance)

    drawRoomsWithOptionChange(template, control, instance, "F_Combat01")

    lu.assertEquals(fields.Rooms:read(2, "OptionKey"), "F_Combat01")
    lu.assertNil(fields.Rewards:read(2, "Reward1Key"))
    lu.assertNil(fields.Rewards:read(2, "Reward2Key"))
    lu.assertNil(fields.Rewards:read(2, "Reward5Key"))
    lu.assertNil(fields.Rewards:read(2, "Reward6Key"))
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
    lu.assertEquals(snapshot.rows[1].exitCount, 2)
    lu.assertEquals(snapshot.rows[1].rewardExitCount, 2)
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertTrue(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[3].routeOrdinal, 2)
    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertTrue(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[4].routeOrdinal, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[4].role.key, "Miniboss")
    lu.assertEquals(snapshot.rows[4].optionKey, "Q_MiniBoss02")
    lu.assertEquals(snapshot.rows[4].option.label, "Brute")
    lu.assertEquals(snapshot.rows[4].exitCount, 2)
    lu.assertEquals(snapshot.rows[4].rewardExitCount, 2)
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

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeSnapshotsPrebossRow()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
            {},
            qCombatRow("Q_Combat10"),
            qCombatRow("Q_Combat03"),
            qMinibossRow("Q_MiniBoss02"),
            qCombatRow("Q_Combat01"),
            qCombatRow("Q_Combat12"),
            qMinibossRow("Q_MiniBoss03"),
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
    lu.assertNil(snapshot.rows[8].roomKey)
    lu.assertEquals(snapshot.rows[8].roleKey, "Preboss")
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
            fOpeningRow(),
            fCombatRow("F_Combat02", "Major"),
            fCombatRow("F_Combat03", "Major"),
            fCombatRow("F_Combat04", "Major"),
            fCombatRow("F_Combat08", "Major"),
            {
                RoleKey = "Story",
                OptionKey = "",
                SiblingStructureKey = "Combat",
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
            OptionKey = "F_Combat04",
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

function TestRunPlannerFixedLinearRoute.testFixedLinearOlympusFirstRouteRowRequiresOutdoorCombatMap()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteP",
        biome = catalog.lookup.P,
    })
    local rows = fakeRows({})
    local values = {}

    lu.assertEquals(data.rowContext(instance, rows, 2).biomeDepthCache, 1)
    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, "P_Combat02"))
    lu.assertTrue(hasValue(values, "P_Combat05"))
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 2, "Combat").P_Combat02, valueStates.HIDDEN)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 2, "Combat").P_Combat05)

    lu.assertEquals(data.rowContext(instance, rows, 3).biomeDepthCache, 2)
    data.fillOptionValues(instance, rows, 3, "Combat", values)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").P_Combat02)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearMegaDraconOnlyLeadsToOutdoorRooms()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteP",
        biome = catalog.lookup.P,
    })
    local rows = fakeRows({
        {},
        { RoleKey = "Combat", OptionKey = "P_Combat05" },
        { RoleKey = "Combat", OptionKey = "P_Combat06" },
        { RoleKey = "Combat", OptionKey = "P_Combat11" },
        { RoleKey = "Miniboss", OptionKey = "P_MiniBoss02" },
        { RoleKey = "Combat", OptionKey = "P_Combat02" },
    })
    local values = {}

    lu.assertTrue(data.validateRow(instance, rows, 5).valid)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeDepthCache, 5)
    data.fillOptionValues(instance, rows, 6, "Combat", values)
    lu.assertTrue(hasValue(values, "P_Combat02"))
    lu.assertTrue(hasValue(values, "P_Combat13"))
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 6, "Combat").P_Combat02, valueStates.INVALID)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").P_Combat13)
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 6).Story, valueStates.INVALID)
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 6).Fountain, valueStates.INVALID)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Midshop)

    local validation = data.validateRow(instance, rows, 6)
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "previous_room_next_tags")
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
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 2, "Combat").Q_Combat10)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 2, "Combat").Q_Combat11)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 2, "Combat").Q_Combat01, valueStates.HIDDEN)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 2, "Combat").Q_Combat03, valueStates.HIDDEN)

    data.fillOptionValues(instance, rows, 3, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat03"))
    lu.assertTrue(hasValue(values, "Q_Combat05"))
    lu.assertTrue(hasValue(values, "Q_Combat15"))
    lu.assertTrue(hasValue(values, "Q_Combat10"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat03)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat05)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat15)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat01, valueStates.HIDDEN)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat10, valueStates.HIDDEN)

    data.fillOptionValues(instance, rows, 4, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss05"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 4, "Miniboss").Q_MiniBoss03, valueStates.HIDDEN)

    data.fillOptionValues(instance, rows, 5, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat01"))
    lu.assertTrue(hasValue(values, "Q_Combat06"))
    lu.assertTrue(hasValue(values, "Q_Combat16"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat01)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat06)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat16)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat03, valueStates.HIDDEN)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat12, valueStates.HIDDEN)

    data.fillOptionValues(instance, rows, 6, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat12"))
    lu.assertTrue(hasValue(values, "Q_Combat13"))
    lu.assertTrue(hasValue(values, "Q_Combat14"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").Q_Combat12)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").Q_Combat13)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").Q_Combat14)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 6, "Combat").Q_Combat01, valueStates.HIDDEN)

    data.fillOptionValues(instance, rows, 7, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss04"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 7, "Miniboss").Q_MiniBoss03)
    lu.assertEquals(data.optionValueStatesForRow(instance, rows, 7, "Miniboss").Q_MiniBoss02, valueStates.HIDDEN)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearValueStatesExactDepthRoles()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 2).Miniboss, valueStates.HIDDEN)

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 4).Combat, valueStates.HIDDEN)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 4).Miniboss)

    data.fillRoleValues(instance, rows, 7, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertEquals(data.roleValueStatesForRow(instance, rows, 7).Combat, valueStates.HIDDEN)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 7).Miniboss)
end

function TestRunPlannerFixedLinearRoute.testFixedLinearExactDepthUsesBiomeDepthCache()
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

function TestRunPlannerFixedLinearRoute.testFixedLinearRuntimeInvalidatesExactDepthOptions()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime(routeFields({
            {
                RoleKey = "Intro",
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
                RoleKey = "Combat",
                OptionKey = "Q_Combat01",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 4)
    lu.assertEquals(snapshot.invalidRows[1].code, "biome_depth_unavailable")
    lu.assertEquals(snapshot.rows[4].routeOrdinal, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertFalse(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].invalidCode, "biome_depth_unavailable")
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
            OptionKey = "F_Combat10",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
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
            OptionKey = "F_Combat10",
        },
    })
    local validExitRows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Combat", OptionKey = "F_Combat01" },
        { RoleKey = "Combat", OptionKey = "F_Combat02" },
        { RoleKey = "Combat", OptionKey = "F_Combat03" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
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

    rowState[5].OptionKey = "F_Combat04"
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
        biomeEncounterDepth = 1,
        biomeEncounterDepthMin = 1,
        biomeEncounterDepthMax = 1,
        biomeEncounterDepthCost = 1,
        biomeEncounterDepthCostMin = 1,
        biomeEncounterDepthCostMax = 1,
        roomHistoryCost = 1,
    })
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeDepthCache, 3)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepth, 5)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthMin, 5)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthMax, 5)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCost, 0)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCostMin, 0)
    lu.assertEquals(data.rowContext(instance, rows, 5).biomeEncounterDepthCostMax, 0)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeDepthCache, 4)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepth, 5)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepthMin, 5)
    lu.assertEquals(data.rowContext(instance, rows, 6).biomeEncounterDepthMax, 5)
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
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat05", "Major"),
    })

    local context = data.rowContext(instance, rows, 3)
    lu.assertEquals(context.biomeEncounterDepth, 3)
    lu.assertEquals(context.biomeEncounterDepthMin, 3)
    lu.assertEquals(context.biomeEncounterDepthMax, 3)
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
    lu.assertEquals(data.rowContext(instance, rows, 7).biomeEncounterDepth, 6)
    lu.assertEquals(data.rowContext(instance, rows, 7).biomeEncounterDepthCost, 0)
    lu.assertEquals(data.rowContext(instance, rows, 8).biomeEncounterDepth, 6)
end

function TestRunPlannerFixedLinearRoute.testMinibossRequiresConcreteOption()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
        fOpeningRow(),
        fCombatRow("F_Combat02", "Major"),
        fCombatRow("F_Combat03", "Major"),
        fCombatRow("F_Combat04", "Major"),
        fCombatRow("F_Combat08", "Major"),
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
            OptionKey = "P_Intro",
        },
        {
            RoleKey = "Combat",
            OptionKey = "P_Combat05",
        },
        {
            RoleKey = "Combat",
            OptionKey = "P_Combat06",
        },
        {
            RoleKey = "Combat",
            OptionKey = "P_Combat11",
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
	            fOpeningRow(),
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
	            fOpeningRow(),
	            {
	                RoleKey = "Story",
	                OptionKey = "F_Story01",
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
                RoleKey = "Combat",
                OptionKey = "F_Combat04",
            },
            {
                RoleKey = "Story",
                OptionKey = "F_Story01",
                SiblingStructureKey = "Combat",
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
