local lu = require("luaunit")

-- luacheck: globals TestRunPlannerRewards
TestRunPlannerRewards = {}

local function loadCatalog()
    local factory = dofile("src/mods/rewards/catalog.lua")
    local surfaces = dofile("src/mods/rewards/surfaces.lua")
    return factory.create(surfaces)
end

local function loadRuntime()
    local chunk = assert(loadfile("src/mods/rewards/runtime.lua"))
    return chunk({
        catalog = loadCatalog(),
    })
end

local function fakeFields(values)
    return {
        read = function(_, alias)
            return values[alias]
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
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxManaDrop",
        "RoomMoneyDrop",
        "StackUpgrade",
        "TalentDrop",
    })
    lu.assertEquals(surface.controls[1].genericRewardLabelHiddenDrawOpts.label, "")
    lu.assertEquals(surface.controls[2].key, "boonSource")
    lu.assertEquals(surface.controls[2].visibleWhen, {
        alias = "Reward1Key",
        value = "Boon",
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
end

function TestRunPlannerRewards.testCatalogUsesMajorMinorSurfaceForShipWheel()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "shipWheel",
        storeSource = "ChooseNextRewardStore",
        defaultRewardStore = "RunProgress",
    })

    lu.assertEquals(surface.kind, "majorMinor")
    lu.assertEquals(surface.majorRewardStore, "RunProgress")
    lu.assertEquals(surface.minorRewardStore, "MetaProgress")
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
        "WeaponUpgrade",
        "MaxHealthDrop",
        "MaxManaDrop",
        "StackUpgrade",
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
    lu.assertEquals(controlByKey(surface, "Boon").values, {
        "",
        "RandomLoot",
        "BlindBoxLoot",
        "ShopHermesUpgrade",
    })
    lu.assertEquals(controlByKey(surface, "Boon").displayValues.RandomLoot, "Boon")
    lu.assertEquals(controlByKey(surface, "Boon").displayValues.BlindBoxLoot, "Mystery Boon")
    lu.assertEquals(controlByKey(surface, "Boon").displayValues.ShopHermesUpgrade, "Hermes")
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
end

function TestRunPlannerRewards.testCatalogNormalizesCuratedShopSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "shop",
        shopProfile = "Q_WorldShop",
    })

    lu.assertEquals(surface.kind, "shop")
    lu.assertEquals(#surface.controls, 10)
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
