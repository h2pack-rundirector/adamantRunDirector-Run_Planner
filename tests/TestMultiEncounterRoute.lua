local lu = require("luaunit")
local h = require("tests.support.control_harness")
local primaryRewardItem = h.primaryRewardItem
local rewardItemBySource = h.rewardItemBySource
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
local buildThessalyRuntime = h.buildThessalyRuntime
local attachSingleBiomeRouteContext = h.attachSingleBiomeRouteContext

-- luacheck: globals TestRunPlannerMultiEncounterRoute
TestRunPlannerMultiEncounterRoute = {}

function TestRunPlannerMultiEncounterRoute.testThessalyRequiresStoryOrShopByDepthFive()
    local control = buildThessalyRuntime({
        {},
        { RoleKey = "Combat", OptionKey = "O_Combat01" },
        { RoleKey = "Combat", OptionKey = "O_Combat02" },
        { RoleKey = "Combat", OptionKey = "O_Combat03" },
        { RoleKey = "Combat", OptionKey = "O_Combat05" },
        { RoleKey = "Combat", OptionKey = "O_Combat06" },
    })
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertTrue(snapshot.rows[5].valid)
    lu.assertFalse(snapshot.rows[6].valid)
    lu.assertEquals(snapshot.rows[6].routeOrdinal, 5)
    lu.assertEquals(snapshot.rows[6].invalidCode, "thessaly_story_or_shop_deadline")
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 6)
    lu.assertEquals(snapshot.invalidRows[1].code, "thessaly_story_or_shop_deadline")
end

function TestRunPlannerMultiEncounterRoute.testThessalyDepthFiveStorySatisfiesDeadline()
    local control = buildThessalyRuntime({
        {},
        { RoleKey = "Combat", OptionKey = "O_Combat01" },
        { RoleKey = "Combat", OptionKey = "O_Combat02" },
        { RoleKey = "Combat", OptionKey = "O_Combat03" },
        { RoleKey = "Combat", OptionKey = "O_Combat05" },
        { RoleKey = "Story", OptionKey = "O_Story01" },
    })
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertTrue(snapshot.rows[6].valid)
end

function TestRunPlannerMultiEncounterRoute.testThessalyPriorShopSatisfiesDeadline()
    local control = buildThessalyRuntime({
        {},
        { RoleKey = "Combat", OptionKey = "O_Combat01" },
        { RoleKey = "Combat", OptionKey = "O_Combat02" },
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat03",
            VariantKey = "ThreeCombats",
            WheelOffer1Key = "OneChoice",
            WheelOffer2Key = "TwoChoices",
        },
        { RoleKey = "Midshop", OptionKey = "O_Shop01" },
        { RoleKey = "Combat", OptionKey = "O_Combat06" },
    })
    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertTrue(snapshot.rows[5].valid)
    lu.assertTrue(snapshot.rows[6].valid)
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
        "Vanilla",
        "Combat",
        "Story",
        "Fountain",
        "Midshop",
        "Devotion",
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
    lu.assertEquals(storage[1].row[4].key, "WheelOffer1Key")
    lu.assertEquals(storage[1].row[5].key, "WheelOffer2Key")
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
        "",
        "TwoCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 3, "Combat"), {
        "",
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 4, "Combat"), {
        "",
        "TwoCombats",
        "ThreeCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 6, "Combat"), {
        "",
        "TwoCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 7, "Combat"), {
        "",
        "TwoCombats",
    })
    lu.assertEquals(routeData.variantValuesForRow(instance, rows, 3, "Story"), {})
    lu.assertEquals(routeData.rowContext(instance, rows, 2).biomeEncounterDepth, 1)
    lu.assertEquals(routeData.rowContext(instance, rows, 3).biomeEncounterDepth, 2)
    lu.assertEquals(routeData.rowContext(instance, rows, 4).biomeEncounterDepth, 3)
    lu.assertEquals(routeData.rowContext(instance, rows, 5).biomeEncounterDepth, 4)
    lu.assertEquals(routeData.rowContext(instance, rows, 6).biomeEncounterDepth, 6)
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterRewardRatioSummaryCountsEncounterLegs()
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
    }, nil, nil, {
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
    local control = template.createRuntime(routeFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat01",
            VariantKey = "TwoCombats",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.rows[2].roomKey, "O_Combat01")
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterWheelTopologyRendersInRoomsView()
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
    fields.Rooms:get(2, "WheelOffer1Key"):write("OneChoice")
    fields.Rooms:get(3, "RoleKey"):write("Combat")
    fields.Rooms:get(3, "OptionKey"):write("O_Combat02")
    fields.Rooms:get(3, "VariantKey"):write("ThreeCombats")
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

    lu.assertEquals(roomWheelDropdownCount, 3)
    lu.assertEquals(rewardWheelDropdownCount, 0)
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterRequiresWheelOfferCountForTopology()
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
            VariantKey = "TwoCombats",
        },
    }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.disabled)
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 2)
    lu.assertEquals(snapshot.invalidRows[1].code, "ship_wheel_offer_count_required")
    lu.assertEquals(snapshot.rows[2].invalidCode, "ship_wheel_offer_count_required")
    lu.assertNil(snapshot.rows[2].roomTopology)
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterRoomTopologySurvivesWhenRewardsDisabled()
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
            VariantKey = "TwoCombats",
            WheelOffer1Key = "OneChoice",
        },
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat02",
            VariantKey = "ThreeCombats",
            WheelOffer1Key = "OneChoice",
            WheelOffer2Key = "TwoChoices",
        },
    }), instance)

    control:setRouteContext({
        isLayerConfigured = function(_, _, layer)
            return layer ~= "rewards"
        end,
        markDirty = function()
        end,
    }, "Surface")

    local snapshot = control:buildSnapshot()

    lu.assertTrue(snapshot.valid)
    lu.assertEquals(snapshot.rows[3].roomTopology, {
        kind = "shipCombat",
        encounters = {
            {
                address = "encounter:1",
                wheelOfferCount = 1,
            },
            {
                address = "encounter:2",
                wheelOfferCount = 2,
            },
        },
    })
    lu.assertEquals(snapshot.rows[3].rewardItems[1].rewardKind, "vanilla")
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterRuntimeBuildsValidatedSnapshot()
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
                VariantKey = "TwoCombats",
                WheelOffer1Key = "TwoChoices",
            },
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat03",
                VariantKey = "ThreeCombats",
                WheelOffer1Key = "OneChoice",
                WheelOffer2Key = "TwoChoices",
            },
            {
                RoleKey = "Fountain",
                OptionKey = "O_Reprieve01",
                Reward1Key = "Minor",
                Reward4Key = "GiftDrop",
            },
            {
                RoleKey = "Story",
                OptionKey = "O_Story01",
            },
            {
                RoleKey = "Combat",
                OptionKey = "O_Combat05",
                VariantKey = "TwoCombats",
                WheelOffer1Key = "OneChoice",
            },
            {},
        }, nil, nil, {
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "ZeusUpgrade",
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
            {},
            {},
            {
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "HestiaUpgrade",
            },
            {},
        }), instance)
    local snapshot = control:buildSnapshot()

    lu.assertEquals(snapshot.biomeKey, "O")
    lu.assertEquals(snapshot.adapter, "multiEncounterFixed")
    lu.assertTrue(snapshot.valid)
    lu.assertFalse(snapshot.disabled)
    lu.assertEquals(#snapshot.rows, 8)

    lu.assertEquals(snapshot.rows[1].routeOrdinal, 0)
    lu.assertEquals(snapshot.rows[1].slotKind, "intro")
    lu.assertEquals(snapshot.rows[1].roomKey, "O_Intro")
    lu.assertEquals(snapshot.rows[1].roleKey, "Intro")
    lu.assertEquals(snapshot.rows[1].exitCount, 1)
    lu.assertEquals(snapshot.rows[1].rewardExitCount, 0)
    lu.assertEquals(primaryRewardItem(snapshot.rows[1]).rewardKind, "none")
    lu.assertTrue(snapshot.rows[1].valid)

    lu.assertEquals(snapshot.rows[2].routeOrdinal, 1)
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "O_Combat01")
    lu.assertEquals(snapshot.rows[2].exitCount, 1)
    lu.assertEquals(snapshot.rows[2].rewardExitCount, 0)
    lu.assertEquals(snapshot.rows[2].variantKey, "")
    lu.assertEquals(snapshot.rows[2].variant.sourceKey, "Vanilla")
    lu.assertNil(snapshot.rows[2].realCombatCount)
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardKind, "none")
    lu.assertEquals(primaryRewardItem(snapshot.rows[2]).rewardPicks, {})
    lu.assertEquals(snapshot.rows[2].encounterRewardLegs, {})

    lu.assertEquals(snapshot.rows[3].routeOrdinal, 2)
    lu.assertEquals(snapshot.rows[3].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[3].optionKey, "O_Combat02")
    lu.assertEquals(snapshot.rows[3].variantKey, "TwoCombats")
    lu.assertEquals(snapshot.rows[3].variant.sourceKey, "TwoCombats")
    lu.assertEquals(snapshot.rows[3].variant.label, "2 Combats")
    lu.assertEquals(snapshot.rows[3].realCombatCount, 2)
    lu.assertEquals(snapshot.rows[3].encounterPolicyKey, "O_CombatData")
    lu.assertEquals(snapshot.rows[3].roomTopology, {
        kind = "shipCombat",
        encounters = {
            {
                address = "encounter:1",
                wheelOfferCount = 2,
            },
        },
    })
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardKind, "none")
    lu.assertEquals(primaryRewardItem(snapshot.rows[3]).rewardPicks, {})
    lu.assertEquals(#snapshot.rows[3].encounterRewardLegs, 1)
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].key, "Encounter1")
    lu.assertEquals(snapshot.rows[3].encounterRewardLegs[1].label, "First Encounter")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "encounter", 1).rewardKind, "majorMinor")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "encounter", 1).rewardPicks[1].value, "Major")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "encounter", 1).rewardPicks[2].value, "Boon")
    lu.assertEquals(rewardItemBySource(snapshot.rows[3], "encounter", 1).rewardPicks[3].value, "ZeusUpgrade")

    lu.assertEquals(snapshot.rows[4].routeOrdinal, 3)
    lu.assertEquals(snapshot.rows[4].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[4].optionKey, "O_Combat03")
    lu.assertEquals(snapshot.rows[4].variantKey, "ThreeCombats")
    lu.assertEquals(snapshot.rows[4].variant.sourceKey, "ThreeCombats")
    lu.assertEquals(snapshot.rows[4].variant.label, "3 Combats")
    lu.assertEquals(snapshot.rows[4].realCombatCount, 3)
    lu.assertEquals(snapshot.rows[4].roomTopology, {
        kind = "shipCombat",
        encounters = {
            {
                address = "encounter:1",
                wheelOfferCount = 1,
            },
            {
                address = "encounter:2",
                wheelOfferCount = 2,
            },
        },
    })
    lu.assertEquals(#snapshot.rows[4].encounterRewardLegs, 2)
    lu.assertEquals(snapshot.rows[4].encounterRewardLegs[1].key, "Encounter1")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "encounter", 1).rewardPicks[3].value, "ZeusUpgrade")
    lu.assertEquals(snapshot.rows[4].encounterRewardLegs[2].key, "Encounter2")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "encounter", 2).rewardPicks[1].value, "Minor")
    lu.assertEquals(rewardItemBySource(snapshot.rows[4], "encounter", 2).rewardPicks[2].value, "GiftDrop")

    lu.assertEquals(snapshot.rows[5].roleKey, "Fountain")
    lu.assertEquals(snapshot.rows[5].variantKey, "")
    lu.assertNil(snapshot.rows[5].variant)
    lu.assertNil(snapshot.rows[5].encounterPolicyKey)
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardKind, "majorMinor")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[1].value, "Minor")
    lu.assertEquals(primaryRewardItem(snapshot.rows[5]).rewardPicks[2].value, "GiftDrop")

    lu.assertEquals(snapshot.rows[6].roleKey, "Story")
    lu.assertEquals(snapshot.rows[6].optionKey, "O_Story01")
    lu.assertEquals(snapshot.rows[6].variantKey, "")
    lu.assertNil(snapshot.rows[6].variant)
    lu.assertNil(snapshot.rows[6].realCombatCount)
    lu.assertEquals(primaryRewardItem(snapshot.rows[6]).rewardKind, "none")
    lu.assertEquals(snapshot.rows[6].encounterRewardLegs, {})

    lu.assertEquals(snapshot.rows[7].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[7].variantKey, "TwoCombats")
    lu.assertEquals(snapshot.rows[7].realCombatCount, 2)
    lu.assertEquals(snapshot.rows[7].roomTopology, {
        kind = "shipCombat",
        encounters = {
            {
                address = "encounter:1",
                wheelOfferCount = 1,
            },
        },
    })
    lu.assertEquals(primaryRewardItem(snapshot.rows[7]).rewardKind, "none")
    lu.assertEquals(#snapshot.rows[7].encounterRewardLegs, 1)
    lu.assertEquals(snapshot.rows[7].encounterRewardLegs[1].key, "Encounter1")
    lu.assertEquals(rewardItemBySource(snapshot.rows[7], "encounter", 1).rewardPicks[3].value, "HestiaUpgrade")

    lu.assertEquals(snapshot.rows[8].slotKind, "preboss")
    lu.assertNil(snapshot.rows[8].roomKey)
    lu.assertEquals(snapshot.rows[8].roleKey, "Preboss")
    lu.assertEquals(snapshot.rows[8].role.label, "Preboss Shop")
    lu.assertEquals(primaryRewardItem(snapshot.rows[8]).rewardKind, "shop")
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterInvalidatesDuplicateTrialRewardGods()
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
        },
        {
            RoleKey = "Combat",
            OptionKey = "O_Combat02",
        },
        {
            RoleKey = "Devotion",
            OptionKey = "O_Devotion01",
            Reward1Key = "ZeusUpgrade",
            Reward2Key = "ZeusUpgrade",
        },
    }), instance)
    attachSingleBiomeRouteContext(control, "Surface", "O")
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertFalse(snapshot.rows[4].valid)
    lu.assertEquals(snapshot.rows[4].invalidCode, "duplicate_devotion_god")
    lu.assertEquals(snapshot.invalidRows[1].rowIndex, 4)
    lu.assertEquals(snapshot.invalidRows[1].code, "duplicate_devotion_god")
end

function TestRunPlannerMultiEncounterRoute.testMultiEncounterRuntimeInvalidatesUnavailableCombatCount()
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
