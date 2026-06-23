local lu = require("luaunit")

-- luacheck: globals TestRunPlannerRewards
TestRunPlannerRewards = {}

local function testImport(path, _, deps)
    local chunk = assert(loadfile("src/" .. path))
    return chunk(deps)
end

local function loadCatalogFactory()
    local previousImport = _G.import
    _G.import = testImport
    local ok, factory = pcall(testImport, "mods/rewards/surfaces/registry.lua")
    _G.import = previousImport
    if not ok then
        error(factory, 0)
    end
    return factory
end

local function loadCatalog()
    local factory = loadCatalogFactory()
    local definitions = dofile("src/mods/rewards/declarations/definitions.lua")
    return factory.create(definitions)
end

local function loadCatalogWith(definitions)
    local factory = loadCatalogFactory()
    return factory.create(definitions)
end

local function loadValueStates()
    return dofile("src/mods/route/value_states.lua")
end

local function loadRoutePosition()
    return dofile("src/mods/route/position.lua")
end

local function loadDecorations()
    local chunk = assert(loadfile("src/mods/ui/decorations.lua"))
    return chunk({
        valueStates = loadValueStates(),
        routePosition = loadRoutePosition(),
    })
end

local function loadRuntime()
    local chunk = assert(loadfile("src/mods/rewards/runtime.lua"))
    return chunk({
        catalog = loadCatalog(),
        valueStates = loadValueStates(),
    })
end

local function loadUi()
    local runtime = loadRuntime()
    local decorations = loadDecorations()
    local chunk = assert(loadfile("src/mods/rewards/ui.lua"))
    return chunk({
        runtime = runtime,
        decorations = decorations,
    }), runtime
end

local function loadConditions()
    return dofile("src/mods/rewards/declarations/conditions.lua")
end

local function loadSemantics()
    return dofile("src/mods/route/reward_planning/semantics.lua")
end

local function qSummitShopContext()
    return {
        kind = "shop",
        shopProfile = "Q_WorldShop",
    }
end

local function fakeFields(values)
    return {
        read = function(_, alias)
            return values[alias]
        end,
    }
end

local function drawableFields(values)
    return {
        read = function(_, alias)
            return values[alias]
        end,
        get = function(_, alias)
            return {
                alias = alias,
                read = function()
                    return values[alias]
                end,
            }
        end,
    }
end

local function controlByKey(surface, key)
    for _, control in ipairs(surface.controls or {}) do
        if control.key == key then
            return control
        end
    end
    return nil
end

local function ruleByTarget(rules, target)
    for _, rule in ipairs(rules or {}) do
        for _, value in ipairs(rule.targets or {}) do
            if value == target then
                return rule
            end
        end
    end
    return nil
end

local function ruleByRequirementCode(rules, code)
    for _, rule in ipairs(rules or {}) do
        for _, requirement in ipairs(rule.requirements or {}) do
            if requirement.code == code then
                return rule
            end
        end
    end
    return nil
end

function TestRunPlannerRewards.testDropdownValueDecoratorMapsSemanticStates()
    local valueStates = loadValueStates()
    local decorations = loadDecorations()
    local owner = {}
    local baseOpts = {
        values = { "A", "B", "C", "D" },
        valueColors = {
            A = { 0.1, 0.2, 0.3, 1.0 },
        },
        visibleValues = {
            D = true,
        },
    }

    local decorated = decorations.decorateDropdown(owner, baseOpts, {
        A = valueStates.NORMAL,
        B = valueStates.HIDDEN,
        C = valueStates.INVALID,
        D = valueStates.WARNING,
    })

    lu.assertNotIs(decorated, baseOpts)
    lu.assertIs(decorated.values, baseOpts.values)
    lu.assertEquals(decorated.visibleValues.B, false)
    lu.assertEquals(decorated.visibleValues.D, true)
    lu.assertEquals(decorated.valueColors.A, { 0.1, 0.2, 0.3, 1.0 })
    lu.assertEquals(decorated.valueColors.C, { 1.0, 0.22, 0.16, 1.0 })
    lu.assertEquals(decorated.valueColors.D, { 1.0, 0.78, 0.18, 1.0 })
end

function TestRunPlannerRewards.testSemanticsDecodeRewardTypesAndSources()
    local semantics = loadSemantics()

    lu.assertEquals(semantics.rewardType({
        rewardKind = "boonSource",
        rewards = { "ZeusUpgrade" },
    }), "Boon")
    lu.assertEquals(semantics.boonSource({
        rewardKind = "boonSource",
        rewards = { "ZeusUpgrade" },
    }), "ZeusUpgrade")

    lu.assertEquals(semantics.rewardType({
        rewardKind = "majorMinor",
        rewards = { "Major", "Boon", "HeraUpgrade" },
        rewardPicks = {
            { key = "rewardType", value = "Boon" },
            { key = "boonSource", value = "AphroditeUpgrade" },
        },
    }), "Boon")
    lu.assertEquals(semantics.boonSource({
        rewardKind = "majorMinor",
        rewards = { "Major", "Boon", "HeraUpgrade" },
        rewardPicks = {
            { key = "boonSource", value = "AphroditeUpgrade" },
        },
    }), "AphroditeUpgrade")

end

function TestRunPlannerRewards.testSemanticsCollectGodLootSources()
    local semantics = loadSemantics()
    local sources = {}

    lu.assertEquals(semantics.godLootSources({
        rewardKind = "devotionPair",
        rewards = { "ApolloUpgrade", "HestiaUpgrade" },
    }, sources), {
        "ApolloUpgrade",
        "HestiaUpgrade",
    })

    lu.assertEquals(semantics.godLootSources({
        rewardKind = "shop",
        rewards = { "RandomLoot", "BlindBoxLoot", "BoostedRandomLoot" },
        rewardLoot = { "ZeusUpgrade", "HeraUpgrade", "PoseidonUpgrade" },
    }, sources), {
        "ZeusUpgrade",
        "PoseidonUpgrade",
    })
end

function TestRunPlannerRewards.testSemanticsExposeRewardEvents()
    local semantics = loadSemantics()
    local row = {
        rowIndex = 3,
        rewardItems = {
            {
                address = "row",
                rewardKind = "shop",
                rewards = { "RandomLoot", "WeaponUpgradeDrop" },
                rewardLoot = { "DemeterUpgrade", "" },
            },
        },
    }
    local rewardItems = {
        collect = function()
            return row.rewardItems
        end,
    }

    local events = semantics.eventsForRow(row, rewardItems, {})

    lu.assertEquals(#events, 2)
    lu.assertEquals(events[1].rewardType, "RandomLoot")
    lu.assertEquals(events[1].address, "shop:1")
    lu.assertEquals(events[1].boonSource, "DemeterUpgrade")
    lu.assertEquals(events[2].rewardType, "WeaponUpgradeDrop")
    lu.assertEquals(events[2].address, "shop:2")
end

function TestRunPlannerRewards.testSemanticsExposeFieldsCageRewardEvents()
    local semantics = loadSemantics()
    local row = {
        rowIndex = 2,
        rewardItems = {
            {
                address = "row",
                rewardKind = "fieldsCages",
                rewardSourceCount = 3,
                rewards = { "Boon", "HermesUpgrade", "StackUpgrade" },
                rewardLoot = { "ZeusUpgrade", "", "" },
            },
        },
    }
    local rewardItems = {
        collect = function()
            return row.rewardItems
        end,
    }

    local events = semantics.eventsForRow(row, rewardItems, {})

    lu.assertEquals(#events, 3)
    lu.assertEquals(events[1].rewardType, "Boon")
    lu.assertEquals(events[1].address, "cage:1")
    lu.assertEquals(events[1].addressLabel, "Cage 1 Reward")
    lu.assertEquals(events[1].boonSource, "ZeusUpgrade")
    lu.assertEquals(events[2].rewardType, "HermesUpgrade")
    lu.assertEquals(events[2].address, "cage:2")
    lu.assertEquals(events[3].rewardType, "StackUpgrade")
    lu.assertEquals(events[3].address, "cage:3")
end

function TestRunPlannerRewards.testSemanticsExposeCandidateRewardEvents()
    local semantics = loadSemantics()
    local row = {
        rowIndex = 4,
    }

    local devotionEvent = semantics.candidateEventForControl(row, {
        address = "row",
        sourceLabel = "Rewards",
        rewardKind = "majorMinor",
        rewards = { "Major", "", "", "", "ZeusUpgrade", "ApolloUpgrade" },
        rewardPicks = {
            { key = "lootAName", value = "HeraUpgrade" },
            { key = "lootBName", value = "HestiaUpgrade" },
        },
    }, {
        kind = "rewardType",
        rowIndex = 1,
    }, "Devotion", "row")

    lu.assertNotNil(devotionEvent)
    lu.assertEquals(devotionEvent.rewardType, "Devotion")
    lu.assertEquals(devotionEvent.address, "row")
    lu.assertEquals(devotionEvent.addressLabel, "Rewards")
    lu.assertEquals(devotionEvent.devotionSourceA, "HeraUpgrade")
    lu.assertEquals(devotionEvent.devotionSourceB, "HestiaUpgrade")

    local shopEvent = semantics.candidateEventForControl(row, {
        address = "row",
        rewardKind = "shop",
        rewards = { "" },
        rewardLoot = { "DemeterUpgrade" },
    }, {
        kind = "shopOption",
        rowIndex = 1,
    }, "RandomLoot", "row")

    lu.assertNotNil(shopEvent)
    lu.assertEquals(shopEvent.rewardType, "RandomLoot")
    lu.assertEquals(shopEvent.address, "shop:1")
    lu.assertEquals(shopEvent.addressLabel, "Shop Offer 1")
    lu.assertEquals(shopEvent.boonSource, "DemeterUpgrade")

    local cageEvent = semantics.candidateEventForControl(row, {
        address = "row",
        rewardKind = "fieldsCages",
        rewardSourceCount = 2,
        rewards = { "", "" },
        rewardLoot = { "ZeusUpgrade", "PoseidonUpgrade" },
    }, {
        kind = "rewardType",
        sourceIndex = 2,
    }, "Boon", "row")

    lu.assertNotNil(cageEvent)
    lu.assertEquals(cageEvent.rewardType, "Boon")
    lu.assertEquals(cageEvent.address, "cage:2")
    lu.assertEquals(cageEvent.addressLabel, "Cage 2 Reward")
    lu.assertEquals(cageEvent.boonSource, "PoseidonUpgrade")
end

function TestRunPlannerRewards.testSemanticsConcreteAndBannedChecks()
    local semantics = loadSemantics()

    lu.assertFalse(semantics.isConcrete({
        rewardKind = "majorMinor",
        rewards = { "Major", "" },
    }))
    lu.assertTrue(semantics.isConcrete({
        rewardKind = "majorMinor",
        rewards = { "Major", "Boon", "ZeusUpgrade" },
    }))
    lu.assertTrue(semantics.hasBannedValue({
        rewardKind = "boonSource",
        rewards = { "ZeusUpgrade" },
    }, {
        Boon = true,
    }))
    lu.assertTrue(semantics.hasBannedValue({
        rewardKind = "roomStore",
        rewards = { "SpellDrop" },
    }, {
        SpellDrop = true,
    }))
end

function TestRunPlannerRewards.testConditionsGroupTalentVariantsBehindSpellRequirement()
    local rules = loadConditions()
    local talentRule = ruleByRequirementCode(rules, "talent_requires_spell")

    lu.assertNotNil(talentRule)
    lu.assertEquals(talentRule.targets, {
        "TalentDrop",
        "MinorTalentDrop",
        "TalentBigDrop",
    })
    lu.assertEquals(talentRule.requirements[1], {
        kind = "minPriorCount",
        counter = "spell",
        scope = "route",
        min = 1,
        code = "talent_requires_spell",
        message = "Path of Stars rewards require an earlier Selene's Gift",
    })
end

function TestRunPlannerRewards.testConditionsApplyDevotionByRewardTypeWithThessalyExitException()
    local rules = loadConditions()
    local devotionRule = ruleByTarget(rules, "Devotion")

    lu.assertNotNil(devotionRule)
    lu.assertNil(devotionRule.appliesToRewardKinds)
    lu.assertEquals(devotionRule.requirements[3], {
        kind = "previousRoomExitCount",
        minCount = 2,
        exceptBiomes = {
            "O",
        },
        code = "previous_room_exit_count",
        message = "Previous planned room must have at least 2 exits",
    })
end

function TestRunPlannerRewards.testConditionsBlockTalentAfterShopTalent()
    local rules = loadConditions()
    local blockerRule = ruleByRequirementCode(rules, "talent_shop_conflict")

    lu.assertNotNil(blockerRule)
    lu.assertEquals(blockerRule.targets, {
        "TalentDrop",
        "MinorTalentDrop",
        "TalentBigDrop",
    })
    lu.assertEquals(blockerRule.requirements[1], {
        kind = "pendingOfferExclusion",
        rewards = {
            "TalentDrop",
        },
        code = "talent_shop_conflict",
        message = "Path of Stars cannot be planned after a shop Path of Stars offer",
        relatedParticipants = {
            {
                kind = "event",
                source = "pendingOffer",
                select = "last",
            },
        },
    })
end

function TestRunPlannerRewards.testConditionsBlockRoomHammerAfterShopHammer()
    local rules = loadConditions()
    local hammerRule = ruleByTarget(rules, "WeaponUpgrade")
    local blockerRule = ruleByRequirementCode(rules, "weapon_upgrade_shop_conflict")

    lu.assertNotNil(hammerRule)
    lu.assertNotNil(blockerRule)
    lu.assertEquals(blockerRule.targets, { "WeaponUpgrade" })
    lu.assertEquals(blockerRule.requirements[1], {
        kind = "pendingOfferExclusion",
        rewards = {
            "WeaponUpgradeDrop",
        },
        code = "weapon_upgrade_shop_conflict",
        message = "Hammer cannot be planned after a shop Hammer offer",
        relatedParticipants = {
            {
                kind = "event",
                source = "pendingOffer",
                select = "last",
            },
        },
    })
end

function TestRunPlannerRewards.testCatalogNormalizesCuratedRunProgressSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "RunProgress",
    })

    lu.assertEquals(surface.kind, "roomStore")
    lu.assertEquals(surface.controls[1].key, "rewardType")
    lu.assertEquals(surface.controls[1].values, {
        "",
        "Boon",
        "HermesUpgrade",
        "Devotion",
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxManaDrop",
        "RoomMoneyDrop",
        "StackUpgrade",
        "SpellDrop",
        "TalentDrop",
    })
    lu.assertEquals(surface.controls[1].displayValues.WeaponUpgrade, "Hammer")
    lu.assertEquals(surface.controls[1].displayValues.MaxHealthDrop, "Max Health")
    lu.assertEquals(surface.controls[1].displayValues.MaxManaDrop, "Max Magick")
    lu.assertEquals(surface.controls[1].displayValues.RoomMoneyDrop, "Gold")
    lu.assertEquals(surface.controls[1].displayValues.TalentDrop, "Path of Stars")
    lu.assertEquals(surface.controls[1].genericRewardLabelHiddenDrawOpts.label, "")
    lu.assertEquals(surface.controls[2].key, "boonSource")
    lu.assertEquals(surface.controls[2].visibleWhen, {
        alias = "Reward1Key",
        value = "Boon",
    })
    lu.assertEquals(surface.controls[3].key, "lootAName")
    lu.assertEquals(surface.controls[3].visibleWhen, {
        alias = "Reward1Key",
        value = "Devotion",
    })
    lu.assertEquals(surface.controls[4].key, "lootBName")
end

function TestRunPlannerRewards.testCatalogNormalizesSpecializedRewardBundles()
    local catalog = loadCatalog()

    local opening = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "OpeningRunProgress",
    })
    lu.assertEquals(opening.controls[1].values, {
        "",
        "Boon",
        "HermesUpgrade",
        "WeaponUpgrade",
        "StackUpgrade",
        "SpellDrop",
    })

    local preboss = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "PreBossRunProgress",
    })
    lu.assertEquals(preboss.controls[1].values, {
        "",
        "Boon",
        "HermesUpgrade",
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxManaDrop",
        "StackUpgrade",
        "SpellDrop",
        "TalentDrop",
    })

    local easyHub = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "EasyHubRewards",
    })
    lu.assertEquals(easyHub.controls[1].values, {
        "",
        "Boon",
        "MaxHealthDropBig",
        "MaxManaDropBig",
        "SpellDrop",
    })

    local clockwork = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "ClockworkExtensionRewards",
    })
    lu.assertEquals(clockwork.controls[1].values, {
        "",
        "WeaponUpgrade",
        "Devotion",
        "StackUpgradeTriple",
        "TalentBigDrop",
        "RoomMoneyTripleDrop",
    })
end

function TestRunPlannerRewards.testCatalogNormalizesFieldsCageSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "fieldsCages",
        rewardStore = "RunProgress",
    })

    lu.assertEquals(surface.kind, "roomStore")
    lu.assertEquals(surface.rewardStore, "RunProgress")
    lu.assertEquals(surface.controls[1].key, "rewardType")
    lu.assertEquals(surface.controls[1].values[2], "Boon")
    lu.assertEquals(surface.controls[2].key, "boonSource")

    local composite = catalog:surfaceFor({
        kind = "fieldsCages",
        rewardStore = "RunProgress",
        sourceCount = 3,
    })
    lu.assertEquals(composite.kind, "fieldsCages")
    lu.assertEquals(composite.sourceCount, 3)
    lu.assertEquals(#composite.controls, 6)
    lu.assertEquals(composite.controls[1].key, "Cage1")
    lu.assertEquals(composite.controls[1].alias, "Reward1Key")
    lu.assertEquals(composite.controls[1].sourceIndex, 1)
    lu.assertEquals(composite.controls[2].key, "Cage1Loot")
    lu.assertEquals(composite.controls[2].alias, "Reward1LootKey")
    lu.assertEquals(composite.controls[3].key, "Cage2")
    lu.assertEquals(composite.controls[5].key, "Cage3")
    lu.assertEquals(composite.rewardConstraints[1].kind, "uniqueRewardTypes")
    lu.assertEquals(composite.rewardConstraints[1].sourceIndices, {
        1,
        2,
        3,
    })
    lu.assertEquals(composite.rewardConstraints[1].allow, {
        Boon = true,
    })
    lu.assertEquals(composite.rewardConstraints[2].kind, "uniqueBoonSource")
    lu.assertEquals(composite.rewardConstraints[2].code, "duplicate_boon_source")
end

function TestRunPlannerRewards.testCatalogNormalizesMajorMinorSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "majorMinor",
        majorRewardStore = "RunProgress",
        minorRewardStore = "MetaProgress",
    })

    lu.assertEquals(surface.kind, "majorMinor")
    lu.assertEquals(surface.controls[1].key, "rewardClass")
    lu.assertEquals(surface.controls[1].values, {
        "",
        "Major",
        "Minor",
    })
    lu.assertEquals(surface.controls[1].displayValues.Major, "Major")
    lu.assertEquals(surface.controls[1].displayValues.Minor, "Minor")
    lu.assertEquals(surface.controls[1].genericRewardLabelHiddenDrawOpts.label, "")
    lu.assertEquals(surface.controls[2].key, "rewardType")
    lu.assertEquals(surface.controls[2].rewardStore, "RunProgress")
    lu.assertEquals(surface.controls[2].visibleWhen, {
        alias = "Reward1Key",
        value = "Major",
    })
    lu.assertEquals(surface.controls[2].values, {
        "",
        "Boon",
        "HermesUpgrade",
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxManaDrop",
        "RoomMoneyDrop",
        "StackUpgrade",
        "SpellDrop",
        "TalentDrop",
    })
    lu.assertEquals(surface.controls[3].key, "boonSource")
    lu.assertEquals(surface.controls[3].visibleWhen, {
        all = {
            {
                alias = "Reward1Key",
                value = "Major",
            },
            {
                alias = "Reward2Key",
                value = "Boon",
            },
        },
    })
    lu.assertEquals(surface.controls[4].key, "rewardType")
    lu.assertEquals(surface.controls[4].rewardStore, "MetaProgress")
    lu.assertEquals(surface.controls[4].visibleWhen, {
        alias = "Reward1Key",
        value = "Minor",
    })
    lu.assertEquals(surface.controls[4].values, {
        "",
        "GiftDrop",
        "MetaCurrencyDrop",
        "MetaCurrencyBigDrop",
        "MetaCardPointsCommonDrop",
        "MetaCardPointsCommonBigDrop",
    })
    lu.assertEquals(surface.controls[4].displayValues.GiftDrop, "Nectar")
    lu.assertEquals(surface.controls[4].displayValues.MetaCurrencyBigDrop, "Big Bones")
    lu.assertEquals(surface.controls[4].displayValues.MetaCardPointsCommonBigDrop, "Big Ashes")
end

function TestRunPlannerRewards.testCatalogOptInDevotionForMajorMinorSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "majorMinor",
        majorRewardStore = "RunProgress",
        minorRewardStore = "MetaProgress",
        allowDevotion = true,
    })

    lu.assertEquals(surface.controls[2].values, {
        "",
        "Boon",
        "HermesUpgrade",
        "Devotion",
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxManaDrop",
        "RoomMoneyDrop",
        "StackUpgrade",
        "SpellDrop",
        "TalentDrop",
    })
    lu.assertEquals(surface.controls[5].key, "lootAName")
    lu.assertEquals(surface.controls[5].visibleWhen, {
        all = {
            { alias = "Reward1Key", value = "Major" },
            { alias = "Reward2Key", value = "Devotion" },
        },
    })
    lu.assertEquals(surface.controls[6].key, "lootBName")
    lu.assertEquals(surface.rewardConstraints[1], {
        kind = "uniqueBoonSource",
        code = "duplicate_devotion_god",
        message = "Trial gods must be different",
    })
end

function TestRunPlannerRewards.testCatalogUsesBundleLabelsForMajorMinorCategories()
    local catalog = loadCatalogWith({
        godLoot = {},
        primitives = {},
        bundles = {
            MajorBundle = {
                label = "Primary",
                options = {},
            },
            MinorBundle = {
                label = "Secondary",
                options = {},
            },
        },
        shops = {},
    })
    local surface = catalog:surfaceFor({
        kind = "majorMinor",
        majorRewardStore = "MajorBundle",
        minorRewardStore = "MinorBundle",
    })

    lu.assertEquals(surface.controls[1].displayValues.Major, "Primary")
    lu.assertEquals(surface.controls[1].displayValues.Minor, "Secondary")
end

function TestRunPlannerRewards.testCatalogSplitsDevotionPairAcrossRows()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "forcedReward",
        rewardType = "Devotion",
    })

    lu.assertEquals(surface.kind, "devotionPair")
    lu.assertEquals(surface.fixedRewardType, "Devotion")
    lu.assertEquals(surface.controls[1].key, "lootAName")
    lu.assertEquals(surface.controls[1].label, "God A")
    lu.assertEquals(surface.controls[1].rowIndex, 1)
    lu.assertEquals(surface.controls[2].key, "lootBName")
    lu.assertEquals(surface.controls[2].label, "God B")
    lu.assertEquals(surface.controls[2].rowIndex, 2)
    lu.assertEquals(surface.rewardConstraints[1], {
        kind = "uniqueBoonSource",
        code = "duplicate_devotion_god",
        message = "Trial gods must be different",
    })
end

function TestRunPlannerRewards.testCatalogNormalizesBoonOnlySurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "RunProgress",
        eligibleRewardTypes = { "Boon" },
    })

    lu.assertEquals(surface.kind, "boonSource")
    lu.assertEquals(surface.fixedRewardType, "Boon")
    lu.assertEquals(#surface.controls, 1)
    lu.assertEquals(surface.controls[1].key, "boonSource")
    lu.assertEquals(surface.controls[1].label, "")
    lu.assertEquals(surface.controls[1].alias, "Reward1Key")
    lu.assertEquals(surface.controls[1].values[1], "")
    lu.assertEquals(surface.controls[1].values[2], "AphroditeUpgrade")
    lu.assertEquals(surface.controls[1].displayValues.AphroditeUpgrade, "Aphrodite")
end

function TestRunPlannerRewards.testCatalogLeavesDevotionGodLabelsIntact()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "forcedReward",
        rewardType = "Devotion",
    })

    lu.assertEquals(surface.controls[1].label, "God A")
    lu.assertEquals(surface.controls[2].label, "God B")
end

function TestRunPlannerRewards.testCatalogNormalizesEphyraSubRoomRewardSurfaces()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "SubRoomRewards",
    })

    lu.assertEquals(surface.kind, "roomStore")
    lu.assertEquals(surface.controls[1].values, {
        "",
        "MaxManaDropSmall",
        "MaxHealthDropSmall",
        "EmptyMaxHealthSmallDrop",
        "RoomMoneyTinyDrop",
        "AirBoost",
        "EarthBoost",
        "FireBoost",
        "WaterBoost",
        "GiftDrop",
        "MetaCurrencyDrop",
        "MetaCardPointsCommonDrop",
        "MaxHealthDrop",
        "MaxManaDrop",
        "StackUpgrade",
        "RoomMoneyDrop",
        "MinorTalentDrop",
    })

    local hardSurface = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "SubRoomRewardsHard",
    })
    lu.assertEquals(hardSurface.kind, "roomStore")
    lu.assertEquals(hardSurface.controls[1].values, {
        "",
        "MaxHealthDrop",
        "MaxManaDrop",
        "StackUpgrade",
        "RoomMoneyDrop",
    })
    lu.assertEquals(surface.controls[1].displayValues.EmptyMaxHealthSmallDrop, "Empty Max Health")
    lu.assertEquals(surface.controls[1].displayValues.MinorTalentDrop, "Tiny Path")
end

function TestRunPlannerRewards.testRuntimeSnapshotsMajorMinorVisiblePicks()
    local runtime = loadRuntime()
    local surface = runtime.surfaceFor({
        kind = "majorMinor",
        majorRewardStore = "RunProgress",
        minorRewardStore = "MetaProgress",
    })

    lu.assertEquals(runtime.snapshot(surface, fakeFields({
        Reward1Key = "Major",
        Reward2Key = "Boon",
        Reward3Key = "ZeusUpgrade",
        Reward4Key = "GiftDrop",
    })), {
        {
            key = "rewardClass",
            kind = "rewardClass",
            alias = "Reward1Key",
            value = "Major",
        },
        {
            key = "rewardType",
            kind = "rewardType",
            alias = "Reward2Key",
            value = "Boon",
            rewardStore = "RunProgress",
        },
        {
            key = "boonSource",
            kind = "boonSource",
            alias = "Reward3Key",
            value = "ZeusUpgrade",
        },
    })

    lu.assertEquals(runtime.snapshot(surface, fakeFields({
        Reward1Key = "Minor",
        Reward2Key = "Boon",
        Reward3Key = "ZeusUpgrade",
        Reward4Key = "GiftDrop",
    })), {
        {
            key = "rewardClass",
            kind = "rewardClass",
            alias = "Reward1Key",
            value = "Minor",
        },
        {
            key = "rewardType",
            kind = "rewardType",
            alias = "Reward4Key",
            value = "GiftDrop",
            rewardStore = "MetaProgress",
        },
    })
end

function TestRunPlannerRewards.testRuntimeSnapshotsShopBoonSourcePicks()
    local runtime = loadRuntime()
    local surface = runtime.surfaceFor({
        kind = "shop",
        shopProfile = "WorldShop",
    })

    lu.assertEquals(runtime.snapshot(surface, fakeFields({
        Reward1Key = "RandomLoot",
        Reward1LootKey = "ZeusUpgrade",
    })), {
        {
            key = "Boon",
            kind = "shopOption",
            alias = "Reward1Key",
            value = "RandomLoot",
        },
        {
            key = "BoonLoot",
            kind = "boonSource",
            alias = "Reward1LootKey",
            value = "ZeusUpgrade",
        },
    })

    lu.assertEquals(runtime.snapshot(surface, fakeFields({
        Reward1Key = "BlindBoxLoot",
        Reward1LootKey = "ZeusUpgrade",
    })), {
        {
            key = "Boon",
            kind = "shopOption",
            alias = "Reward1Key",
            value = "BlindBoxLoot",
        },
    })
end

function TestRunPlannerRewards.testCatalogDeclaresLinkedShopOfferConstraints()
    local runtime = loadRuntime()
    local surface = runtime.surfaceFor(qSummitShopContext())

    lu.assertEquals(surface.rewardConstraints[1], {
        kind = "uniqueRewardTypes",
        sourceIndices = {
            1,
            2,
        },
        code = "duplicate_shop_group_option",
        message = "Offers 1 and 2 share one vanilla shop group and cannot duplicate the same reward",
    })
end

function TestRunPlannerRewards.testUiPassesRewardContextToExternalValueStates()
    local ui, runtime = loadUi()
    local surface = runtime.surfaceFor({
        kind = "roomStore",
        rewardStore = "RunProgress",
    })
    local rewardContext = {
        rowIndex = 2,
        address = "row",
    }
    local fields = drawableFields({
        Reward1Key = "Boon",
    })
    fields.rewardContext = rewardContext
    local seenByAlias = {}
    local captured = {}
    local draw = {
        imgui = {
            GetCursorPosX = function()
                return 0
            end,
            AlignTextToFramePadding = function() end,
            Text = function() end,
            SameLine = function() end,
            SetCursorPosX = function() end,
        },
        widgets = {
            dropdown = function(field, opts)
                captured[field.alias] = opts
                return false
            end,
        },
    }

    ui.draw(draw, surface, fields, {
        valueStatesForControl = function(control, callbackFields, callbackContext)
            seenByAlias[control.alias] = {
                control = control,
                fields = callbackFields,
                context = callbackContext,
            }
            return {
                Boon = 2,
            }
        end,
    })

    local seen = seenByAlias.Reward1Key
    lu.assertEquals(seen.control.alias, "Reward1Key")
    lu.assertIs(seen.fields, fields)
    lu.assertIs(seen.context, rewardContext)
    lu.assertEquals(captured.Reward1Key.valueColors.Boon, { 1.0, 0.22, 0.16, 1.0 })
end

function TestRunPlannerRewards.testUiInvalidatesImmediatelyAfterRewardControlChanges()
    local ui, runtime = loadUi()
    local surface = runtime.surfaceFor(qSummitShopContext())
    local invalidated = false
    local secondControlSawInvalidation = false
    local draw = {
        imgui = {
            GetCursorPosX = function()
                return 0
            end,
            AlignTextToFramePadding = function() end,
            Text = function() end,
            SameLine = function() end,
            SetCursorPosX = function() end,
        },
        widgets = {
            dropdown = function(field)
                return field.alias == "Reward1Key"
            end,
        },
    }

    ui.draw(draw, surface, drawableFields({
        Reward1Key = "MaxHealthDropBig",
        Reward2Key = "MaxManaDropBig",
    }), {
        onControlChanged = function()
            invalidated = true
        end,
        valueStatesForControl = function(control)
            if control.alias == "Reward2Key" then
                secondControlSawInvalidation = invalidated
            end
            return nil
        end,
    })

    lu.assertTrue(invalidated)
    lu.assertTrue(secondControlSawInvalidation)
end

function TestRunPlannerRewards.testCatalogAppliesIneligibleRewardTypes()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "RunProgress",
        ineligibleRewardTypes = { "RoomMoneyDrop" },
    })

    lu.assertEquals(surface.kind, "roomStore")
    lu.assertEquals(surface.controls[1].values, {
        "",
        "Boon",
        "HermesUpgrade",
        "Devotion",
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxManaDrop",
        "StackUpgrade",
        "SpellDrop",
        "TalentDrop",
    })
end

function TestRunPlannerRewards.testCatalogComposesEligibleAndIneligibleRewardTypes()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "roomStore",
        rewardStore = "RunProgress",
        eligibleRewardTypes = { "Boon", "HermesUpgrade", "RoomMoneyDrop" },
        ineligibleRewardTypes = { "RoomMoneyDrop" },
    })

    lu.assertEquals(surface.kind, "roomStore")
    lu.assertEquals(surface.controls[1].values, {
        "",
        "Boon",
        "HermesUpgrade",
    })
end

function TestRunPlannerRewards.testCatalogNormalizesStandardWorldShopSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "shop",
        shopProfile = "WorldShop",
    })

    lu.assertEquals(surface.kind, "shop")
    lu.assertEquals(#surface.controls, 4)
    lu.assertEquals(controlByKey(surface, "Boon").label, "Offer 1")
    lu.assertEquals(controlByKey(surface, "MajorNonBoon").label, "Offer 2")
    lu.assertEquals(controlByKey(surface, "Minor").label, "Offer 3")
    lu.assertEquals(controlByKey(surface, "Boon").values, {
        "",
        "RandomLoot",
        "BlindBoxLoot",
        "ShopHermesUpgrade",
    })
    lu.assertEquals(controlByKey(surface, "Boon").displayValues.RandomLoot, "Boon")
    lu.assertEquals(controlByKey(surface, "Boon").displayValues.BlindBoxLoot, "Mystery Boon")
    lu.assertEquals(controlByKey(surface, "Boon").displayValues.ShopHermesUpgrade, "Hermes Boon")
    lu.assertEquals(controlByKey(surface, "Boon").rowIndex, 1)
    lu.assertEquals(controlByKey(surface, "BoonLoot").alias, "Reward1LootKey")
    lu.assertEquals(controlByKey(surface, "BoonLoot").rowIndex, 1)
    lu.assertEquals(controlByKey(surface, "BoonLoot").visibleWhen, {
        any = {
            { alias = "Reward1Key", value = "RandomLoot" },
            { alias = "Reward1Key", value = "BoostedRandomLoot" },
        },
    })
    lu.assertEquals(controlByKey(surface, "BoonLoot").values[1], "")
    lu.assertEquals(controlByKey(surface, "BoonLoot").values[2], "AphroditeUpgrade")
    lu.assertEquals(controlByKey(surface, "Minor").values, {
        "",
        "MaxManaDrop",
        "StackUpgrade",
        "StoreRewardRandomStack",
        "SpellDrop",
        "TalentDrop",
    })
    lu.assertEquals(controlByKey(surface, "Minor").displayValues.StoreRewardRandomStack, "Pom Slice")
    lu.assertEquals(controlByKey(surface, "Minor").displayValues.SpellDrop, "Selene's Gift")
    lu.assertEquals(controlByKey(surface, "MajorNonBoon").rowIndex, 2)
    lu.assertEquals(controlByKey(surface, "Minor").rowIndex, 3)
end

function TestRunPlannerRewards.testCatalogNormalizesTartarusShopSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "shop",
        shopProfile = "I_WorldShop",
    })

    lu.assertEquals(surface.kind, "shop")
    lu.assertEquals(#surface.controls, 8)
    lu.assertEquals(controlByKey(surface, "Group1Offer1").label, "Offer 1")
    lu.assertEquals(controlByKey(surface, "Group2Offer1").label, "Offer 2")
    lu.assertEquals(controlByKey(surface, "Group3Offer1").label, "Offer 3")
    lu.assertEquals(controlByKey(surface, "Group4Offer1").label, "Offer 4")
    lu.assertEquals(controlByKey(surface, "Group5Offer1").label, "Offer 5")
    lu.assertEquals(controlByKey(surface, "Group4Offer1").values, {
        "",
        "WeaponUpgradeDrop",
        "RandomLoot",
        "BlindBoxLoot",
        "ShopHermesUpgrade",
        "ChaosWeaponUpgrade",
        "BoostedRandomLoot",
        "MaxHealthDropBig",
        "MaxManaDropBig",
    })
    lu.assertEquals(controlByKey(surface, "Group4Offer1").displayValues.RandomLoot, "Boon")
    lu.assertEquals(controlByKey(surface, "Group4Offer1").displayValues.BoostedRandomLoot, "Boosted Boon")
    lu.assertEquals(controlByKey(surface, "Group4Offer1").displayValues.WeaponUpgradeDrop, "Hammer")
    lu.assertEquals(controlByKey(surface, "Group4Offer1").displayValues.ChaosWeaponUpgrade, "Anvil")
    lu.assertEquals(controlByKey(surface, "Group4Offer1Loot").alias, "Reward4LootKey")
    lu.assertEquals(controlByKey(surface, "Group4Offer1Loot").visibleWhen, {
        any = {
            { alias = "Reward4Key", value = "RandomLoot" },
            { alias = "Reward4Key", value = "BoostedRandomLoot" },
        },
    })
    lu.assertEquals(controlByKey(surface, "Group5Offer1").values, {
        "",
        "WeaponPointsRareDrop",
        "CardUpgradePointsDrop",
        "CharonPointsDrop",
    })
    lu.assertEquals(controlByKey(surface, "Group5Offer1").displayValues.WeaponPointsRareDrop, "Nightmare")
    lu.assertEquals(controlByKey(surface, "Group5Offer1").displayValues.CardUpgradePointsDrop, "Moon Dust")
    lu.assertEquals(controlByKey(surface, "Group5Offer1").displayValues.CharonPointsDrop, "Obol Points")
end

function TestRunPlannerRewards.testCatalogNormalizesCuratedShopSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "shop",
        shopProfile = "Q_WorldShop",
    })

    lu.assertEquals(surface.kind, "shop")
    lu.assertEquals(#surface.controls, 10)
    lu.assertEquals(controlByKey(surface, "Group1Offer1").label, "Offer 1")
    lu.assertEquals(controlByKey(surface, "Group1Offer2").label, "Offer 2")
    lu.assertEquals(controlByKey(surface, "Group2Offer1").label, "Offer 3")
    lu.assertEquals(controlByKey(surface, "Group3Offer1").label, "Offer 4")
    lu.assertEquals(controlByKey(surface, "Group4Offer1").label, "Offer 5")
    lu.assertEquals(controlByKey(surface, "Group5Offer1").label, "Offer 6")
    lu.assertEquals(controlByKey(surface, "Group1Offer1").values, {
        "",
        "RandomLoot",
        "BlindBoxLoot",
        "StackUpgrade",
        "BoostedRandomLoot",
        "StackUpgradeBig",
        "MaxHealthDrop",
        "MaxManaDrop",
        "TalentDrop",
        "SpellDrop",
    })
    lu.assertEquals(controlByKey(surface, "Group1Offer1").displayValues.RandomLoot, "Boon")
    lu.assertEquals(controlByKey(surface, "Group1Offer1").displayValues.BlindBoxLoot, "Mystery Boon")
    lu.assertEquals(controlByKey(surface, "Group1Offer1").displayValues.BoostedRandomLoot, "Boosted Boon")
    lu.assertEquals(controlByKey(surface, "Group1Offer1Loot").alias, "Reward1LootKey")
    lu.assertEquals(controlByKey(surface, "Group1Offer2").values, controlByKey(surface, "Group1Offer1").values)
    lu.assertEquals(controlByKey(surface, "Group1Offer2Loot").alias, "Reward2LootKey")
    lu.assertEquals(controlByKey(surface, "Group4Offer1").values, {
        "",
        "WeaponUpgradeDrop",
        "RandomLoot",
        "ShopHermesUpgrade",
        "ChaosWeaponUpgrade",
        "BoostedRandomLoot",
        "MaxHealthDropBig",
        "MaxManaDropBig",
    })
    lu.assertEquals(controlByKey(surface, "Group4Offer1Loot").alias, "Reward5LootKey")
    lu.assertEquals(controlByKey(surface, "Group5Offer1").values, {
        "",
        "WeaponPointsRareDrop",
        "CardUpgradePointsDrop",
        "CharonPointsDrop",
    })
end
