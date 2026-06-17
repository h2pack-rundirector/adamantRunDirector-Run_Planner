local lu = require("luaunit")

-- luacheck: globals TestRunPlannerRewards
TestRunPlannerRewards = {}

local function loadCatalog()
    local factory = dofile("src/mods/rewards/catalog.lua")
    local surfaces = dofile("src/mods/rewards/surfaces.lua")
    return factory.create(surfaces)
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
    lu.assertEquals(surface.controls[2].key, "boonSource")
    lu.assertEquals(surface.controls[2].visibleWhen, {
        alias = "Reward1Key",
        value = "Boon",
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
    lu.assertEquals(surface.controls[1].alias, "Reward1Key")
    lu.assertEquals(surface.controls[1].values[1], "")
    lu.assertEquals(surface.controls[1].values[2], "AphroditeUpgrade")
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

function TestRunPlannerRewards.testCatalogNormalizesCuratedShopSurface()
    local catalog = loadCatalog()
    local surface = catalog:surfaceFor({
        kind = "shop",
        shopProfile = "Q_WorldShop",
    })

    lu.assertEquals(surface.kind, "shop")
    lu.assertEquals(#surface.controls, 6)
    lu.assertEquals(surface.controls[1].key, "Group1Offer1")
    lu.assertEquals(surface.controls[1].values, {
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
    lu.assertEquals(surface.controls[2].key, "Group1Offer2")
    lu.assertEquals(surface.controls[2].values, surface.controls[1].values)
    lu.assertEquals(surface.controls[6].key, "Group5Offer1")
    lu.assertEquals(surface.controls[6].values, {
        "",
        "MetaCardPointsCommonDrop",
        "MetaCurrencyDrop",
        "GiftDrop",
    })
end
