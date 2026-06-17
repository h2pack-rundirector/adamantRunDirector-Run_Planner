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

local function loadRouteDeps()
    local common = testImport("mods/route/common.lua")
    local route = {
        common = common,
        availability = testImport("mods/route/availability.lua"),
        readCache = testImport("mods/route/read_cache.lua"),
        requirements = testImport("mods/route/requirements.lua", nil, {
            common = common,
        }),
    }
    route.rowEngine = testImport("mods/route/row_engine.lua", nil, route)
    return route
end

local function loadFixedLinearTemplate()
    local template
    withTestImport(function()
        template = testImport("mods/controls/templates.lua").FixedLinearRoute
    end)
    return template
end

local function loadHubPylonTemplate()
    local template
    withTestImport(function()
        template = testImport("mods/controls/templates.lua").HubPylonRoute
    end)
    return template
end

local function loadMultiEncounterTemplate()
    local template
    withTestImport(function()
        template = testImport("mods/controls/templates.lua").MultiEncounterFixedRoute
    end)
    return template
end

local function loadFieldsCageTemplate()
    local template
    withTestImport(function()
        template = testImport("mods/controls/templates.lua").FieldsCageRoute
    end)
    return template
end

local function loadFixedLinearData()
    return testImport("mods/controls/FixedLinearRoute/data.lua", nil, loadRouteDeps())
end

local function loadHubPylonData()
    return testImport("mods/controls/HubPylonRoute/data.lua", nil, loadRouteDeps())
end

local function loadMultiEncounterData()
    return testImport("mods/controls/MultiEncounterFixedRoute/data.lua", nil, loadRouteDeps())
end

local function loadFieldsCageData()
    return testImport("mods/controls/FieldsCageRoute/data.lua", nil, loadRouteDeps())
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

local function routeFields(rows, sideRows, sideRewardRows, encounterRewardRows, cageRewardRows)
    return {
        Rooms = fakeRows(rows or {}),
        Rewards = fakeRows(rows or {}),
        SideRooms = fakeRows(sideRows or {}),
        SideRewards = fakeRows(sideRewardRows or {}),
        EncounterRewards = fakeRows(encounterRewardRows or {}),
        CageRewards = fakeRows(cageRewardRows or {}),
    }
end

function TestRunPlannerControls.testCatalogBuildsControlsForSupportedAdapters()
    local catalog, data = loadCatalog()
    local controls = data.buildControls(catalog, testImport)

    lu.assertEquals(data.routeControlNames(catalog, testImport), {
        "RouteF",
        "RouteG",
        "RouteH",
        "RouteN",
        "RouteO",
        "RouteP",
        "RouteQ",
    })
    lu.assertEquals(data.routeControlTabs(catalog, testImport).Underworld, {
        { key = "F", label = "Erebus", controlName = "RouteF" },
        { key = "G", label = "Oceanus", controlName = "RouteG" },
        { key = "H", label = "Fields", controlName = "RouteH" },
    })
    lu.assertEquals(data.routeControlTabs(catalog, testImport).Surface, {
        { key = "N", label = "Ephyra", controlName = "RouteN" },
        { key = "O", label = "Thessaly", controlName = "RouteO" },
        { key = "P", label = "Olympus", controlName = "RouteP" },
        { key = "Q", label = "Summit", controlName = "RouteQ" },
    })
    lu.assertEquals(controls.RouteF.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteG.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteH.template, "FieldsCageRoute")
    lu.assertEquals(controls.RouteN.template, "HubPylonRoute")
    lu.assertEquals(controls.RouteO.template, "MultiEncounterFixedRoute")
    lu.assertEquals(controls.RouteP.template, "FixedLinearRoute")
    lu.assertEquals(controls.RouteQ.template, "FixedLinearRoute")
    lu.assertNil(controls.RouteI)
end

function TestRunPlannerControls.testFixedLinearStorageMatchesRouteRows()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 12)
    lu.assertEquals(instance.routeSlots[1].coordinate, 0)
    lu.assertEquals(instance.routeSlots[1].kind, "opening")
    lu.assertEquals(instance.routeSlots[1].label, "Opening")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Opening")
    lu.assertEquals(instance.routeSlots[2].coordinate, 1)
    lu.assertEquals(instance.routeSlots[10].coordinate, 9)
    lu.assertEquals(instance.routeSlots[11].coordinate, 10)
    lu.assertEquals(instance.routeSlots[11].kind, "preboss")
    lu.assertEquals(instance.routeSlots[11].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[11].branchKey, "Shop")
    lu.assertEquals(instance.routeSlots[11].branchValues, {
        "Shop",
    })
    lu.assertEquals(instance.routeSlots[12].coordinate, 10)
    lu.assertEquals(instance.routeSlots[12].kind, "preboss")
    lu.assertEquals(instance.routeSlots[12].label, "Preboss Room")
    lu.assertEquals(instance.routeSlots[12].branchKey, "MajorReward")
    lu.assertEquals(instance.routeSlots[12].branchValues, {
        "MajorReward",
    })
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
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].type, "table")
    lu.assertEquals(storage[2].minRows, 12)
    lu.assertEquals(storage[2].defaultRows, 12)
    lu.assertEquals(storage[2].maxRows, 12)
    lu.assertEquals(storage[2].row[1].key, "Reward1Key")
    lu.assertEquals(storage[2].row[6].key, "Reward6Key")
    lu.assertEquals(storage[2].row[7].key, "Reward1LootKey")
    lu.assertEquals(storage[2].row[12].key, "Reward6LootKey")
end

function TestRunPlannerControls.testFixedLinearEntryMetadataRendersIntroRows()
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
        lu.assertEquals(instance.routeSlots[1].coordinate, 0)
        lu.assertEquals(instance.routeSlots[1].kind, "intro")
        lu.assertEquals(instance.routeSlots[1].label, "Intro")
        lu.assertEquals(instance.routeSlots[1].roomKey, case.introRoom)
        lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
        lu.assertEquals(instance.routeSlots[case.prebossRow].kind, "preboss")
    end
end

function TestRunPlannerControls.testHubPylonStorageMatchesEphyraRouteRows()
    local catalog = loadCatalog()
    local routeData = loadHubPylonData()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 10)
    lu.assertEquals(instance.routeSlots[1].kind, "fixedBeforeHub")
    lu.assertEquals(instance.routeSlots[1].label, "Opening")
    lu.assertEquals(instance.routeSlots[1].roomKey, "N_Opening01")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Opening")
    lu.assertEquals(instance.routeSlots[2].label, "Pre-Hub")
    lu.assertEquals(instance.routeSlots[3].label, "Hub")
    lu.assertEquals(instance.routeSlots[3].roomKey, "N_Hub")
    lu.assertEquals(instance.routeSlots[4].kind, "pylonPick")
    lu.assertEquals(instance.routeSlots[4].coordinate, 1)
    lu.assertEquals(instance.routeSlots[4].label, "Pylon 1")
    lu.assertEquals(instance.routeSlots[9].coordinate, 6)
    lu.assertEquals(instance.routeSlots[9].label, "Pylon 6")
    lu.assertEquals(instance.routeSlots[10].kind, "fixedAfterHub")
    lu.assertEquals(instance.routeSlots[10].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[10].roomKey, "N_PreBoss01")
    lu.assertEquals(instance.routeSlots[10].roleKey, "Preboss")
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Story",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "N_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")
    lu.assertEquals(instance.optionValuesByRole.Miniboss, {
        "",
        "N_MiniBoss01",
        "N_MiniBoss02",
    })
    lu.assertEquals(instance.maxSideDoorCount, 3)
    lu.assertEquals(instance.sideRoomModeValues, {
        "",
        "Disabled",
        "Enabled",
    })
    lu.assertEquals(instance.sideRoomModeLabels, {
        [""] = "Vanilla",
        Disabled = "Disabled",
        Enabled = "Enabled",
    })

    lu.assertEquals(instance.sideRoomRowCount, 18)

    lu.assertEquals(#storage, 4)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 10)
    lu.assertEquals(storage[1].defaultRows, 10)
    lu.assertEquals(storage[1].maxRows, 10)
    lu.assertEquals(storage[1].row[1].key, "RoleKey")
    lu.assertEquals(storage[1].row[2].key, "OptionKey")
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].minRows, 10)
    lu.assertEquals(storage[2].row[1].key, "Reward1Key")
    lu.assertEquals(storage[2].row[12].key, "Reward6LootKey")
    lu.assertEquals(storage[3].key, "SideRooms")
    lu.assertEquals(storage[3].minRows, 18)
    lu.assertEquals(storage[3].defaultRows, 18)
    lu.assertEquals(storage[3].maxRows, 18)
    lu.assertEquals(storage[3].row[1].key, "ModeKey")
    lu.assertEquals(storage[3].row[1].default, "")
    lu.assertEquals(storage[4].key, "SideRewards")
    lu.assertEquals(storage[4].minRows, 18)
    lu.assertEquals(storage[4].row[1].key, "Reward1Key")
    lu.assertEquals(storage[4].row[12].key, "Reward6LootKey")
    lu.assertEquals(routeData.sideRoomRowIndex(instance, 4, 1), 1)
    lu.assertEquals(routeData.sideRoomRowIndex(instance, 4, 3), 3)
    lu.assertEquals(routeData.sideRoomRowIndex(instance, 9, 1), 16)
    lu.assertNil(routeData.sideRoomRowIndex(instance, 1, 1))
end

function TestRunPlannerControls.testMultiEncounterStorageMatchesThessalyRouteRows()
    local catalog = loadCatalog()
    local routeData = loadMultiEncounterData()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 8)
    lu.assertEquals(instance.routeSlots[1].coordinate, 0)
    lu.assertEquals(instance.routeSlots[1].kind, "intro")
    lu.assertEquals(instance.routeSlots[1].label, "Intro")
    lu.assertEquals(instance.routeSlots[1].roomKey, "O_Intro")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
    lu.assertEquals(instance.routeSlots[2].coordinate, 1)
    lu.assertEquals(instance.routeSlots[2].kind, "route")
    lu.assertEquals(instance.routeSlots[2].label, "Depth 1")
    lu.assertEquals(instance.routeSlots[7].coordinate, 6)
    lu.assertEquals(instance.routeSlots[8].coordinate, 7)
    lu.assertEquals(instance.routeSlots[8].kind, "preboss")
    lu.assertEquals(instance.routeSlots[8].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[8].branchKey, "Shop")
    lu.assertEquals(instance.roleValues, {
        "Vanilla",
        "Combat",
        "Story",
        "Fountain",
        "Midshop",
        "Trial",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "O_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "")

    lu.assertEquals(#storage, 3)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 8)
    lu.assertEquals(storage[1].defaultRows, 8)
    lu.assertEquals(storage[1].maxRows, 8)
    lu.assertEquals(storage[1].row[1].key, "RoleKey")
    lu.assertEquals(storage[1].row[2].key, "OptionKey")
    lu.assertEquals(storage[1].row[3].key, "VariantKey")
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].minRows, 8)
    lu.assertEquals(storage[2].row[1].key, "Reward1Key")
    lu.assertEquals(storage[2].row[12].key, "Reward6LootKey")
    lu.assertEquals(storage[3].key, "EncounterRewards")
    lu.assertEquals(storage[3].minRows, 12)
    lu.assertEquals(storage[3].defaultRows, 12)
    lu.assertEquals(storage[3].maxRows, 12)
    lu.assertEquals(storage[3].row[1].key, "Reward1Key")
    lu.assertEquals(storage[3].row[12].key, "Reward6LootKey")
    lu.assertNil(routeData.encounterRewardRowIndex(instance, 1, 1))
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 2, 1), 1)
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 2, 2), 2)
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 7, 2), 12)
    lu.assertNil(routeData.encounterRewardRowIndex(instance, 8, 1))

    lu.assertEquals(routeData.variantLabelsForRow(instance, "Combat"), {
        [""] = "Vanilla",
        TwoCombats = "2 Combats",
        ThreeCombats = "3 Combats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, 2, "Combat"), {
        "",
        "TwoCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, 3, "Combat"), {
        "",
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, 7, "Combat"), {
        "",
        "TwoCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, 3, "Story"), {})
end

function TestRunPlannerControls.testFieldsCageStorageMatchesFieldsRouteRows()
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
    lu.assertEquals(instance.routeSlots[2].kind, "fieldsPick")
    lu.assertEquals(instance.routeSlots[2].coordinate, 1)
    lu.assertEquals(instance.routeSlots[2].label, "Pick 1")
    lu.assertEquals(instance.routeSlots[5].coordinate, 4)
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
    lu.assertEquals(instance.cageRewardRowCount, 12)

    lu.assertEquals(#storage, 3)
    lu.assertEquals(storage[1].key, "Rooms")
    lu.assertEquals(storage[1].minRows, 6)
    lu.assertEquals(storage[2].key, "Rewards")
    lu.assertEquals(storage[2].minRows, 6)
    lu.assertEquals(storage[3].key, "CageRewards")
    lu.assertEquals(storage[3].minRows, 12)
    lu.assertEquals(storage[3].defaultRows, 12)
    lu.assertEquals(storage[3].maxRows, 12)
    lu.assertEquals(storage[3].row[1].key, "Reward1Key")
    lu.assertEquals(storage[3].row[12].key, "Reward6LootKey")
    lu.assertEquals(routeData.cageRewardRowIndex(instance, 2, 1), 1)
    lu.assertEquals(routeData.cageRewardRowIndex(instance, 2, 3), 3)
    lu.assertEquals(routeData.cageRewardRowIndex(instance, 5, 1), 10)
    lu.assertEquals(routeData.cageRewardRowIndex(instance, 5, 3), 12)
    lu.assertNil(routeData.cageRewardRowIndex(instance, 1, 1))
    lu.assertNil(routeData.cageRewardRowIndex(instance, 6, 1))

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

function TestRunPlannerControls.testFixedLinearOpeningRowUsesFixedRoomChoice()
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

function TestRunPlannerControls.testHubPylonFixedRowsUseImplicitRooms()
    local catalog = loadCatalog()
    local data = loadHubPylonData()
    local instance = data.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 1, values)
    lu.assertEquals(values, {
        "Opening",
    })

    data.fillOptionValues(instance, rows, 1, "Opening", values)
    lu.assertEquals(values, {})

    local roleKey, role = data.resolveRole(instance, rows, 1)
    local optionKey, option = data.resolveOption(instance, rows, 1, roleKey)
    lu.assertEquals(roleKey, "Opening")
    lu.assertEquals(role.label, "Opening")
    lu.assertEquals(role.roomKey, "N_Opening01")
    lu.assertEquals(optionKey, "")
    lu.assertNil(option)
    lu.assertTrue(data.validateRow(instance, rows, 1).valid)
end

function TestRunPlannerControls.testHubPylonRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(routeFields({
            {},
            {},
            {},
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat12",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Story",
                OptionKey = "",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "N_MiniBoss02",
                Reward1Key = "AphroditeUpgrade",
            },
            {
                RoleKey = "Story",
                OptionKey = "N_Story01",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {},
        }, {
            { ModeKey = "Enabled" },
            { ModeKey = "Disabled" },
            {},
        }, {
            { Reward1Key = "MaxHealthDrop" },
            {},
            {},
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "N")
    lu.assertEquals(snapshot.adapter, "hubPylon")
    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 7)
    lu.assertEquals(snapshot.invalidRows[1].code, "role_limit")

    lu.assertEquals(snapshot.rows[1].slotKind, "fixedBeforeHub")
    lu.assertEquals(snapshot.rows[1].slotLabel, "Opening")
    lu.assertEquals(snapshot.rows[1].roomKey, "N_Opening01")
    lu.assertEquals(snapshot.rows[1].roleKey, "Opening")
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(snapshot.rows[1].rewardKind, "roomStore")

    lu.assertEquals(snapshot.rows[4].slotKind, "pylonPick")
    lu.assertEquals(snapshot.rows[4].coordinate, 1)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[4].optionKey, "N_Combat12")
    lu.assertEquals(snapshot.rows[4].roomKey, "N_Combat12")
    lu.assertEquals(snapshot.rows[4].hubDoorId, 561389)
    lu.assertEquals(#snapshot.rows[4].sideDoors, 3)
    lu.assertEquals(#snapshot.rows[4].sideRooms, 3)
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[4].rewardPicks[1].value, "Boon")
    lu.assertEquals(snapshot.rows[4].rewardPicks[2].value, "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].roomKey, "N_Sub09")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].doorId, 558352)
    lu.assertEquals(snapshot.rows[4].sideRooms[1].modeKey, "Enabled")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].storedModeKey, "Enabled")
    lu.assertTrue(snapshot.rows[4].sideRooms[1].enabled)
    lu.assertEquals(snapshot.rows[4].sideRooms[1].rewardStore, "SubRoomRewardsHard")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].rewardPicks[1], {
        key = "rewardType",
        kind = "rewardType",
        alias = "Reward1Key",
        storageAlias = "Reward1Key",
        value = "MaxHealthDrop",
    })
    lu.assertEquals(snapshot.rows[4].sideRooms[2].roomKey, "N_Sub10")
    lu.assertEquals(snapshot.rows[4].sideRooms[2].modeKey, "Disabled")
    lu.assertEquals(snapshot.rows[4].sideRooms[2].storedModeKey, "Disabled")
    lu.assertFalse(snapshot.rows[4].sideRooms[2].enabled)
    lu.assertEquals(snapshot.rows[4].sideRooms[2].rewardStore, "SubRoomRewardsHard")
    lu.assertEquals(snapshot.rows[4].sideRooms[2].rewardKind, "none")
    lu.assertEquals(snapshot.rows[4].sideRooms[2].rewardPicks, {})
    lu.assertEquals(snapshot.rows[4].sideRooms[3].roomKey, "N_Sub07")
    lu.assertEquals(snapshot.rows[4].sideRooms[3].modeKey, "Vanilla")
    lu.assertEquals(snapshot.rows[4].sideRooms[3].storedModeKey, "")
    lu.assertFalse(snapshot.rows[4].sideRooms[3].enabled)
    lu.assertEquals(snapshot.rows[4].sideRooms[3].rewardStore, "SubRoomRewards")
    lu.assertEquals(snapshot.rows[4].sideRooms[3].rewardPicks, {})

    lu.assertEquals(snapshot.rows[5].roleKey, "Story")
    lu.assertEquals(snapshot.rows[5].optionKey, "N_Story01")
    lu.assertEquals(snapshot.rows[5].roomKey, "N_Story01")
    lu.assertEquals(snapshot.rows[5].hubDoorId, 560848)
    lu.assertTrue(snapshot.rows[5].valid)

    lu.assertEquals(snapshot.rows[6].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[6].optionKey, "N_MiniBoss02")
    lu.assertEquals(snapshot.rows[6].roomKey, "N_MiniBoss02")
    lu.assertEquals(snapshot.rows[6].rewardKind, "boonSource")
    lu.assertEquals(snapshot.rows[6].rewardPicks[1].value, "AphroditeUpgrade")
    lu.assertTrue(snapshot.rows[6].valid)

    lu.assertEquals(snapshot.rows[7].roleKey, "Story")
    lu.assertFalse(snapshot.rows[7].valid)
    lu.assertEquals(snapshot.rows[7].invalidCode, "role_limit")

    lu.assertEquals(snapshot.rows[10].slotKind, "fixedAfterHub")
    lu.assertEquals(snapshot.rows[10].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[10].roomKey, "N_PreBoss01")
    lu.assertEquals(snapshot.rows[10].roleKey, "Preboss")
    lu.assertTrue(snapshot.rows[10].valid)
    lu.assertEquals(snapshot.rows[10].rewardKind, "shop")
end

function TestRunPlannerControls.testFixedLinearPrebossRowsUseBranchChoices()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rows = fakeRows({})
    local values = {}

    data.fillRoleValues(instance, rows, 11, values)
    lu.assertEquals(values, {
        "Shop",
    })

    data.fillOptionValues(instance, rows, 11, "Shop", values)
    lu.assertEquals(values, {})

    local roleKey, branch = data.resolveRole(instance, rows, 11)
    lu.assertEquals(roleKey, "Shop")
    lu.assertEquals(branch.label, "Preboss Shop")
    lu.assertTrue(data.validateRow(instance, rows, 11).valid)

    data.fillRoleValues(instance, rows, 12, values)
    lu.assertEquals(values, {
        "MajorReward",
    })

    roleKey, branch = data.resolveRole(instance, rows, 12)
    lu.assertEquals(roleKey, "MajorReward")
    lu.assertEquals(branch.label, "Preboss Room")
    lu.assertTrue(data.validateRow(instance, rows, 12).valid)
end

function TestRunPlannerControls.testFixedLinearRuntimeBuildsValidatedSnapshot()
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
    lu.assertEquals(snapshot.rows[1].coordinate, 0)
    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "Q_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertEquals(snapshot.rows[2].coordinate, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Vanilla")
    lu.assertTrue(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[3].coordinate, 2)
    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertTrue(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[4].coordinate, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[4].role.key, "Miniboss")
    lu.assertEquals(snapshot.rows[4].optionKey, "Q_MiniBoss02")
    lu.assertEquals(snapshot.rows[4].option.label, "Brute")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].variantKey, "Manual")
    lu.assertEquals(snapshot.rows[4].rewards[1], "Boon")
    lu.assertEquals(snapshot.rows[4].rewards[2], "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[4].rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[4].rewardPicks, {
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

    lu.assertEquals(snapshot.rows[5].roleKey, "Missing")
    lu.assertEquals(snapshot.rows[5].invalidCode, "unknown_role")
    lu.assertFalse(snapshot.rows[5].valid)
    lu.assertEquals(snapshot.rows[5].optionKey, "Q_MiniBoss03")
    lu.assertNil(snapshot.rows[5].option)
end

function TestRunPlannerControls.testMultiEncounterRuntimeBuildsValidatedSnapshot()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat01",
                VariantKey = "",
            },
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat02",
                VariantKey = "ThreeCombats",
            },
            {
                RoleKey = "Fountain",
                OptionKey = "O_Reprieve01",
                Reward1Key = "Minor",
                Reward4Key = "GiftDrop",
            },
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat05",
                VariantKey = "TwoCombats",
            },
            {
                RoleKey = "Miniboss",
                OptionKey = "O_MiniBoss01",
                Reward1Key = "AphroditeUpgrade",
            },
            {
                RoleKey = "Vanilla",
            },
            {},
        }, nil, nil, {
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "PoseidonUpgrade",
            },
            {},
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "ZeusUpgrade",
            },
            {
                Reward1Key = "Minor",
                Reward4Key = "GiftDrop",
            },
            {},
            {},
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "HestiaUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "O")
    lu.assertEquals(snapshot.adapter, "multiEncounterFixed")
    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.rows, 8)

    lu.assertEquals(snapshot.rows[1].coordinate, 0)
    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "O_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertEquals(snapshot.rows[1].rewardKind, "none")
    lu.assertTrue(snapshot.rows[1].valid)

    lu.assertEquals(snapshot.rows[2].coordinate, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "O_Combat01")
    lu.assertEquals(snapshot.rows[2].variantKey, "")
    lu.assertEquals(snapshot.rows[2].variant.sourceKey, "Vanilla")
    lu.assertNil(snapshot.rows[2].realCombatCount)
    lu.assertEquals(snapshot.rows[2].rewardKind, "none")
    lu.assertEquals(snapshot.rows[2].rewardPicks, {})
    lu.assertEquals(snapshot.rows[2].encounterRewardLegs, {})

    lu.assertEquals(snapshot.rows[3].coordinate, 2)
    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[3].optionKey, "O_Combat02")
    lu.assertEquals(snapshot.rows[3].variantKey, "ThreeCombats")
    lu.assertEquals(snapshot.rows[3].variant.sourceKey, "ThreeCombats")
    lu.assertEquals(snapshot.rows[3].variant.label, "3 Combats")
    lu.assertEquals(snapshot.rows[3].realCombatCount, 3)
    lu.assertEquals(snapshot.rows[3].encounterPolicyKey, "O_CombatData")
    lu.assertEquals(snapshot.rows[3].rewardKind, "none")
    lu.assertEquals(snapshot.rows[3].rewardPicks, {})
    lu.assertEquals(#snapshot.rows[3].encounterRewardLegs, 2)
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].key, "Combat1")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].label, "First Combat")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].rewardKind, "majorMinor")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].rewardPicks[1].value, "Major")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].rewardPicks[2].value, "Boon")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].rewardPicks[3].value, "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[2].key, "Combat2")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[2].label, "Second Combat")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[2].rewardKind, "majorMinor")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[2].rewardPicks[1].value, "Minor")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[2].rewardPicks[2].value, "GiftDrop")

    lu.assertEquals(snapshot.rows[4].roleKey, "Fountain")
    lu.assertEquals(snapshot.rows[4].variantKey, "")
    lu.assertNil(snapshot.rows[4].variant)
    lu.assertNil(snapshot.rows[4].encounterPolicyKey)
    lu.assertEquals(snapshot.rows[4].rewardKind, "majorMinor")
    lu.assertEquals(snapshot.rows[4].rewardPicks[1].value, "Minor")
    lu.assertEquals(snapshot.rows[4].rewardPicks[2].value, "GiftDrop")

    lu.assertEquals(snapshot.rows[5].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[5].variantKey, "TwoCombats")
    lu.assertEquals(snapshot.rows[5].realCombatCount, 2)
    lu.assertEquals(snapshot.rows[5].rewardKind, "none")
    lu.assertEquals(#snapshot.rows[5].encounterRewardLegs, 1)
    lu.assertEquals(snapshot.rows[5].encounterRewardLegs[1].key, "Combat1")
    lu.assertEquals(snapshot.rows[5].encounterRewardLegs[1].rewardPicks[3].value, "HestiaUpgrade")

    lu.assertEquals(snapshot.rows[8].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[8].roomKey, "O_PreBoss01")
    lu.assertEquals(snapshot.rows[8].branchKey, "Shop")
    lu.assertEquals(snapshot.rows[8].roleKey, "Shop")
    lu.assertEquals(snapshot.rows[8].role.label, "Preboss Shop")
    lu.assertEquals(snapshot.rows[8].rewardKind, "shop")
end

function TestRunPlannerControls.testMultiEncounterRuntimeInvalidatesUnavailableCombatCount()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(routeFields({
            {},
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat01",
                VariantKey = "ThreeCombats",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "variant_unavailable")
    lu.assertEquals(snapshot.rows[2].invalidCode, "variant_unavailable")
end

function TestRunPlannerControls.testFieldsCageRuntimeBuildsValidatedSnapshot()
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
            },
            {
                RoleKey = "Combat",
                OptionKey = "H_Combat09",
                VariantKey = "TwoRewards",
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
        }, nil, nil, nil, {
            {
                Reward1Key = "Boon",
                Reward2Key = "PoseidonUpgrade",
            },
            {
                Reward1Key = "HermesUpgrade",
            },
            {
                Reward1Key = "StackUpgrade",
            },
            {
                Reward1Key = "Boon",
                Reward2Key = "HestiaUpgrade",
            },
            {
                Reward1Key = "WeaponUpgrade",
            },
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
    lu.assertEquals(snapshot.rows[1].rewardKind, "none")

    lu.assertEquals(snapshot.rows[2].slotKind, "fieldsPick")
    lu.assertEquals(snapshot.rows[2].coordinate, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].roomKey, "H_Combat04")
    lu.assertEquals(snapshot.rows[2].variantKey, "ThreeRewards")
    lu.assertEquals(snapshot.rows[2].cagePolicyKey, "H_FieldsCageRewards")
    lu.assertEquals(snapshot.rows[2].cageRewardCount, 3)
    lu.assertEquals(snapshot.rows[2].rewardKind, "none")
    lu.assertEquals(snapshot.rows[2].rewardPicks, {})
    lu.assertEquals(#snapshot.rows[2].cageRewards, 3)
    lu.assertEquals(snapshot.rows[2].cageRewards[1].key, "Cage1")
    lu.assertEquals(snapshot.rows[2].cageRewards[1].label, "Cage 1")
    lu.assertEquals(snapshot.rows[2].cageRewards[1].rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[2].cageRewards[1].rewardPicks[1].value, "Boon")
    lu.assertEquals(snapshot.rows[2].cageRewards[1].rewardPicks[2].value, "PoseidonUpgrade")
    lu.assertEquals(snapshot.rows[2].cageRewards[1].rewardPicks[2].storageAlias, "Reward2Key")
    lu.assertEquals(snapshot.rows[2].cageRewards[2].rewardPicks[1].value, "HermesUpgrade")
    lu.assertEquals(snapshot.rows[2].cageRewards[3].rewardPicks[1].value, "StackUpgrade")

    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[3].optionKey, "H_Combat09")
    lu.assertEquals(snapshot.rows[3].cageRewardCount, 2)
    lu.assertEquals(#snapshot.rows[3].cageRewards, 2)
    lu.assertEquals(snapshot.rows[3].cageRewards[1].rewardPicks[2].value, "HestiaUpgrade")
    lu.assertEquals(snapshot.rows[3].cageRewards[2].rewardPicks[1].value, "WeaponUpgrade")

    lu.assertEquals(snapshot.rows[4].roleKey, "Bridge")
    lu.assertEquals(snapshot.rows[4].role.label, "Echo")
    lu.assertEquals(snapshot.rows[4].optionKey, "H_Bridge01")
    lu.assertEquals(snapshot.rows[4].roomKey, "H_Bridge01")
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].rewardKind, "none")

    lu.assertEquals(snapshot.rows[5].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[5].optionKey, "H_MiniBoss01")
    lu.assertEquals(snapshot.rows[5].roomKey, "H_MiniBoss01")
    lu.assertEquals(snapshot.rows[5].rewardKind, "boonSource")
    lu.assertEquals(snapshot.rows[5].rewardPicks[1].value, "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[6].slotKind, "fixedAfterRoute")
    lu.assertEquals(snapshot.rows[6].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[6].roomKey, "H_PreBoss01")
    lu.assertEquals(snapshot.rows[6].roleKey, "Preboss")
    lu.assertEquals(snapshot.rows[6].rewardKind, "shop")
end

function TestRunPlannerControls.testFieldsCageRuntimeInvalidatesCageCountAboveMapCapacity()
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

function TestRunPlannerControls.testFieldsCageRuntimeInvalidatesForcedCageRewardsWithoutMap()
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

function TestRunPlannerControls.testFieldsCageAvailabilityFiltersEchoToThirdPick()
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
    lu.assertFalse(hasValue(values, "Miniboss"))
    lu.assertFalse(hasValue(values, "Bridge"))

    data.fillRoleValues(instance, rows, 3, values)
    lu.assertTrue(hasValue(values, "Miniboss"))
    lu.assertFalse(hasValue(values, "Bridge"))

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Bridge"))
end

function TestRunPlannerControls.testFixedLinearRuntimeSnapshotsPrebossBranchRows()
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
    lu.assertEquals(snapshot.rows[8].coordinate, 7)
    lu.assertEquals(snapshot.rows[8].slotKind, "preboss")
    lu.assertEquals(snapshot.rows[8].roomKey, "Q_PreBoss01")
    lu.assertEquals(snapshot.rows[8].branchKey, "Shop")
    lu.assertEquals(snapshot.rows[8].roleKey, "Shop")
    lu.assertEquals(snapshot.rows[8].role.label, "Preboss Shop")
    lu.assertTrue(snapshot.rows[8].valid)
    lu.assertEquals(snapshot.rows[8].rewardKind, "shop")
    lu.assertEquals(#snapshot.rows[8].rewardPicks, 0)
end

function TestRunPlannerControls.testSingleRoomRolesDefaultToConcreteOption()
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
	                RoleKey = "Story",
	                OptionKey = "",
	            },
	        }), instance)
	    local row = control:rowSnapshot(5)

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
	    local control = template.createRuntime(routeFields({
	            {
	                RoleKey = "",
	            },
	            {
	                RoleKey = "Combat",
	                OptionKey = "F_Combat01",
	            },
	        }), instance)
	    local surface = control:rewardSurface(2)

    lu.assertEquals(surface.kind, "majorMinor")
    lu.assertEquals(surface.controls[1].values, { "", "Major", "Minor" })
    lu.assertFalse(hasValue(surface.controls[2].values, "Devotion"))
    lu.assertTrue(hasValue(surface.controls[2].values, "RoomMoneyDrop"))
    lu.assertTrue(hasValue(surface.controls[4].values, "GiftDrop"))
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

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertFalse(hasValue(values, "Story"))
    lu.assertFalse(hasValue(values, "Fountain"))
    lu.assertFalse(hasValue(values, "Midshop"))
    lu.assertFalse(hasValue(values, "Miniboss"))

    rows = fakeRows({
        { RoleKey = "" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    })
    data.fillRoleValues(instance, rows, 5, values)
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

    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, ""))
    lu.assertTrue(hasValue(values, "F_Combat01"))
    lu.assertFalse(hasValue(values, "F_Combat05"))

    data.fillOptionValues(instance, rows, 6, "Combat", values)
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

    data.fillOptionValues(instance, rows, 2, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat10"))
    lu.assertTrue(hasValue(values, "Q_Combat11"))
    lu.assertFalse(hasValue(values, "Q_Combat03"))

    data.fillOptionValues(instance, rows, 3, "Combat", values)
    lu.assertTrue(hasValue(values, "Q_Combat03"))
    lu.assertTrue(hasValue(values, "Q_Combat05"))
    lu.assertTrue(hasValue(values, "Q_Combat15"))
    lu.assertFalse(hasValue(values, "Q_Combat10"))

    data.fillOptionValues(instance, rows, 4, "Miniboss", values)
    lu.assertTrue(hasValue(values, "Q_MiniBoss02"))
    lu.assertTrue(hasValue(values, "Q_MiniBoss05"))
    lu.assertFalse(hasValue(values, "Q_MiniBoss03"))

    data.fillOptionValues(instance, rows, 7, "Miniboss", values)
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

    data.fillRoleValues(instance, rows, 2, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertTrue(hasValue(values, "Combat"))
    lu.assertFalse(hasValue(values, "Miniboss"))

    data.fillRoleValues(instance, rows, 4, values)
    lu.assertTrue(hasValue(values, "Vanilla"))
    lu.assertFalse(hasValue(values, "Combat"))
    lu.assertTrue(hasValue(values, "Miniboss"))

    data.fillRoleValues(instance, rows, 7, values)
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
    lu.assertEquals(snapshot.rows[4].coordinate, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertFalse(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].invalidCode, "forced_depth_role")
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
            RoleKey = "Story",
            OptionKey = "F_Story01",
        },
    })
    local values = {}

    data.fillRoleValues(instance, rows, 5, values)
    lu.assertTrue(hasValue(values, "Story"))

    data.fillRoleValues(instance, rows, 6, values)
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
        { RoleKey = "" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
    }), 5, values)
    lu.assertFalse(hasValue(values, "Midshop"))

    data.fillRoleValues(instance, fakeRows({
        { RoleKey = "" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
    }), 5, values)
    lu.assertTrue(hasValue(values, "Midshop"))
end

function TestRunPlannerControls.testFixedLinearReadPassInvalidationRefreshesCachedValues()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local rowState = {
        { RoleKey = "" },
        { RoleKey = "Vanilla" },
        { RoleKey = "Vanilla" },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
        },
    }
    local rows = fakeRows(rowState)

    data.beginReadPass(instance)
    local values = data.roleValuesForRow(instance, rows, 5)
    lu.assertFalse(hasValue(values, "Midshop"))

    rowState[4].OptionKey = "F_Combat02"
    lu.assertFalse(hasValue(data.roleValuesForRow(instance, rows, 5), "Midshop"))

    data.invalidateReadPass(instance)
    lu.assertTrue(hasValue(data.roleValuesForRow(instance, rows, 5), "Midshop"))
    data.endReadPass(instance)
end

function TestRunPlannerControls.testFixedLinearAvailabilityChecksTrialRewardRequirements()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local values = {}

    data.fillRoleValues(instance, fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
        },
    }), 6, values)
    lu.assertFalse(hasValue(values, "Trial"))

    data.fillRoleValues(instance, fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "AresUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
        },
    }), 6, values)
    lu.assertFalse(hasValue(values, "Trial"))

    data.fillRoleValues(instance, fakeRows({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ApolloUpgrade",
        },
        {
            RoleKey = "Vanilla",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
        },
    }), 6, values)
    lu.assertTrue(hasValue(values, "Trial"))
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesPreviousRoomExitRequirement()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            { RoleKey = "" },
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

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesTrialRewardRequirements()
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
                Reward2Key = "Boon",
                Reward3Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Vanilla",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat04",
            },
	            {
	                RoleKey = "Trial",
	                OptionKey = "F_Combat05",
	                Reward1Key = "ZeusUpgrade",
	                Reward2Key = "ApolloUpgrade",
            },
	        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 6)
    lu.assertEquals(snapshot.invalidRows[1].code, "prior_distinct_god_loot")
    lu.assertFalse(snapshot.rows[6].valid)
    lu.assertEquals(snapshot.rows[6].invalidCode, "prior_distinct_god_loot")
end

function TestRunPlannerControls.testFixedLinearRuntimeInvalidatesOutOfRangeAndDuplicateRows()
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
    lu.assertEquals(snapshot.invalidRows[1].code, "option_unavailable")
    lu.assertEquals(snapshot.invalidRows[2].rowIndex, 6)
    lu.assertEquals(snapshot.invalidRows[2].code, "role_limit")
    lu.assertEquals(snapshot.rows[2].roleKey, "Story")
    lu.assertEquals(snapshot.rows[2].optionKey, "F_Story01")
    lu.assertFalse(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[5].roleKey, "Story")
    lu.assertEquals(snapshot.rows[5].optionKey, "F_Story01")
    lu.assertTrue(snapshot.rows[5].valid)
    lu.assertEquals(snapshot.rows[6].roleKey, "Story")
    lu.assertEquals(snapshot.rows[6].optionKey, "F_Story01")
    lu.assertFalse(snapshot.rows[6].valid)
    lu.assertEquals(snapshot.rows[6].invalidCode, "role_limit")
end
