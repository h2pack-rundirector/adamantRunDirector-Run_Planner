local lu = require("luaunit")
local h = require("tests.support.control_harness")
local loadCatalog = h.loadCatalog
local loadFixedLinearTemplate = h.loadFixedLinearTemplate
local loadFixedLinearData = h.loadFixedLinearData
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw
local loadRouteDeps = h.loadRouteDeps
local valueStates = dofile("src/mods/ui/value_states.lua")

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
    return {
        OptionKey = "F_Opening01",
        Reward1Key = "SpellDrop",
    }
end

local function fCombatRow(optionKey, rewardKey, siblingKey)
    local row = {
        RoleKey = "Combat",
        OptionKey = optionKey,
        Reward1Key = rewardKey,
        SiblingStructureKey = siblingKey,
    }
    if rewardKey == "Major" then
        row.Reward2Key = "MaxHealthDrop"
    elseif rewardKey == "Minor" then
        row.Reward4Key = "GiftDrop"
    end
    return row
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
    lu.assertEquals(storage[2].row[13].key, "Reward1StateKey")
    lu.assertEquals(storage[2].row[18].key, "Reward6StateKey")
    lu.assertEquals(storage[2].row[19].key, "PrebossBranchKey")
    lu.assertEquals(storage[2].row[20].key, "SiblingRewardClassKey")

    instance = template.prepare({
        name = "RouteG",
        biome = catalog.lookup.G,
    })
    storage = template.storage(instance)
    lu.assertEquals(storage[1].row[4].key, "SiblingStructureKey")
    lu.assertEquals(storage[1].row[5].key, "SiblingStructure2Key")
    lu.assertEquals(storage[2].row[20].key, "SiblingRewardClassKey")
    lu.assertEquals(storage[2].row[21].key, "Sibling2RewardClassKey")

    instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    storage = template.storage(instance)
    lu.assertEquals(#storage[1].row, 3)
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(#storage[2].row, 19)
end


function TestRunPlannerFixedLinearRoute.testFixedLinearTopologyDefaultsControlsActiveWithoutFeedback()
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
    })

    lu.assertTrue(data.siblingTopologyStatus(instance, rows, 3).valid)
    lu.assertTrue(data.siblingStructureStatus(instance, rows, 3).valid)
    lu.assertEquals(data.activeSiblingStructureCount(instance, rows, 2), 1)
    lu.assertEquals(data.activeSiblingStructureCount(instance, rows, 3), 1)
    lu.assertTrue(data.shouldDrawSiblingStructure(instance, rows, 2, 1))
    lu.assertTrue(data.shouldDrawSiblingStructure(instance, rows, 3, 1))
    lu.assertFalse(data.shouldDrawSiblingRewardClass(instance, rows, 3, 1))
    lu.assertNil(data.roomTopology(instance, rows, 3))
end







function TestRunPlannerFixedLinearRoute.testFixedLinearTopologyControlsUseRouteFeedbackWindow()
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
    })
    instance.routeKey = "Underworld"
    instance.routeContext = {
        routeGeneration = function()
            return 7
        end,
    }
    instance.routeFeedbackGeneration = 7
    instance.routeFeedback = {
        [3] = {
            topology = {
                active = true,
                controlsActive = false,
            },
        },
    }

    lu.assertTrue(data.siblingTopologyStatus(instance, rows, 3).valid)
    lu.assertFalse(data.siblingStructureStatus(instance, rows, 3).valid)
    lu.assertFalse(data.shouldDrawSiblingStructure(instance, rows, 3, 1))
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
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 4, "Story").F_Story01)

    lu.assertEquals(instance.routeSlots[5].routeOrdinal, 4)
    lu.assertTrue(hasValue(data.optionValuesForRow(instance, rows, 5, "Story"), "F_Story01"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Story").F_Story01)

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



function TestRunPlannerFixedLinearRoute.testSingleRoomRolesDefaultToConcreteOption()
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
                RoleKey = "Story",
                OptionKey = "",
                SiblingStructureKey = "Combat",
            },
        })
    local roleKey = data.resolveRole(instance, rows, 6)
    local optionKey, option = data.resolveOption(instance, rows, 6, roleKey)

    lu.assertEquals(roleKey, "Story")
    lu.assertEquals(optionKey, "F_Story01")
    lu.assertEquals(option.label, "Arachne")
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
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 2).Story)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 2).Fountain)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 2).Midshop)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 2).Miniboss)

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
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 2, "Combat").F_Combat05)

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
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").F_Combat09)
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

    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, "P_Combat02"))
    lu.assertTrue(hasValue(values, "P_Combat05"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 2, "Combat").P_Combat02)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 2, "Combat").P_Combat05)

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

    data.fillOptionValues(instance, rows, 6, "Combat", values)
    lu.assertTrue(hasValue(values, "P_Combat02"))
    lu.assertTrue(hasValue(values, "P_Combat13"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").P_Combat02)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").P_Combat13)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Story)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Fountain)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 6).Midshop)
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
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 2, "Combat").Q_Combat01)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 2, "Combat").Q_Combat03)

    data.fillOptionValues(instance, rows, 3, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat03"))
    lu.assertTrue(hasValue(values, "Q_Combat05"))
    lu.assertTrue(hasValue(values, "Q_Combat15"))
    lu.assertTrue(hasValue(values, "Q_Combat10"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat03)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat05)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat15)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat01)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 3, "Combat").Q_Combat10)

    data.fillOptionValues(instance, rows, 4, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss05"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 4, "Miniboss").Q_MiniBoss03)

    data.fillOptionValues(instance, rows, 5, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat01"))
    lu.assertTrue(hasValue(values, "Q_Combat06"))
    lu.assertTrue(hasValue(values, "Q_Combat16"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat01)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat06)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat16)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat03)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 5, "Combat").Q_Combat12)

    data.fillOptionValues(instance, rows, 6, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat12"))
    lu.assertTrue(hasValue(values, "Q_Combat13"))
    lu.assertTrue(hasValue(values, "Q_Combat14"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").Q_Combat12)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").Q_Combat13)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").Q_Combat14)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 6, "Combat").Q_Combat01)

    data.fillOptionValues(instance, rows, 7, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss04"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 7, "Miniboss").Q_MiniBoss03)
    lu.assertNil(data.optionValueStatesForRow(instance, rows, 7, "Miniboss").Q_MiniBoss02)
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
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 2).Miniboss)

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 4).Combat)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 4).Miniboss)

    data.fillRoleValues(instance, rows, 7, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 7).Combat)
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

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 4).Miniboss)

    data.fillRoleValues(instance, rows, 5, values)
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 5).Combat)
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 5).Miniboss)
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
    lu.assertNil(data.roleValueStatesForRow(instance, rows, 7).Story)
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

    local validation = loadRouteDeps().controlForm.validateRoomChoice({
        data = data,
        instance = instance,
        rows = rows,
        rowIndex = 6,
    })
    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "option_required")
    lu.assertEquals(validation.controlTargets, {
        {
            tabKey = "rooms",
            controlAlias = "OptionKey",
            state = valueStates.INVALID,
            mode = "selected",
        },
    })
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
        blockingHorizon = function()
            return nil
        end,
        historyValueStates = function(
            _,
            routeKey,
            biomeKey,
            rowIndex,
            controlAlias,
            rewardAddress
        )
            seen.routeKey = routeKey
            seen.biomeKey = biomeKey
            seen.rowIndex = rowIndex
            seen.rewardAddress = rewardAddress
            seen.controlAlias = controlAlias
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
end

function TestRunPlannerFixedLinearRoute.testFixedLinearSiblingRewardDropdownUsesRouteValueStateContext()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fields = routeUiFields(template.storage(instance))
    local function writeRow(rowIndex, room, reward)
        for alias, value in pairs(room or {}) do
            fields.Rooms:get(rowIndex, alias):write(value)
        end
        for alias, value in pairs(reward or {}) do
            fields.Rewards:get(rowIndex, alias):write(value)
        end
    end
    writeRow(1, fOpeningRow())
    writeRow(2, { RoleKey = "Combat", OptionKey = "F_Combat02" }, { Reward1Key = "Major" })
    writeRow(3, { RoleKey = "Combat", OptionKey = "F_Combat03" }, { Reward1Key = "Major" })
    writeRow(4, { RoleKey = "Combat", OptionKey = "F_Combat04" }, { Reward1Key = "Major" })
    writeRow(5, { RoleKey = "Combat", OptionKey = "F_Combat08" }, { Reward1Key = "Major" })
    writeRow(
        6,
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            SiblingStructureKey = "Combat",
        },
        {
            Reward1Key = "Major",
        }
    )
    local control = template.createUi(fields, instance)
    local siblingRewardField = fields.Rewards:get(6, "SiblingRewardClassKey")
    local seen = {}
    control:setRouteContext({
        blockingHorizon = function()
            return nil
        end,
        historyValueStates = function(
            _,
            routeKey,
            biomeKey,
            rowIndex,
            controlAlias,
            rewardAddress
        )
        if rewardAddress == "sibling:1" then
            seen.routeKey = routeKey
            seen.biomeKey = biomeKey
            seen.rowIndex = rowIndex
            seen.rewardAddress = rewardAddress
            seen.controlAlias = controlAlias
        end
        return {
            Minor = 2,
            }
        end,
    }, "Underworld")
    local draw = noOpDraw()
    local sawSibling = false
    draw.widgets.dropdown = function(field, opts)
        if field == siblingRewardField then
            sawSibling = true
            lu.assertTrue(hasValue(opts.values or {}, "Minor"))
            lu.assertEquals(opts.valueColors.Minor, { 1.0, 0.22, 0.16, 1.0 })
        end
        return false
    end

    template.views.rewards(draw, control, instance)

    lu.assertTrue(sawSibling)
    lu.assertEquals(seen.routeKey, "Underworld")
    lu.assertEquals(seen.biomeKey, "F")
    lu.assertEquals(seen.rowIndex, 6)
    lu.assertEquals(seen.rewardAddress, "sibling:1")
    lu.assertEquals(seen.controlAlias, "SiblingRewardClassKey")
end
