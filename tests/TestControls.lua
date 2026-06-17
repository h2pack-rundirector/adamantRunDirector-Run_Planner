local lu = require("luaunit")

-- luacheck: globals TestRunPlannerControls
TestRunPlannerControls = {}

local function testImport(path, _, deps)
    local chunk = assert(loadfile("src/" .. path))
    return chunk(deps)
end

local function withTestImport(callback)
    local previousImport = _G.import
    _G.import = testImport
    local ok, err = pcall(callback)
    _G.import = previousImport
    if not ok then
        error(err, 0)
    end
end

local function loadCatalog()
    local data = dofile("src/mods/data.lua")
    return data.loadCatalog(testImport), data
end

local function loadFixedLinearTemplate()
    local template
    withTestImport(function()
        template = testImport("mods/controls/FixedLinearRoute/FixedLinearRoute.lua")
    end)
    return template
end

local function loadFixedLinearData()
    return testImport("mods/controls/FixedLinearRoute/data.lua")
end

local function hasValue(values, expected)
    for _, value in ipairs(values) do
        if value == expected then
            return true
        end
    end
    return false
end

local function fakeRows(rows)
    return {
        count = function()
            return #rows
        end,
        read = function(_, rowIndex, alias)
            return rows[rowIndex] and rows[rowIndex][alias] or nil
        end,
    }
end

function TestRunPlannerControls.testCatalogBuildsControlsForFixedLinearAdapters()
    local catalog, data = loadCatalog()
    local controls = data.buildControls(catalog, testImport)

    lu.assertEquals(data.routeControlNames(catalog, testImport), {
        "RouteF",
        "RouteG",
        "RouteP",
        "RouteQ",
    })
    lu.assertEquals(data.routeControlTabs(catalog, testImport).Underworld, {
        { key = "F", label = "Erebus", controlName = "RouteF" },
        { key = "G", label = "Oceanus", controlName = "RouteG" },
    })
    lu.assertEquals(data.routeControlTabs(catalog, testImport).Surface, {
        { key = "P", label = "Olympus", controlName = "RouteP" },
        { key = "Q", label = "Summit", controlName = "RouteQ" },
    })
    lu.assertEquals(controls.RouteF.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteG.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteP.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteQ.template, "FixedLinearRoute")
    lu.assertNil(controls.RouteH)
    lu.assertNil(controls.RouteI)
    lu.assertNil(controls.RouteN)
    lu.assertNil(controls.RouteO)
end

function TestRunPlannerControls.testFixedLinearStorageMatchesRouteRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 9)
    lu.assertEquals(instance.routeSlots[1].coordinate, 1)
    lu.assertEquals(instance.routeSlots[9].coordinate, 9)
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Story",
        "Fountain",
        "Midshop",
        "Trial",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "F_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Fountain, { "F_Reprieve01" })
    lu.assertEquals(instance.optionValuesByRole.Midshop, { "F_Shop01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")

    lu.assertEquals(#storage, 1)
    lu.assertEquals(storage[1].key, "Rows")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 9)
    lu.assertEquals(storage[1].defaultRows, 9)
    lu.assertEquals(storage[1].maxRows, 9)
    lu.assertEquals(storage[1].row[1].key, "RoleKey")
    lu.assertEquals(storage[1].row[2].key, "OptionKey")
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(storage[1].row[9].key, "Reward6Key")
end

function TestRunPlannerControls.testFixedLinearRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime({
        Rows = fakeRows({
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
        }),
    }, instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "Q")
    lu.assertEquals(snapshot.adapter, "scriptedFixedLinear")
    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 4)
    lu.assertEquals(snapshot.invalidRows[1].code, "unknown_role")
    lu.assertEquals(snapshot.rows[1].coordinate, 1)
    lu.assertEquals(snapshot.rows[1].roleKey, "Vanilla")
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(snapshot.rows[2].coordinate, 2)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertTrue(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[3].coordinate, 3)
    lu.assertEquals(snapshot.rows[3].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[3].role.key, "Miniboss")
    lu.assertEquals(snapshot.rows[3].optionKey, "Q_MiniBoss02")
    lu.assertEquals(snapshot.rows[3].option.label, "Brute")
    lu.assertTrue(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[3].variantKey, "Manual")
    lu.assertEquals(snapshot.rows[3].rewards[1], "Boon")
    lu.assertEquals(snapshot.rows[3].rewards[2], "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[3].rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[3].rewardPicks, {
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

    lu.assertEquals(snapshot.rows[4].roleKey, "Missing")
    lu.assertEquals(snapshot.rows[4].invalidCode, "unknown_role")
    lu.assertFalse(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].optionKey, "Q_MiniBoss03")
    lu.assertNil(snapshot.rows[4].option)
end

function TestRunPlannerControls.testSingleRoomRolesDefaultToConcreteOption()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime({
        Rows = fakeRows({
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
        }),
    }, instance)
    local row = control:rowSnapshot(4)

    lu.assertEquals(row.roleKey, "Story")
    lu.assertEquals(row.optionKey, "F_Story01")
    lu.assertEquals(row.option.label, "Arachne")
end

function TestRunPlannerControls.testCombatRewardSurfaceHidesTrialReward()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime({
        Rows = fakeRows({
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat01",
            },
        }),
    }, instance)
    local surface = control:rewardSurface(1)

    lu.assertEquals(surface.kind, "roomStore")
    lu.assertFalse(hasValue(surface.controls[1].values, "Devotion"))
    lu.assertTrue(hasValue(surface.controls[1].values, "RoomMoneyDrop"))
end

function TestRunPlannerControls.testFixedLinearAvailabilityFiltersRolesByRouteRow()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 1, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertFalse(hasValue(values, "Story"))
    lu.assertFalse(hasValue(values, "Fountain"))
    lu.assertFalse(hasValue(values, "Midshop"))
    lu.assertFalse(hasValue(values, "Miniboss"))

    rows = fakeRows({
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    })
    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Story"))
    lu.assertTrue(hasValue(values, "Fountain"))
    lu.assertTrue(hasValue(values, "Midshop"))
    lu.assertTrue(hasValue(values, "Miniboss"))
end

function TestRunPlannerControls.testFixedLinearAvailabilityFiltersOptionsByRouteRow()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillOptionValues(instance, rows, 1, "Combat", values)
    lu.assertTrue(hasValue(values, ""))
    lu.assertTrue(hasValue(values, "F_Combat01"))
    lu.assertFalse(hasValue(values, "F_Combat05"))

    data.fillOptionValues(instance, rows, 5, "Combat", values)
    lu.assertTrue(hasValue(values, "F_Combat05"))
    lu.assertFalse(hasValue(values, "F_Combat09"))
end

function TestRunPlannerControls.testFixedLinearAvailabilityFiltersScriptedExactDepthOptions()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillOptionValues(instance, rows, 1, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat10"))
    lu.assertTrue(hasValue(values, "Q_Combat11"))
    lu.assertFalse(hasValue(values, "Q_Combat03"))

    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat03"))
    lu.assertTrue(hasValue(values, "Q_Combat05"))
    lu.assertTrue(hasValue(values, "Q_Combat15"))
    lu.assertFalse(hasValue(values, "Q_Combat10"))

    data.fillOptionValues(instance, rows, 3, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss05"))
    lu.assertFalse(hasValue(values, "Q_MiniBoss03"))

    data.fillOptionValues(instance, rows, 6, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss03"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss04"))
    lu.assertFalse(hasValue(values, "Q_MiniBoss02"))
end

function TestRunPlannerControls.testFixedLinearAvailabilityFiltersForcedDepthRoles()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 1, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertFalse(hasValue(values, "Miniboss"))

    data.fillRoleValues(instance, rows, 3, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertFalse(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))

    data.fillRoleValues(instance, rows, 6, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertFalse(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesForcedDepthRoles()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime({
        Rows = fakeRows({
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
        }),
    }, instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 3)
    lu.assertEquals(snapshot.invalidRows[1].code, "forced_depth_role")
    lu.assertEquals(snapshot.rows[3].coordinate, 3)
    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertFalse(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[3].invalidCode, "forced_depth_role")
end

function TestRunPlannerControls.testFixedLinearAvailabilityConsumesPriorOneShotRoles()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({
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
            RoleKey = "Story",
            OptionKey = "F_Story01",
        },
    })
    local values = {}

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Story"))

    data.fillRoleValues(instance, rows, 5, values)
    lu.assertFalse(hasValue(values, "Story"))
end

function TestRunPlannerControls.testFixedLinearAvailabilityChecksPreviousRoomExitRequirement()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local values = {}

    data.fillRoleValues(instance, fakeRows({
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
    }), 4, values)
    lu.assertFalse(hasValue(values, "Midshop"))

    data.fillRoleValues(instance, fakeRows({
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    }), 4, values)
    lu.assertTrue(hasValue(values, "Midshop"))
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesPreviousRoomExitRequirement()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime({
        Rows = fakeRows({
            { RoleKey = "Vanilla" },
            { RoleKey = "Vanilla" },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat01",
            },
            {
                RoleKey = "Midshop",
                OptionKey = "F_Shop01",
            },
        }),
    }, instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 4)
    lu.assertEquals(snapshot.invalidRows[1].code, "previous_room_exit_count")
    lu.assertTrue(snapshot.rows[3].valid)
    lu.assertFalse(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].invalidCode, "previous_room_exit_count")
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesOutOfRangeAndDuplicateRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime({
        Rows = fakeRows({
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
                RoleKey = "Story",
                OptionKey = "F_Story01",
            },
            {
                RoleKey = "Story",
                OptionKey = "F_Story01",
            },
        }),
    }, instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 2)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 1)
    lu.assertEquals(snapshot.invalidRows[1].code, "option_unavailable")
    lu.assertEquals(snapshot.invalidRows[2].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[2].code, "role_limit")
    lu.assertEquals(snapshot.rows[1].roleKey, "Story")
    lu.assertEquals(snapshot.rows[1].optionKey, "F_Story01")
    lu.assertFalse(snapshot.rows[1].valid)
    lu.assertEquals(snapshot.rows[4].roleKey, "Story")
    lu.assertEquals(snapshot.rows[4].optionKey, "F_Story01")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[5].roleKey, "Story")
    lu.assertEquals(snapshot.rows[5].optionKey, "F_Story01")
    lu.assertFalse(snapshot.rows[5].valid)
    lu.assertEquals(snapshot.rows[5].invalidCode, "role_limit")
end
