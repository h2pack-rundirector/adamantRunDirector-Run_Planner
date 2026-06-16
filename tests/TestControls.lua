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

function TestRunPlannerControls.testFixedLinearRuntimeBuildsNormalizedSnapshot()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteQ",
        biome = catalog.lookup.Q,
    })
    local control = template.createRuntime({
        Rows = fakeRows({
            {
                RoleKey = "Miniboss",
                OptionKey = "Q_MiniBoss02",
                VariantKey = "Manual",
                Reward1Key = "ZeusUpgrade",
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
    lu.assertEquals(snapshot.rows[1].coordinate, 2)
    lu.assertEquals(snapshot.rows[1].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[1].role.key, "Miniboss")
    lu.assertEquals(snapshot.rows[1].optionKey, "Q_MiniBoss02")
    lu.assertEquals(snapshot.rows[1].option.label, "Brute")
    lu.assertEquals(snapshot.rows[1].variantKey, "Manual")
    lu.assertEquals(snapshot.rows[1].rewards[1], "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[2].roleKey, "Vanilla")
    lu.assertEquals(snapshot.rows[2].optionKey, "")
    lu.assertNil(snapshot.rows[2].option)
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
                RoleKey = "Story",
                OptionKey = "",
            },
        }),
    }, instance)
    local row = control:rowSnapshot(1)

    lu.assertEquals(row.roleKey, "Story")
    lu.assertEquals(row.optionKey, "F_Story01")
    lu.assertEquals(row.option.label, "Arachne")
end
