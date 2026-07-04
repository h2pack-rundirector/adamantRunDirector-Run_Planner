local lu = require("luaunit")
local h = require("tests.support.control_harness")
local loadCatalog = h.loadCatalog
local loadHubPylonTemplate = h.loadHubPylonTemplate
local loadMultiEncounterTemplate = h.loadMultiEncounterTemplate
local loadRouteGlobalTemplate = h.loadRouteGlobalTemplate
local loadMultiEncounterData = h.loadMultiEncounterData
local loadRunContext = h.loadRunContext
local hasValue = h.hasValue
local fakeRows = h.fakeRows
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local noOpDraw = h.noOpDraw

-- luacheck: globals TestRunPlannerMultiEncounterRoute
TestRunPlannerMultiEncounterRoute = {}

local function thessalyCombat(optionKey, variantKey)
    variantKey = variantKey or "TwoCombats"
    local row = {
        RoleKey = "Combat",
        OptionKey = optionKey,
        VariantKey = variantKey,
        WheelOffer1Key = "OneChoice",
    }
    if variantKey == "ThreeCombats" then
        row.WheelOffer2Key = "TwoChoices"
    end
    return row
end

local function thessalyEncounterRewardRows(rows)
    local encounterRows = {}
    for rowIndex, row in ipairs(rows or {}) do
        local offset = (rowIndex - 2) * 2
        if offset >= 0 then
            if row.WheelOffer1Key ~= nil then
                encounterRows[offset + 1] = {
                    WheelOffer1Key = row.WheelOffer1Key,
                    Reward1Key = "Major",
                    Reward2Key = "MaxHealthDrop",
                }
            end
            if row.WheelOffer2Key ~= nil then
                encounterRows[offset + 2] = {
                    WheelOffer2Key = row.WheelOffer2Key,
                    Reward1Key = "Major",
                    Reward2Key = "MaxHealthDrop",
                }
            end
        end
    end
    return encounterRows
end

local function thessalyRouteFields(rows, encounterRewardRows)
    return routeFields(rows, encounterRewardRows or thessalyEncounterRewardRows(rows))
end

local function buildThessalyControlWithEncounterRewards(rows)
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    return template.createRuntime(thessalyRouteFields(rows), instance)
end



function TestRunPlannerMultiEncounterRoute.testMultiEncounterStorageMatchesThessalyRouteRows()
    local catalog = loadCatalog()
    local routeData = loadMultiEncounterData()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local storage = template.storage(instance)

    lu.assertEquals(instance.routeRowCount, 8)
    lu.assertEquals(instance.routeSlots[1].routeOrdinal, 0)
    lu.assertEquals(instance.routeSlots[1].kind, "intro")
    lu.assertEquals(instance.routeSlots[1].label, "Intro")
    lu.assertEquals(instance.routeSlots[1].roomKey, "O_Intro")
    lu.assertEquals(instance.routeSlots[1].roleKey, "Intro")
    lu.assertEquals(instance.routeSlots[2].routeOrdinal, 1)
    lu.assertEquals(instance.routeSlots[2].kind, "biomeRow")
    lu.assertEquals(instance.routeSlots[2].label, "Depth 1")
    lu.assertEquals(instance.routeSlots[7].routeOrdinal, 6)
    lu.assertEquals(instance.routeSlots[8].routeOrdinal, 7)
    lu.assertEquals(instance.routeSlots[8].kind, "preboss")
    lu.assertEquals(instance.routeSlots[8].label, "Preboss Shop")
    lu.assertEquals(instance.routeSlots[8].roleKey, "Preboss")
    lu.assertEquals(instance.roleValues, {
        "Combat",
        "Story",
        "Fountain",
        "Midshop",
        "Devotion",
        "Miniboss",
    })
    lu.assertEquals(instance.optionValuesByRole.Story, { "O_Story01" })
    lu.assertEquals(instance.optionValuesByRole.Combat[1], "O_Combat01")

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
    lu.assertEquals(storage[3].row[13].key, "Reward1StateKey")
    lu.assertEquals(storage[3].row[18].key, "Reward6StateKey")
    lu.assertEquals(storage[3].row[19].key, "PrebossBranchKey")
    lu.assertEquals(storage[3].row[20].key, "WheelOffer1Key")
    lu.assertEquals(storage[3].row[21].key, "WheelOffer2Key")
    lu.assertNil(routeData.encounterRewardRowIndex(instance, 1, 1))
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 2, 1), 1)
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 2, 2), 2)
    lu.assertEquals(routeData.encounterRewardRowIndex(instance, 7, 2), 12)
    lu.assertNil(routeData.encounterRewardRowIndex(instance, 8, 1))

    lu.assertEquals(routeData.variantLabelsForRow(instance, "Combat"), {
        TwoCombats = "2 Combats",
        ThreeCombats = "3 Combats",
    })
    local rows = fakeRows({
        {},
        {
            RoleKey = "Combat",
            VariantKey = "TwoCombats",
        },
        {
            RoleKey = "Combat",
            VariantKey = "TwoCombats",
        },
        {
            RoleKey = "Combat",
            VariantKey = "TwoCombats",
        },
        {
            RoleKey = "Combat",
            VariantKey = "ThreeCombats",
        },
    })

    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 2, "Combat"), {
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 3, "Combat"), {
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 4, "Combat"), {
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 6, "Combat"), {
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 7, "Combat"), {
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 3, "Story"), {})
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterCombatRequiresCombatCount()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(thessalyRouteFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
        },
    }), instance)
    local completion = control:read("completion")

    lu.assertFalse(completion.valid)
    lu.assertEquals(completion.completionInvalidRows[1].rowIndex, 2)
    lu.assertEquals(completion.completionInvalidRows[1].code, "selection_required")
    lu.assertEquals(completion.completionInvalidRows[1].message, "Choose combat count")
    lu.assertEquals(completion.completionInvalidRows[1].tabKey, "rooms")
    lu.assertEquals(completion.completionInvalidRows[1].controlTargets[1].controlAlias, "VariantKey")
end


function TestRunPlannerMultiEncounterRoute.testMultiEncounterRewardRatioSummaryCountsEncounterLegs()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(thessalyRouteFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
            VariantKey = "TwoCombats",
        },
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat02",
            VariantKey = "TwoCombats",
        },
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat03",
            VariantKey = "ThreeCombats",
        },
    }, {
        {},
        {},
        {},
        {},
        { Reward1Key = "Minor" },
        { Reward1Key = "Major" },
    }), instance)
    local summary = control:rewardRatioSummary()

    lu.assertEquals(summary.targetMetaProgress, 0.30)
    lu.assertEquals(summary.totalCount, 4)
    lu.assertEquals(summary.minorCount, 1)
    lu.assertEquals(summary.majorCount, 1)
    lu.assertEquals(summary.unsetCount, 2)
    lu.assertEquals(
        summary.text,
        "Expected Minor/Major: 30.0% / 70.0%    Current Minor/Major: 50.0% / 50.0% (2/4 set, 2 vanillas)"
    )
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterSnapshotUsesSelectedOptionRoomKey()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(thessalyRouteFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
            VariantKey = "TwoCombats",
        },
    }), instance)
    local snapshot = control:read("selectedNodesSnapshot")

    lu.assertEquals(snapshot.nodes[2].currentRoom.optionKey, "O_Combat01")
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterEmitsSelectedNodesSnapshot()
    local control = buildThessalyControlWithEncounterRewards({
        {},
        thessalyCombat("O_Combat01"),
        thessalyCombat("O_Combat02", "ThreeCombats"),
    })

    local snapshot = control:read("selectedNodesSnapshot")

    lu.assertEquals(snapshot.schema, "selectedNodes.v1")
    lu.assertEquals(snapshot.controlName, "RouteO")
    lu.assertEquals(snapshot.biomeKey, "O")
    lu.assertEquals(snapshot.adapter, "multiEncounterFixed")
    lu.assertEquals(snapshot.nodes[1].currentRoom.roleKey, "Intro")
    lu.assertEquals(snapshot.nodes[1].currentRoom.optionKey, "O_Intro")
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.roleKey, "Combat")
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.optionKey, "O_Combat01")
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.rewards.encounter[1].wheelOfferKey, "OneChoice")
    lu.assertEquals(snapshot.nodes[2].currentRoom.roleKey, "Combat")
    lu.assertEquals(snapshot.nodes[2].currentRoom.optionKey, "O_Combat01")
    lu.assertEquals(snapshot.nodes[2].currentRoom.variantKey, "TwoCombats")
    lu.assertEquals(#snapshot.nodes[2].rewards.encounter, 1)
    lu.assertEquals(snapshot.nodes[2].rewards.encounter[1].values[2], "MaxHealthDrop")
    lu.assertEquals(snapshot.nodes[3].currentRoom.variantKey, "ThreeCombats")
    lu.assertEquals(#snapshot.nodes[3].rewards.encounter, 2)
    lu.assertEquals(snapshot.nodes[3].rewards.encounter[2].wheelOfferKey, "TwoChoices")
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterWheelTopologyRendersInRewardsView()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local fields = routeUiFields(template.storage(instance))
    fields.Rooms:get(2, "RoleKey"):write("Combat")
    fields.Rooms:get(2, "OptionKey"):write("O_Combat01")
    fields.Rooms:get(2, "VariantKey"):write("TwoCombats")
    fields.Rooms:get(3, "RoleKey"):write("Combat")
    fields.Rooms:get(3, "OptionKey"):write("O_Combat02")
    fields.Rooms:get(3, "VariantKey"):write("ThreeCombats")
    fields.EncounterRewards:get(1, "WheelOffer1Key"):write("OneChoice")
    local control = template.createUi(fields, instance)
    local draw = noOpDraw()
    local roomWheelDropdownCount = 0
    local rewardWheelDropdownCount = 0

    draw.widgets.dropdown = function(_, opts)
        if hasValue(opts.values or {}, "OneChoice") and hasValue(opts.values or {}, "TwoChoices") then
            roomWheelDropdownCount = roomWheelDropdownCount + 1
        end
        return false
    end
    template.views.rooms(draw, control, instance)

    draw.widgets.dropdown = function(_, opts)
        if hasValue(opts.values or {}, "OneChoice") and hasValue(opts.values or {}, "TwoChoices") then
            rewardWheelDropdownCount = rewardWheelDropdownCount + 1
        end
        return false
    end
    template.views.rewards(draw, control, instance)

    lu.assertEquals(roomWheelDropdownCount, 0)
    lu.assertEquals(rewardWheelDropdownCount, 3)
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterRequiresWheelOfferCountForRewardTopology()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(thessalyRouteFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
            VariantKey = "TwoCombats",
        },
    }), instance)
    local completion = control:read("completion")

    lu.assertFalse(completion.valid)
    lu.assertEquals(completion.completionInvalidRows[1].rowIndex, 2)
    lu.assertEquals(completion.completionInvalidRows[1].code, "ship_wheel_offer_count_required")
    lu.assertEquals(completion.completionInvalidRows[1].message, "Choose wheel choices for 1st Encounter")
    lu.assertEquals(completion.completionInvalidRows[1].tabKey, "rewards")
    lu.assertEquals(completion.completionInvalidRows[1].controlTargets[1].address, "encounter:1")
    lu.assertEquals(completion.completionInvalidRows[1].controlTargets[1].controlAlias, "WheelOffer1Key")
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterRequiresWheelOfferCountForEachActiveLeg()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(thessalyRouteFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
            VariantKey = "ThreeCombats",
            WheelOffer1Key = "OneChoice",
        },
    }), instance)
    local completion = control:read("completion")

    lu.assertFalse(completion.valid)
    lu.assertEquals(completion.completionInvalidRows[1].rowIndex, 2)
    lu.assertEquals(completion.completionInvalidRows[1].code, "ship_wheel_offer_count_required")
    lu.assertEquals(completion.completionInvalidRows[1].message, "Choose wheel choices for 2nd Encounter")
    lu.assertEquals(completion.completionInvalidRows[1].tabKey, "rewards")
    lu.assertEquals(completion.completionInvalidRows[1].controlTargets[1].address, "encounter:2")
    lu.assertEquals(completion.completionInvalidRows[1].controlTargets[1].controlAlias, "WheelOffer2Key")
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterRejectsUnknownWheelOfferCount()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(thessalyRouteFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
            VariantKey = "TwoCombats",
            WheelOffer1Key = "BadWheel",
        },
    }), instance)
    local completion = control:read("completion")

    lu.assertFalse(completion.valid)
    lu.assertEquals(completion.completionInvalidRows[1].rowIndex, 2)
    lu.assertEquals(completion.completionInvalidRows[1].code, "unknown_wheel_offer_count")
    lu.assertEquals(completion.completionInvalidRows[1].message, "Unknown wheel choices for 1st Encounter: BadWheel")
    lu.assertEquals(completion.completionInvalidRows[1].tabKey, "rewards")
    lu.assertEquals(completion.completionInvalidRows[1].controlTargets[1].address, "encounter:1")
    lu.assertEquals(completion.completionInvalidRows[1].controlTargets[1].controlAlias, "WheelOffer1Key")
end



function TestRunPlannerMultiEncounterRoute.testMultiEncounterExportsDuplicateTrialRewardGods()
    local catalog = loadCatalog()
    local template = loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(thessalyRouteFields({
        {},
        thessalyCombat("O_Combat01"),
        thessalyCombat("O_Combat02"),
        {
            RoleKey = "Devotion",
            OptionKey = "O_Devotion01",
            Reward1Key = "ZeusUpgrade",
            Reward2Key = "ZeusUpgrade",
        },
    }), instance)
    local snapshot = control:read("selectedNodesSnapshot")

    lu.assertEquals(snapshot.nodes[4].rewards.row.values[1], "ZeusUpgrade")
    lu.assertEquals(snapshot.nodes[4].rewards.row.values[2], "ZeusUpgrade")
end


function TestRunPlannerMultiEncounterRoute.testMultiEncounterDevotionRequirementsUsePriorSurfaceBiomes()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalSurface",
        route = catalog.routes.lookup.Surface,
        gods = catalog.gods,
    })
    local globalFields = routeUiFields(globalTemplate.storage(globalInstance))
    globalFields.ConfigureRewards:write(false)
    local globalControl = globalTemplate.createRuntime(globalFields, globalInstance)
    local hubTemplate = loadHubPylonTemplate()
    local nInstance = hubTemplate.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local nControl = hubTemplate.createRuntime(routeFields({
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
            OptionKey = "N_Story01",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "N_MiniBoss02",
            Reward1Key = "AphroditeUpgrade",
        },
    }), nInstance)
    local routeContext = loadRunContext().create({
        routes = catalog.routes,
        controlResolver = function(controlName)
            if controlName == "RouteN" then
                return nControl
            elseif controlName == "RouteGlobalSurface" then
                return globalControl
            end
            return nil
        end,
    })

    local data = loadMultiEncounterData()
    local oInstance = data.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local rows = fakeRows({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat02",
        },
        {},
    })

    lu.assertTrue(hasValue(data.roleValuesForRow(oInstance, rows, 4), "Devotion"))

    oInstance.routeContext = routeContext
    oInstance.routeKey = "Surface"
    lu.assertTrue(hasValue(data.roleValuesForRow(oInstance, rows, 4), "Devotion"))
    lu.assertNotNil(data.roleValueStatesForRow(oInstance, rows, 4).Devotion)

    globalFields.ConfigureRewards:write(true)
    routeContext:beginPass()
    lu.assertTrue(hasValue(data.roleValuesForRow(oInstance, rows, 4), "Devotion"))
    lu.assertNil(data.roleValueStatesForRow(oInstance, rows, 4).Devotion)
end
