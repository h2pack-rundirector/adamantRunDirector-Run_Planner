local lu = require("luaunit")
local h = require("tests.support.control_harness")
local primaryRewardItem = h.primaryRewardItem
local rewardItemBySource = h.rewardItemBySource
local loadCatalog = h.loadCatalog
local loadHubPylonTemplate = h.loadHubPylonTemplate
local loadHubPylonData = h.loadHubPylonData
local fakeRows = h.fakeRows
local routeFields = h.routeFields

-- luacheck: globals TestRunPlannerHubPylonRoute
TestRunPlannerHubPylonRoute = {}

function TestRunPlannerHubPylonRoute.testHubPylonStorageMatchesEphyraRouteRows()
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
    lu.assertEquals(instance.routeSlots[3].roomHistoryCost, 0)
    lu.assertEquals(instance.routeSlots[4].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[4].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[4].label, "Pylon 1")
    lu.assertEquals(instance.routeSlots[9].routeOrdinal, 6)
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

function TestRunPlannerHubPylonRoute.testHubPylonFixedRowsUseImplicitRooms()
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

function TestRunPlannerHubPylonRoute.testHubPylonRuntimeBuildsValidatedSnapshot()
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
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "roomStore")
    lu.assertEquals(snapshot.rows[3].slotLabel, "Hub")
    lu.assertEquals(snapshot.rows[3].roomHistoryCost, 0)

    lu.assertEquals(snapshot.rows[4].slotKind, "biomeRow")
    lu.assertEquals(snapshot.rows[4].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[4].optionKey, "N_Combat12")
    lu.assertEquals(snapshot.rows[4].roomKey, "N_Combat12")
    lu.assertEquals(snapshot.rows[4].roomHistoryCost, 2)
    lu.assertEquals(snapshot.rows[4].hubDoorId, 561389)
    lu.assertEquals(#snapshot.rows[4].sideDoors, 3)
    lu.assertEquals(#snapshot.rows[4].sideRooms, 3)
    lu.assertTrue(snapshot.rows[4].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardKind, "roomStore")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardPicks[1].value, "Boon")
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardPicks[2].value, "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].roomKey, "N_Sub09")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].doorId, 558352)
    lu.assertEquals(snapshot.rows[4].sideRooms[1].modeKey, "Enabled")
    lu.assertEquals(snapshot.rows[4].sideRooms[1].storedModeKey, "Enabled")
    lu.assertTrue(snapshot.rows[4].sideRooms[1].enabled)
    lu.assertEquals(snapshot.rows[4].sideRooms[1].rewardStore, "SubRoomRewardsHard")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 1).rewardKind, "roomStore")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 1).rewardPicks[1], {
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
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 2).rewardKind, "none")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 2).rewardPicks, {})
    lu.assertEquals(snapshot.rows[4].sideRooms[3].roomKey, "N_Sub07")
    lu.assertEquals(snapshot.rows[4].sideRooms[3].modeKey, "Vanilla")
    lu.assertEquals(snapshot.rows[4].sideRooms[3].storedModeKey, "")
    lu.assertFalse(snapshot.rows[4].sideRooms[3].enabled)
    lu.assertEquals(snapshot.rows[4].sideRooms[3].rewardStore, "SubRoomRewards")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "side", 3).rewardPicks, {})

    lu.assertEquals(snapshot.rows[5].roleKey, "Story")
    lu.assertEquals(snapshot.rows[5].optionKey, "N_Story01")
    lu.assertEquals(snapshot.rows[5].roomKey, "N_Story01")
    lu.assertEquals(snapshot.rows[5].hubDoorId, 560848)
    lu.assertTrue(snapshot.rows[5].valid)

    lu.assertEquals(snapshot.rows[6].roleKey, "Miniboss")
    lu.assertEquals(snapshot.rows[6].optionKey, "N_MiniBoss02")
    lu.assertEquals(snapshot.rows[6].roomKey, "N_MiniBoss02")
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardKind, "boonSource")
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardPicks[1].value, "AphroditeUpgrade")
    lu.assertTrue(snapshot.rows[6].valid)

    lu.assertEquals(snapshot.rows[7].roleKey, "Story")
    lu.assertFalse(snapshot.rows[7].valid)
    lu.assertEquals(snapshot.rows[7].invalidCode, "role_limit")

    lu.assertEquals(snapshot.rows[10].slotKind, "fixedAfterHub")
    lu.assertEquals(snapshot.rows[10].slotLabel, "Preboss Shop")
    lu.assertEquals(snapshot.rows[10].roomKey, "N_PreBoss01")
    lu.assertEquals(snapshot.rows[10].roleKey, "Preboss")
    lu.assertEquals(snapshot.rows[10].roomHistoryCost, 1)
    lu.assertTrue(snapshot.rows[10].valid)
    lu.assertEquals(primaryRewardItem(snapshot.rows[10]).rewardKind, "shop")
end

function TestRunPlannerHubPylonRoute.testHubPylonPolicyAllowsDuplicateBoonSources()
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
                RoleKey = "Combat",
                OptionKey = "N_Combat13",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
            },
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 0)
    lu.assertEquals(primaryRewardItem(snapshot.rows[4]).rewardPicks[2].value, "ZeusUpgrade")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[2].value, "ZeusUpgrade")
end

function TestRunPlannerHubPylonRoute.testHubPylonPolicyRejectsDuplicateNonBoonRewards()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local rowData = {
            {},
            {},
            {},
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat12",
                Reward1Key = "MaxHealthDropBig",
            },
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat13",
                Reward1Key = "MaxHealthDropBig",
            },
        }
    local control = template.createRuntime(routeFields(rowData), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(#snapshot.invalidRows, 1)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 5)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_reward_type")
    lu.assertEquals(snapshot.rows[5].invalidCode, "duplicate_reward_type")

end
