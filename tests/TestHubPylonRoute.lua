local lu = require("luaunit")
local h = require("tests.support.control_harness")
local loadCatalog = h.loadCatalog
local loadHubPylonTemplate = h.loadHubPylonTemplate
local loadHubPylonData = h.loadHubPylonData
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw

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
    lu.assertEquals(instance.routeSlots[10].kind, "preboss")
    lu.assertEquals(instance.routeSlots[10].label, "Preboss Shop")
    lu.assertNil(instance.routeSlots[10].roomKey)
    lu.assertEquals(instance.routeSlots[10].roleKey, "Preboss")
    lu.assertEquals(instance.roleValues, {
        "Combat",
        "Story",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "N_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "N_Combat05")
    lu.assertEquals(instance.optionValuesByRole.Miniboss, {
        "N_MiniBoss01",
        "N_MiniBoss02",
    })
    lu.assertEquals(instance.maxSideDoorCount, 3)
    lu.assertEquals(instance.biome.hub.sideRoomAvailability.vanillaPolicy, {
        minPerPylon = 0.5,
        chanceAfterMinimum = 0.3,
    })
    lu.assertEquals(instance.sideRoomModeValues, {
        "Disabled",
        "Enabled",
    })
    lu.assertEquals(instance.sideRoomModeLabels, {
        Disabled = "Disabled",
        Enabled = "Enabled",
    })
    lu.assertEquals(instance.sideRoomEncounterClassLabels, {
        Easy = "Easy",
        Empty = "Empty",
        Hard = "Hard",
    })
    lu.assertEquals(routeData.sideRoomEncounterClassValues(
        instance,
        instance.biome.hub.combatRoomsByKey.N_Combat12.sideDoors[1]
    ), { "Hard" })
    lu.assertEquals(routeData.sideRoomEncounterClassValues(
        instance,
        instance.biome.hub.combatRoomsByKey.N_Combat05.sideDoors[1]
    ), { "Easy", "Empty" })
    lu.assertEquals(routeData.sideRoomEncounterClassValues(
        instance,
        instance.biome.hub.combatRoomsByKey.N_Combat12.sideDoors[3]
    ), { "Easy", "Hard" })

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
    lu.assertEquals(storage[3].row[1].default, "Disabled")
    lu.assertEquals(storage[3].row[2].key, "Entered")
    lu.assertEquals(storage[3].row[2].type, "bool")
    lu.assertEquals(storage[3].row[2].default, false)
    lu.assertEquals(storage[3].row[3].key, "EncounterClassKey")
    lu.assertEquals(storage[3].row[3].default, "")
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
    lu.assertTrue(data.validateFormRow(instance, rows, 1).valid)
end


function TestRunPlannerHubPylonRoute.testHubPylonEmitsDumbSelectedRowsSnapshot()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(routeFields({
            { Reward1Key = "SpellDrop" },
            { Reward1Key = "WeaponUpgrade" },
            {},
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat12",
                Reward1Key = "Boon",
                Reward2Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Story",
                OptionKey = "N_Story01",
            },
            {},
            {},
            {},
            {},
            {},
        }, {
            { ModeKey = "Enabled", Entered = true },
            { ModeKey = "Enabled", Entered = false },
            {},
        }, {
            { Reward1Key = "MaxHealthDrop" },
            {},
            {},
        }), instance)

    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.schema, "selectedRows.v1")
    lu.assertEquals(snapshot.controlName, "RouteN")
    lu.assertEquals(snapshot.biomeKey, "N")
    lu.assertEquals(snapshot.adapter, "hubPylon")
    lu.assertEquals(snapshot.hub.roomKey, "N_Hub")
    lu.assertEquals(snapshot.hub.generatedDoorCount, 10)
    lu.assertEquals(snapshot.hub.selectedDoorCount, 6)
    lu.assertNil(snapshot.rows[1].valid)
    lu.assertNil(snapshot.rows[1].roomTopology)
    lu.assertEquals(snapshot.rows[1].roleKey, "Opening")
    lu.assertEquals(snapshot.rows[1].roomKey, "N_Opening01")
    lu.assertEquals(snapshot.rows[3].roleKey, "Hub")
    lu.assertEquals(snapshot.rows[3].roomKey, "N_Hub")

    local pylon = snapshot.rows[4]
    lu.assertEquals(pylon.slotKind, "biomeRow")
    lu.assertEquals(pylon.routeOrdinal, 1)
    lu.assertEquals(pylon.roleKey, "Combat")
    lu.assertEquals(pylon.optionKey, "N_Combat12")
    lu.assertEquals(pylon.roomKey, "N_Combat12")
    lu.assertEquals(pylon.hubDoorId, 561389)
    lu.assertEquals(pylon.topology.hub.roomKey, "N_Hub")
    lu.assertEquals(pylon.rewards.row.values[1], "Boon")
    lu.assertEquals(pylon.rewards.row.values[2], "ZeusUpgrade")
    lu.assertEquals(#pylon.sideRooms, 3)
    lu.assertEquals(pylon.sideRooms[1].roomKey, "N_Sub09")
    lu.assertEquals(pylon.sideRooms[1].modeKey, "Enabled")
    lu.assertTrue(pylon.sideRooms[1].entered)
    lu.assertEquals(pylon.sideRooms[1].encounterClassKey, "Hard")
    lu.assertEquals(pylon.sideRooms[1].rewards[1], "MaxHealthDrop")
    lu.assertEquals(pylon.sideRooms[2].roomKey, "N_Sub10")
    lu.assertTrue(pylon.sideRooms[2].enabled)
    lu.assertFalse(pylon.sideRooms[2].entered)
    lu.assertNil(pylon.sideRooms[2].encounterClassKey)
    lu.assertEquals(pylon.sideRooms[3].roomKey, "N_Sub07")
    lu.assertFalse(pylon.sideRooms[3].enabled)
    lu.assertFalse(pylon.sideRooms[3].entered)

    lu.assertEquals(snapshot.rows[5].roleKey, "Story")
    lu.assertEquals(snapshot.rows[5].optionKey, "N_Story01")
    lu.assertEquals(snapshot.rows[10].roleKey, "Preboss")
end

function TestRunPlannerHubPylonRoute.testHubPylonReadSelectedRowsSnapshot()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(routeFields({
        { Reward1Key = "SpellDrop" },
        { Reward1Key = "WeaponUpgrade" },
        {},
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat05",
            Reward1Key = "MaxHealthDrop",
        },
        {},
        {},
        {},
        {},
        {},
        {},
    }), instance)

    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.schema, "selectedRows.v1")
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[4].optionKey, "N_Combat05")
end

function TestRunPlannerHubPylonRoute.testHubPylonSideRoomProbabilitySummary()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(routeFields({
            { Reward1Key = "SpellDrop" },
            { Reward1Key = "WeaponUpgrade" },
            {},
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat12",
            },
            {
                RoleKey = "Combat",
                OptionKey = "N_Combat06",
            },
        }, {
            { ModeKey = "Enabled", Entered = true },
            { ModeKey = "Enabled", Entered = false },
            {},
            {},
            { ModeKey = "Enabled", Entered = true },
        }), instance)
    local summary = control:sideRoomProbabilitySummary()

    lu.assertEquals(summary.totalCount, 5)
    lu.assertEquals(summary.enabledCount, 3)
    lu.assertEquals(summary.disabledCount, 2)
    lu.assertAlmostEquals(summary.expectedOpenCount, 3, 0.001)
    lu.assertStrContains(summary.text, "Vanilla Side Rooms: min 0.5 per pylon, then 30.0% chance")
    lu.assertStrContains(summary.text, "Planned: 3 enabled / 2 disabled")
    lu.assertStrContains(summary.text, "expected ~3.0 open")
end


local function renderHubPylonRoomDropdowns(control, instance, template)
    local draw = noOpDraw()
    local dropdowns = {}
    draw.widgets.dropdown = function(_, opts)
        dropdowns[#dropdowns + 1] = opts
        return false
    end

    template.views.rooms(draw, control, instance)
    return dropdowns
end

local function findDropdownWithValue(dropdowns, value)
    for _, opts in ipairs(dropdowns or {}) do
        for _, candidate in ipairs(opts.values or {}) do
            if candidate == value then
                return opts
            end
        end
    end
    return nil
end

local function routeContextWithEnrichment(enabled)
    return {
        canUseEnrichmentColors = function()
            return enabled == true
        end,
        blockingHorizon = function()
            return nil
        end,
        isRouteBiomeInactive = function()
            return false
        end,
    }
end

function TestRunPlannerHubPylonRoute.testHubPylonRoomDropdownUsesEphyraEnrichmentColors()
    local catalog = loadCatalog()
    local template = loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(4, "RoleKey"):write("Combat")

    local control = template.createUi(fields, instance)
    control:setRouteContext(routeContextWithEnrichment(true), "Surface")

    local dropdowns = renderHubPylonRoomDropdowns(control, instance, template)
    local combatOpts = findDropdownWithValue(dropdowns, "N_Combat06")

    lu.assertNotNil(combatOpts)
    lu.assertEquals(combatOpts.valueColors.N_Combat06, { 0.25, 0.85, 1.0, 1.0 })
    lu.assertEquals(combatOpts.valueColors.N_Combat05, { 0.35, 0.9, 0.45, 1.0 })

    control:setRouteContext(routeContextWithEnrichment(false), "Surface")

    local disabledDropdowns = renderHubPylonRoomDropdowns(control, instance, template)
    local disabledCombatOpts = findDropdownWithValue(disabledDropdowns, "N_Combat06")

    lu.assertNotNil(disabledCombatOpts)
    lu.assertNil(disabledCombatOpts.valueColors)
end
