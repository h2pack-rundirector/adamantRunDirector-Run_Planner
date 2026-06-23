local lu = require("luaunit")

-- luacheck: globals TestRunPlannerData
TestRunPlannerData = {}

local function testImport(path)
    return dofile("src/" .. path)
end

local GOD_LOOT_NAMES = {
    "AphroditeUpgrade",
    "ApolloUpgrade",
    "AresUpgrade",
    "DemeterUpgrade",
    "HephaestusUpgrade",
    "HestiaUpgrade",
    "HeraUpgrade",
    "PoseidonUpgrade",
    "ZeusUpgrade",
}

local function noneReward()
    return { kind = "none" }
end

local function roomStoreReward(rewardStore, opts)
    opts = opts or {}
    local reward = {
        kind = "roomStore",
        rewardStore = rewardStore,
    }
    if opts.eligibleRewardTypes ~= nil then
        reward.eligibleRewardTypes = opts.eligibleRewardTypes
    end
    if opts.ineligibleRewardTypes ~= nil then
        reward.ineligibleRewardTypes = opts.ineligibleRewardTypes
    end
    return reward
end

local function majorMinorReward(opts)
    opts = opts or {}
    local reward = {
        kind = "majorMinor",
        majorRewardStore = "RunProgress",
        minorRewardStore = "MetaProgress",
    }
    if opts.allowDevotion == true then
        reward.allowDevotion = true
    end
    return reward
end

local function forcedReward(rewardType, opts)
    opts = opts or {}
    local reward = {
        kind = "forcedReward",
        rewardType = rewardType,
    }
    if opts.rewardStore ~= nil then
        reward.rewardStore = opts.rewardStore
    end
    return reward
end

local function boonSourcePick()
    return {
        kind = "boonSource",
        allowedLootNames = GOD_LOOT_NAMES,
    }
end

local function previousExitCountRequirement()
    return {
        kind = "previousRoomExitCount",
        minCount = 2,
    }
end

local function midshopRequirements()
    return {
        previousExitCountRequirement(),
    }
end

local function oneShotRouteRules()
    return {
        maxSelectionsPerBiome = 1,
    }
end

local function maxSelectionRouteRules(count)
    return {
        maxSelectionsPerBiome = count,
    }
end

local function assertOneShotRole(role)
    lu.assertEquals(role.routeRules, oneShotRouteRules())
end

local function devotionPick()
    return {
        kind = "devotionPair",
        source = "priorDistinctGodLoot",
        minDistinct = 2,
        allowedLootNames = GOD_LOOT_NAMES,
    }
end

local function devotionReward()
    local reward = forcedReward("Devotion")
    reward.pick = devotionPick()
    return reward
end

local function shopReward(shopProfile, opts)
    opts = opts or {}
    local reward = {
        kind = "shop",
        shopProfile = shopProfile,
        rewardGeneration = opts.rewardGeneration or {
            effectTiming = "afterNextRow",
        },
    }
    return reward
end

local function prebossReward(shopProfile)
    local choiceGroup = {
        key = "prebossChoice",
        effectTiming = "sameChoiceUnion",
    }
    return {
        kind = "preboss",
        offers = {
            {
                address = "prebossShop",
                label = "Shop",
                kind = "shop",
                shopProfile = shopProfile,
                rewardAliasStart = 1,
                rewardAliasCount = 3,
                rewardGeneration = {
                    effectTiming = "afterNextRow",
                },
                rewardChoiceGroup = choiceGroup,
            },
            {
                address = "prebossReward",
                label = "Free Reward",
                kind = "roomStore",
                rewardStore = "RunProgress",
                ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
                rewardAliasStart = 4,
                rewardAliasCount = 2,
                rewardChoiceGroup = choiceGroup,
            },
        },
    }
end

local function fieldsCagesReward(rewardStore, opts)
    opts = opts or {}
    local reward = {
        kind = "fieldsCages",
        rewardStore = rewardStore or "RunProgress",
    }
    if opts.eligibleRewardTypes ~= nil then
        reward.eligibleRewardTypes = opts.eligibleRewardTypes
    end
    if opts.ineligibleRewardTypes ~= nil then
        reward.ineligibleRewardTypes = opts.ineligibleRewardTypes
    end
    if opts.rewardGeneration ~= nil then
        reward.rewardGeneration = opts.rewardGeneration
    end
    return reward
end

function TestRunPlannerData.testBiomeDefinitionsExposeVanillaDepthScope()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertEquals(#biomes.ordered, 8)
    lu.assertEquals(biomes.ordered[1].key, "F")
    lu.assertEquals(biomes.ordered[2].key, "G")
    lu.assertEquals(biomes.ordered[3].key, "H")
    lu.assertEquals(biomes.ordered[4].key, "I")
    lu.assertEquals(biomes.ordered[5].key, "N")
    lu.assertEquals(biomes.ordered[6].key, "O")
    lu.assertEquals(biomes.ordered[7].key, "P")
    lu.assertEquals(biomes.ordered[8].key, "Q")

    lu.assertEquals(biomes.routes.ordered[1], {
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H", "I" },
    })
    lu.assertEquals(biomes.routes.ordered[2], {
        key = "Surface",
        label = "Surface",
        biomes = { "N", "O", "P", "Q" },
    })

    lu.assertEquals(biomes.lookup.F.slotLayout.routeRowLabelPrefix, "Depth")
    lu.assertEquals(biomes.lookup.F.slotLayout.depthRange, { min = 0, max = 11 })
    lu.assertEquals(biomes.lookup.F.slotLayout.routeStartOrdinal, 1)
    lu.assertEquals(biomes.lookup.F.slotLayout.routeEndOrdinal, 10)

    lu.assertEquals(biomes.lookup.G.slotLayout.depthRange, { min = 1, max = 8 })
    lu.assertEquals(biomes.lookup.G.slotLayout.routeRowLabelPrefix, "Depth")
    lu.assertEquals(biomes.lookup.G.slotLayout.routeStartOrdinal, 1)
    lu.assertEquals(biomes.lookup.G.slotLayout.routeEndOrdinal, 7)

    lu.assertEquals(biomes.lookup.H.adapter, "fieldsCageRoute")
    lu.assertEquals(biomes.lookup.H.slotLayout.routeRowLabelPrefix, "Pick")
    lu.assertEquals(biomes.lookup.H.slotLayout.routeStartOrdinal, 1)
    lu.assertEquals(biomes.lookup.H.slotLayout.routeEndOrdinal, 4)

    lu.assertEquals(biomes.lookup.I.adapter, "clockworkGoal")
    lu.assertEquals(biomes.lookup.I.slotLayout.routeRowLabelPrefix, "Step")
    lu.assertEquals(biomes.lookup.I.slotLayout.routeStartOrdinal, 1)
    lu.assertEquals(biomes.lookup.I.slotLayout.routeEndOrdinal, 12)

    lu.assertEquals(biomes.lookup.N.adapter, "hubPylon")
    lu.assertEquals(biomes.lookup.N.slotLayout.routeRowLabelPrefix, "Pylon")
    lu.assertEquals(biomes.lookup.N.hub.pylonRoomHistoryCost, 2)
    lu.assertEquals(biomes.lookup.N.slotLayout.routeStartOrdinal, 1)
    lu.assertEquals(biomes.lookup.N.slotLayout.routeEndOrdinal, 6)

    lu.assertEquals(biomes.lookup.O.slotLayout.depthRange, { min = 1, max = 7 })
    lu.assertEquals(biomes.lookup.O.slotLayout.routeRowLabelPrefix, "Depth")
    lu.assertEquals(biomes.lookup.O.slotLayout.routeStartOrdinal, 1)
    lu.assertEquals(biomes.lookup.O.slotLayout.routeEndOrdinal, 6)
    lu.assertEquals(biomes.lookup.O.biomeRules[1], {
        key = "story_or_shop_deadline",
        type = "requireAnyRoomByCounter",
        counter = "biomeDepthCache",
        deadline = 5,
        roomKeys = { "O_Story01", "O_Shop01" },
        code = "thessaly_story_or_shop_deadline",
        message = "Thessaly requires Circe or Shop by depth 5",
    })

    lu.assertEquals(biomes.lookup.P.slotLayout.depthRange, { min = 1, max = 9 })
    lu.assertEquals(biomes.lookup.P.slotLayout.routeRowLabelPrefix, "Depth")
    lu.assertEquals(biomes.lookup.P.slotLayout.routeStartOrdinal, 1)
    lu.assertEquals(biomes.lookup.P.slotLayout.routeEndOrdinal, 8)

    lu.assertEquals(biomes.lookup.Q.slotLayout.depthRange, { min = 1, max = 7 })
    lu.assertEquals(biomes.lookup.Q.slotLayout.routeRowLabelPrefix, "Depth")
    lu.assertEquals(biomes.lookup.Q.slotLayout.routeStartOrdinal, 1)
    lu.assertEquals(biomes.lookup.Q.slotLayout.routeEndOrdinal, 6)
end

function TestRunPlannerData.testBiomeDefinitionsDeclareRewardRatios()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertEquals(biomes.lookup.F.rewardRatio, { targetMetaProgress = 0.315 })
    lu.assertEquals(biomes.lookup.G.rewardRatio, { targetMetaProgress = 0.35 })
    lu.assertEquals(biomes.lookup.O.rewardRatio, { targetMetaProgress = 0.30 })
    lu.assertEquals(biomes.lookup.P.rewardRatio, { targetMetaProgress = 0.20 })

    lu.assertNil(biomes.lookup.N.rewardRatio)
    lu.assertNil(biomes.lookup.H.rewardRatio)
    lu.assertNil(biomes.lookup.I.rewardRatio)
    lu.assertNil(biomes.lookup.Q.rewardRatio)
end

function TestRunPlannerData.testBiomeDefinitionsDeclareRoomHistoryTimeline()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertEquals(biomes.lookup.F.timeline.defaultRoomHistoryCost, 1)
    lu.assertEquals(biomes.lookup.F.timeline.afterBiome[1].key, "Boss")
    lu.assertEquals(biomes.lookup.F.timeline.afterBiome[1].roomOptions[1].key, "F_Boss01")
    lu.assertEquals(biomes.lookup.F.timeline.afterBiome[1].roomOptions[2].key, "F_Boss02")
    lu.assertEquals(biomes.lookup.F.timeline.afterBiome[1].roomHistoryCost, 1)
    lu.assertEquals(biomes.lookup.F.timeline.afterBiome[2].key, "PostBoss")
    lu.assertEquals(biomes.lookup.F.timeline.afterBiome[2].roomKey, "F_PostBoss01")
    lu.assertEquals(biomes.lookup.F.timeline.afterBiome[2].roomHistoryCost, 1)
    lu.assertEquals(biomes.lookup.F.timeline.afterBiome[2].features, { wellShop = true })

    lu.assertEquals(biomes.lookup.N.hub.pylonRoomHistoryCost, 2)
    lu.assertEquals(biomes.lookup.N.timeline.afterBiome[1].roomOptions[1].key, "N_Boss01")
    lu.assertEquals(biomes.lookup.N.timeline.afterBiome[2].roomKey, "N_PostBoss01")
    lu.assertEquals(biomes.lookup.N.timeline.afterBiome[2].features, { surfaceShop = true })
    lu.assertEquals(biomes.lookup.I.timeline.afterBiome[1].roomOptions, {
        { key = "I_Boss01", label = "Boss" },
    })
    lu.assertEquals(biomes.lookup.I.timeline.afterBiome[2].features, { wellShop = true })
    lu.assertEquals(biomes.lookup.P.timeline.afterBiome[1].roomOptions, {
        { key = "P_Boss01", label = "Boss" },
    })
    lu.assertEquals(biomes.lookup.P.timeline.afterBiome[2].features, { surfaceShop = true })
    lu.assertEquals(biomes.lookup.Q.timeline.afterBiome[2].features, { surfaceShop = true })
end

function TestRunPlannerData.testBiomeDefinitionsDeclareNaturalChaosFeatures()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local chaos = { chaos = true }
    local chaosWell = { chaos = true, wellShop = true }
    local chaosSurface = { chaos = true, surfaceShop = true }

    lu.assertNil(biomes.lookup.F.slotLayout.special[0].features)
    lu.assertEquals(biomes.lookup.F.featurePolicies.wellShop.roomHistoryDepth, { min = 3 })
    lu.assertEquals(biomes.lookup.F.slotLayout.special[0].roomOptions[1].features, chaos)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Combat.mapOptions[1].features, chaosWell)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Story.roomOptions[1].features, chaos)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Fountain.roomOptions[1].features, chaos)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Midshop.roomOptions[1].features, chaos)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Combat.mapOptions[5].features, chaosWell)
    lu.assertNil(biomes.lookup.F.rolesByKey.Miniboss.features)

    lu.assertEquals(biomes.lookup.G.slotLayout.entry.features, chaos)
    lu.assertEquals(biomes.lookup.G.featurePolicies.wellShop.roomHistoryDepth, { min = 3 })
    lu.assertEquals(biomes.lookup.G.rolesByKey.Combat.mapOptions[1].features, chaosWell)
    lu.assertEquals(biomes.lookup.G.rolesByKey.Story.roomOptions[1].features, chaos)
    lu.assertEquals(biomes.lookup.G.rolesByKey.Fountain.roomOptions[1].features, chaos)
    lu.assertEquals(biomes.lookup.G.rolesByKey.Midshop.roomOptions[1].features, chaos)
    lu.assertEquals(biomes.lookup.G.rolesByKey.Combat.mapOptions[2].features, chaosWell)
    lu.assertEquals(biomes.lookup.G.rolesByKey.Miniboss.roomOptions[1].features, chaos)

    lu.assertEquals(biomes.lookup.N.slotLayout.fixedBeforeHub[1].features, chaos)
    lu.assertEquals(biomes.lookup.N.featurePolicies.surfaceShop.roomHistoryDepth, { min = 3 })
    lu.assertNil(biomes.lookup.N.slotLayout.fixedBeforeHub[2].features)
    lu.assertNil(biomes.lookup.N.rolesByKey.Combat.features)

    lu.assertEquals(biomes.lookup.P.featurePolicies.chaos.roomHistoryDepth, { max = 5 })
    lu.assertEquals(biomes.lookup.P.featurePolicies.surfaceShop.roomHistoryDepth, { min = 3 })
    lu.assertEquals(biomes.lookup.P.slotLayout.entry.features, chaos)
    lu.assertEquals(biomes.lookup.P.rolesByKey.Combat.mapOptions[1].features, chaosSurface)
    lu.assertEquals(biomes.lookup.P.rolesByKey.Fountain.roomOptions[1].features, chaosSurface)
    lu.assertEquals(biomes.lookup.P.rolesByKey.Midshop.roomOptions[1].features, chaos)
    lu.assertNil(biomes.lookup.P.rolesByKey.Story.features)
    lu.assertNil(biomes.lookup.P.rolesByKey.Miniboss.features)

    lu.assertEquals(biomes.lookup.H.featurePolicies.wellShop.roomHistoryDepth, { min = 3 })
    lu.assertEquals(biomes.lookup.I.featurePolicies.wellShop.roomHistoryDepth, { min = 3 })
    lu.assertEquals(biomes.lookup.O.featurePolicies.surfaceShop.roomHistoryDepth, { min = 3 })
    lu.assertEquals(biomes.lookup.Q.featurePolicies.surfaceShop.roomHistoryDepth, { min = 3 })
end

local function optionByKey(options, key)
    for _, option in ipairs(options or {}) do
        if option.key == key then
            return option
        end
    end
    return nil
end

local function optionKeys(options)
    local keys = {}
    for _, option in ipairs(options or {}) do
        keys[#keys + 1] = option.key
    end
    return keys
end

function TestRunPlannerData.testBiomeDefinitionsLabelCombatRoomMetadata()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertEquals(
        optionByKey(biomes.lookup.F.rolesByKey.Combat.mapOptions, "F_Combat01").label,
        "C01 (1 Exit)"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.F.rolesByKey.Combat.mapOptions, "F_Combat02").label,
        "C02 (2 Exits)"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.G.rolesByKey.Combat.mapOptions, "G_Combat02").label,
        "C02 (3 Exits)"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.I.rolesByKey.Goal.mapOptions, "I_Combat02").label,
        "C02 (1 Exit)"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.H.rolesByKey.Combat.mapOptions, "H_Combat04").label,
        "C04 (4 Slots)"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.N.rolesByKey.Combat.mapOptions, "N_Combat01").label,
        "C01 (E)"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.O.rolesByKey.Combat.mapOptions, "O_Combat01").label,
        "C01"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.P.rolesByKey.Combat.mapOptions, "P_Combat01").label,
        "C01 (Outdoor)"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.P.rolesByKey.Combat.mapOptions, "P_Combat02").label,
        "C02 (Indoor)"
    )
    lu.assertEquals(
        optionByKey(biomes.lookup.Q.rolesByKey.Combat.mapOptions, "Q_Combat01").label,
        "C01"
    )
end

function TestRunPlannerData.testEphyraCombatRoomsDeclareLocationAndDifficulty()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local combat = biomes.lookup.N.rolesByKey.Combat.mapOptions

    lu.assertEquals(optionKeys(combat), {
        "N_Combat05",
        "N_Combat06",
        "N_Combat07",
        "N_Combat08",
        "N_Combat02",
        "N_Combat04",
        "N_Combat11",
        "N_Combat14",
        "N_Combat19",
        "N_Combat22",
        "N_Combat03",
        "N_Combat09",
        "N_Combat10",
        "N_Combat13",
        "N_Combat17",
        "N_Combat20",
        "N_Combat21",
        "N_Combat01",
        "N_Combat12",
        "N_Combat15",
        "N_Combat16",
        "N_Combat18",
        "N_Combat23",
    })
    lu.assertEquals(optionByKey(combat, "N_Combat05").location, "S")
    lu.assertEquals(optionByKey(combat, "N_Combat05").difficulty, 2)
    lu.assertEquals(optionByKey(combat, "N_Combat19").location, "W")
    lu.assertEquals(optionByKey(combat, "N_Combat19").difficulty, 4)
    lu.assertEquals(optionByKey(combat, "N_Combat21").location, "N")
    lu.assertEquals(optionByKey(combat, "N_Combat21").difficulty, 4)
    lu.assertEquals(optionByKey(combat, "N_Combat01").location, "E")
    lu.assertEquals(optionByKey(combat, "N_Combat01").difficulty, 3)
end

local function assertMinibossCosts(role, expectedCosts)
    lu.assertTrue(role.requiresConcreteOption)
    lu.assertNil(role.biomeEncounterDepthCost)
    for _, option in ipairs(role.roomOptions or {}) do
        lu.assertNotNil(
            option.biomeEncounterDepthCost,
            "Miniboss option must declare cost: " .. tostring(option.key)
        )
    end
    for optionKey, expectedCost in pairs(expectedCosts) do
        lu.assertEquals(optionByKey(role.roomOptions, optionKey).biomeEncounterDepthCost, expectedCost)
    end
end

local function assertEncounterDepthCostRange(value, minCost, maxCost)
    lu.assertEquals(value, {
        min = minCost,
        max = maxCost,
    })
end

local function assertEncounterDepthCost(value, context)
    if type(value) == "table" then
        lu.assertNotNil(value.min, context .. " missing min encounter-depth cost")
        lu.assertNotNil(value.max, context .. " missing max encounter-depth cost")
        return
    end
    lu.assertEquals(type(value), "number", context .. " missing encounter-depth cost")
end

local function roleOptions(role)
    return role.roomOptions or role.mapOptions or {}
end

local function assertSlotEncounterDepthCost(slot, context)
    if slot == nil then
        return
    end
    assertEncounterDepthCost(slot.biomeEncounterDepthCost, context)
end

local function assertSlotListEncounterDepthCosts(slots, context)
    for index, slot in ipairs(slots or {}) do
        assertSlotEncounterDepthCost(slot, context .. "[" .. tostring(index) .. "]")
    end
end

local function assertSpecialSlotEncounterDepthCosts(slots, context)
    for ordinal, slot in pairs(slots or {}) do
        assertSlotEncounterDepthCost(slot, context .. "[" .. tostring(ordinal) .. "]")
    end
end

function TestRunPlannerData.testBiomeDefinitionsDeclareEncounterDepthCosts()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertEquals(biomes.lookup.F.slotLayout.special[0].biomeEncounterDepthCost, 1)
    lu.assertNil(biomes.lookup.F.slotLayout.default)
    assertEncounterDepthCostRange(biomes.lookup.F.rolesByKey.Vanilla.biomeEncounterDepthCost, 0, 1)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Combat.biomeEncounterDepthCost, 1)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Combat.mapOptions[1].biomeEncounterDepthCost, 1)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Story.biomeEncounterDepthCost, 0)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Fountain.biomeEncounterDepthCost, 0)
    lu.assertEquals(optionByKey(biomes.lookup.F.rolesByKey.Combat.mapOptions, "F_Combat05").biomeEncounterDepthCost, 1)
    assertEncounterDepthCostRange(biomes.lookup.G.rolesByKey.Vanilla.biomeEncounterDepthCost, 0, 1)
    lu.assertEquals(biomes.lookup.G.rolesByKey.Combat.biomeEncounterDepthCost, 1)
    assertEncounterDepthCostRange(biomes.lookup.H.rolesByKey.Vanilla.biomeEncounterDepthCost, 0, 1)
    lu.assertEquals(biomes.lookup.H.rolesByKey.Combat.biomeEncounterDepthCost, 1)
    assertEncounterDepthCostRange(biomes.lookup.I.rolesByKey.Vanilla.biomeEncounterDepthCost, 0, 1)
    lu.assertEquals(biomes.lookup.I.rolesByKey.Goal.biomeEncounterDepthCost, 1)
    lu.assertEquals(biomes.lookup.I.rolesByKey.ExtensionCombat.biomeEncounterDepthCost, 1)
    assertEncounterDepthCostRange(biomes.lookup.N.rolesByKey.Vanilla.biomeEncounterDepthCost, 0, 1)
    lu.assertEquals(biomes.lookup.N.rolesByKey.Combat.biomeEncounterDepthCost, 1)
    assertEncounterDepthCostRange(biomes.lookup.O.rolesByKey.Vanilla.biomeEncounterDepthCost, 0, 2)
    assertEncounterDepthCostRange(biomes.lookup.O.rolesByKey.Combat.biomeEncounterDepthCost, 1, 2)
    lu.assertEquals(biomes.lookup.O.rolesByKey.Devotion.biomeEncounterDepthCost, 1)
    assertEncounterDepthCostRange(biomes.lookup.P.rolesByKey.Vanilla.biomeEncounterDepthCost, 0, 1)
    lu.assertEquals(biomes.lookup.P.rolesByKey.Combat.biomeEncounterDepthCost, 1)
    assertEncounterDepthCostRange(biomes.lookup.Q.rolesByKey.Vanilla.biomeEncounterDepthCost, 0, 1)
    lu.assertEquals(biomes.lookup.Q.rolesByKey.Combat.biomeEncounterDepthCost, 1)

    assertMinibossCosts(biomes.lookup.F.rolesByKey.Miniboss, {
        F_MiniBoss01 = 1,
        F_MiniBoss02 = 1,
        F_MiniBoss03 = 1,
    })
    assertMinibossCosts(biomes.lookup.H.rolesByKey.Miniboss, {
        H_MiniBoss01 = 1,
        H_MiniBoss02 = 1,
    })
    assertMinibossCosts(biomes.lookup.I.rolesByKey.Miniboss, {
        I_MiniBoss01 = 1,
        I_MiniBoss02 = 1,
    })
    assertMinibossCosts(biomes.lookup.N.rolesByKey.Miniboss, {
        N_MiniBoss01 = 1,
        N_MiniBoss02 = 1,
    })
    assertMinibossCosts(biomes.lookup.G.rolesByKey.Miniboss, {
        G_MiniBoss01 = 1,
        G_MiniBoss02 = 0,
        G_MiniBoss03 = 1,
    })
    assertMinibossCosts(biomes.lookup.O.rolesByKey.Miniboss, {
        O_MiniBoss01 = 0,
        O_MiniBoss02 = 1,
    })
    assertMinibossCosts(biomes.lookup.P.rolesByKey.Miniboss, {
        P_MiniBoss01 = 0,
        P_MiniBoss02 = 1,
    })
    assertMinibossCosts(biomes.lookup.Q.rolesByKey.Miniboss, {
        Q_MiniBoss02 = 1,
        Q_MiniBoss03 = 1,
        Q_MiniBoss04 = 0,
        Q_MiniBoss05 = 1,
    })

    lu.assertEquals(biomes.lookup.F.slotLayout.special[11].biomeEncounterDepthCost, 0)

    local thessalyPolicy = biomes.lookup.O.combatEncounterPolicy.countControl.options
    assertEncounterDepthCostRange(thessalyPolicy[1].biomeEncounterDepthCost, 1, 2)
    lu.assertEquals(thessalyPolicy[2].biomeEncounterDepthCost, 1)
    lu.assertEquals(thessalyPolicy[3].biomeEncounterDepthCost, 2)
end

function TestRunPlannerData.testBiomeDefinitionsResolveRouteEncounterDepthCosts()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    for _, biome in ipairs(biomes.ordered) do
        local slotLayout = biome.slotLayout or {}
        assertSlotEncounterDepthCost(slotLayout.entry, biome.key .. ".entry")
        assertSlotListEncounterDepthCosts(slotLayout.fixedBeforeRoute, biome.key .. ".fixedBeforeRoute")
        assertSlotListEncounterDepthCosts(slotLayout.fixedAfterRoute, biome.key .. ".fixedAfterRoute")
        assertSlotListEncounterDepthCosts(slotLayout.fixedBeforeHub, biome.key .. ".fixedBeforeHub")
        assertSlotListEncounterDepthCosts(slotLayout.fixedAfterHub, biome.key .. ".fixedAfterHub")
        assertSlotListEncounterDepthCosts(slotLayout.fixedAfterGoals, biome.key .. ".fixedAfterGoals")
        assertSpecialSlotEncounterDepthCosts(slotLayout.special, biome.key .. ".special")

        for _, role in ipairs(biome.roles or {}) do
            local context = biome.key .. "." .. tostring(role.key)
            if role.requiresConcreteOption then
                for _, option in ipairs(roleOptions(role)) do
                    assertEncounterDepthCost(option.biomeEncounterDepthCost, context .. "." .. tostring(option.key))
                end
            else
                assertEncounterDepthCost(role.biomeEncounterDepthCost, context)
            end
        end

        local countOptions = biome.combatEncounterPolicy
            and biome.combatEncounterPolicy.countControl
            and biome.combatEncounterPolicy.countControl.options
            or nil
        for _, option in ipairs(countOptions or {}) do
            assertEncounterDepthCost(
                option.biomeEncounterDepthCost,
                biome.key .. ".combatEncounterPolicy." .. tostring(option.key)
            )
        end
    end
end

function TestRunPlannerData.testBiomeDefinitionsDeclareShopFeatureEligibility()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local chaos = { chaos = true }
    local chaosWell = { chaos = true, wellShop = true }
    local well = { wellShop = true }
    local surface = { surfaceShop = true }
    local chaosSurface = { chaos = true, surfaceShop = true }

    local gCombat = biomes.lookup.G.rolesByKey.Combat.mapOptions
    lu.assertEquals(optionByKey(gCombat, "G_Combat03").features, chaosWell)
    lu.assertEquals(optionByKey(gCombat, "G_Combat04").features, chaos)
    lu.assertEquals(optionByKey(gCombat, "G_Combat07").features, chaosWell)

    lu.assertEquals(biomes.lookup.H.rolesByKey.Combat.mapOptions[1].features, well)
    lu.assertNil(biomes.lookup.H.rolesByKey.Miniboss.roomOptions[1].features)

    lu.assertEquals(optionByKey(biomes.lookup.I.rolesByKey.Goal.mapOptions, "I_Combat24").features, well)
    lu.assertEquals(
        biomes.lookup.I.clockwork.extensionRoom.specialOptions.miniboss[1].features,
        well
    )
    lu.assertNil(biomes.lookup.I.clockwork.extensionRoom.specialOptions.fountain[1].features)

    local nCombat02 = biomes.lookup.N.hub.combatRoomsByKey.N_Combat02
    lu.assertEquals(nCombat02.sideDoors[1].features, surface)
    local nCombat06 = biomes.lookup.N.hub.combatRoomsByKey.N_Combat06
    lu.assertEquals(nCombat06.sideDoors[2].features, surface)

    lu.assertNil(optionByKey(biomes.lookup.O.rolesByKey.Combat.mapOptions, "O_Combat01").features)
    lu.assertEquals(optionByKey(biomes.lookup.O.rolesByKey.Combat.mapOptions, "O_Combat02").features, surface)
    lu.assertEquals(biomes.lookup.O.rolesByKey.Fountain.roomOptions[1].features, surface)
    lu.assertEquals(biomes.lookup.O.rolesByKey.Devotion.roomOptions[1].features, surface)
    lu.assertNil(biomes.lookup.O.rolesByKey.Miniboss.roomOptions[1].features)
    lu.assertEquals(biomes.lookup.O.rolesByKey.Miniboss.roomOptions[2].features, surface)

    lu.assertEquals(optionByKey(biomes.lookup.P.rolesByKey.Combat.mapOptions, "P_Combat03").features, chaosSurface)
    lu.assertEquals(optionByKey(biomes.lookup.P.rolesByKey.Combat.mapOptions, "P_Combat04").features, chaos)
    lu.assertEquals(biomes.lookup.P.rolesByKey.Fountain.roomOptions[1].features, chaosSurface)

    lu.assertEquals(optionByKey(biomes.lookup.Q.rolesByKey.Combat.mapOptions, "Q_Combat13").features, surface)
    lu.assertNil(optionByKey(biomes.lookup.Q.rolesByKey.Combat.mapOptions, "Q_Combat14").features)
    lu.assertNil(optionByKey(biomes.lookup.Q.rolesByKey.Miniboss.roomOptions, "Q_MiniBoss02").features)
end

function TestRunPlannerData.testRewardTypeMetadataSeparatesBoonHermesAndDevotion()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertEquals(biomes.rewardTypes.lookup.Boon.pick, boonSourcePick())
    lu.assertEquals(biomes.rewardTypes.lookup.HermesUpgrade.kind, "standaloneLoot")
    lu.assertNil(biomes.rewardTypes.lookup.HermesUpgrade.pick)
    lu.assertEquals(biomes.rewardTypes.lookup.Devotion.pick, devotionPick())
    lu.assertNil(biomes.rewardTypes.lookup.Devotion.routeRequirements)
end

function TestRunPlannerData.testBiomeDefinitionsDeclareDepthSpecials()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    local fOpening = biomes.lookup.F.slotLayout.special[0]
    lu.assertEquals(fOpening.kind, "opening")
    lu.assertEquals(fOpening.key, "Opening")
    lu.assertEquals(fOpening.roomOptions[1].key, "F_Opening01")
    lu.assertEquals(fOpening.reward, roomStoreReward("OpeningRunProgress"))
    lu.assertTrue(fOpening.locked)

    local fPreboss = biomes.lookup.F.slotLayout.special[11]
    lu.assertEquals(fPreboss.roomKey, "F_PreBoss01")
    lu.assertEquals(fPreboss.biomeDepthCache, 10)
    lu.assertEquals(fPreboss.key, "Preboss")
    lu.assertEquals(fPreboss.label, "Preboss")
    lu.assertEquals(fPreboss.reward, prebossReward("WorldShop"))

    local gIntro = biomes.lookup.G.slotLayout.entry
    lu.assertEquals(gIntro.kind, "intro")
    lu.assertEquals(gIntro.roomKey, "G_Intro")
    lu.assertTrue(gIntro.locked)
    lu.assertNil(biomes.lookup.G.slotLayout.special[1])

    local gPreboss = biomes.lookup.G.slotLayout.special[8]
    lu.assertEquals(gPreboss.roomKey, "G_PreBoss01")
    lu.assertEquals(gPreboss.label, "Preboss")
    lu.assertEquals(gPreboss.reward, prebossReward("WorldShop"))

    lu.assertEquals(biomes.lookup.H.slotLayout.fixedBeforeRoute[1].roomKey, "H_Intro")
    lu.assertEquals(biomes.lookup.H.slotLayout.fixedBeforeRoute[1].reward, noneReward())
    local hPreboss = biomes.lookup.H.slotLayout.fixedAfterRoute[1]
    lu.assertEquals(hPreboss.kind, "preboss")
    lu.assertEquals(hPreboss.roomKey, "H_PreBoss01")
    lu.assertEquals(hPreboss.label, "Preboss")
    lu.assertEquals(hPreboss.reward, prebossReward("WorldShop"))

    local oIntro = biomes.lookup.O.slotLayout.entry
    lu.assertEquals(oIntro.kind, "intro")
    lu.assertEquals(oIntro.roomKey, "O_Intro")
    lu.assertTrue(oIntro.locked)
    lu.assertNil(biomes.lookup.O.slotLayout.special[1])

    local pIntro = biomes.lookup.P.slotLayout.entry
    lu.assertEquals(pIntro.kind, "intro")
    lu.assertEquals(pIntro.roomKey, "P_Intro")
    lu.assertTrue(pIntro.locked)
    lu.assertNil(biomes.lookup.P.slotLayout.special[1])

    local pPreboss = biomes.lookup.P.slotLayout.special[9]
    lu.assertEquals(pPreboss.roomKey, "P_PreBoss01")
    lu.assertEquals(pPreboss.label, "Preboss")
    lu.assertEquals(pPreboss.reward, prebossReward("WorldShop"))

    local qIntro = biomes.lookup.Q.slotLayout.entry
    lu.assertEquals(qIntro.kind, "intro")
    lu.assertEquals(qIntro.roomKey, "Q_Intro")
    lu.assertTrue(qIntro.locked)
    lu.assertNil(biomes.lookup.Q.slotLayout.special[1])

    local qPreboss = biomes.lookup.Q.slotLayout.special[7]
    lu.assertEquals(qPreboss.roomKey, "Q_PreBoss01")
    lu.assertEquals(qPreboss.key, "Preboss")
    lu.assertEquals(qPreboss.label, "Preboss Shop")
    lu.assertEquals(qPreboss.reward, shopReward("Q_WorldShop"))

    local oPreboss = biomes.lookup.O.slotLayout.special[7]
    lu.assertEquals(oPreboss.roomKey, "O_PreBoss01")
    lu.assertEquals(oPreboss.key, "Preboss")
    lu.assertEquals(oPreboss.label, "Preboss Shop")
    lu.assertEquals(oPreboss.reward, shopReward("WorldShop"))
end

function TestRunPlannerData.testBiomeDefinitionsDeclareRoleCapabilities()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertNil(biomes.lookup.F.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Combat.mapOptions[1].key, "F_Combat01")
    lu.assertEquals(biomes.lookup.F.rolesByKey.Combat.reward, majorMinorReward())
    lu.assertEquals(
        optionByKey(biomes.lookup.F.rolesByKey.Combat.mapOptions, "F_Combat05").reward,
        majorMinorReward({ allowDevotion = true })
    )
    lu.assertEquals(biomes.lookup.F.rolesByKey.Fountain.reward, majorMinorReward())
    assertOneShotRole(biomes.lookup.F.rolesByKey.Story)
    assertOneShotRole(biomes.lookup.F.rolesByKey.Fountain)
    assertOneShotRole(biomes.lookup.F.rolesByKey.Midshop)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Miniboss.roomOptions[1].key, "F_MiniBoss01")
    lu.assertEquals(biomes.lookup.F.rolesByKey.Miniboss.reward, roomStoreReward("RunProgress", {
        eligibleRewardTypes = { "Boon" },
    }))
    lu.assertEquals(biomes.lookup.F.rolesByKey.Miniboss.routeRules, oneShotRouteRules())

    lu.assertEquals(biomes.lookup.G.rolesByKey.Combat.reward, majorMinorReward())
    lu.assertEquals(
        optionByKey(biomes.lookup.G.rolesByKey.Combat.mapOptions, "G_Combat02").reward,
        majorMinorReward({ allowDevotion = true })
    )
    lu.assertEquals(biomes.lookup.G.rolesByKey.Fountain.reward, majorMinorReward())
    assertOneShotRole(biomes.lookup.G.rolesByKey.Story)
    assertOneShotRole(biomes.lookup.G.rolesByKey.Fountain)
    assertOneShotRole(biomes.lookup.G.rolesByKey.Midshop)
    lu.assertNil(biomes.lookup.G.rolesByKey.Trial)

    lu.assertNil(biomes.lookup.P.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.P.rolesByKey.Combat.reward, majorMinorReward())
    lu.assertEquals(biomes.lookup.P.rolesByKey.Fountain.reward, majorMinorReward())
    lu.assertEquals(biomes.lookup.P.slotLayout.entry.tags, { "Outdoor" })
    lu.assertEquals(biomes.lookup.P.slotLayout.special[9].tags, { "Indoor", "Outdoor" })
    lu.assertEquals(biomes.lookup.P.rolesByKey.Combat.mapOptions[2].tags, { "Indoor" })
    lu.assertEquals(biomes.lookup.P.rolesByKey.Combat.mapOptions[17].tags, { "Outdoor" })
    lu.assertEquals(biomes.lookup.P.rolesByKey.Fountain.roomOptions[1].tags, { "Indoor" })
    lu.assertEquals(biomes.lookup.P.rolesByKey.Midshop.roomOptions[1].tags, { "Outdoor" })
    lu.assertEquals(biomes.lookup.P.rolesByKey.Miniboss.roomOptions[1].tags, { "Indoor" })
    assertOneShotRole(biomes.lookup.P.rolesByKey.Story)
    assertOneShotRole(biomes.lookup.P.rolesByKey.Fountain)
    assertOneShotRole(biomes.lookup.P.rolesByKey.Midshop)
    lu.assertEquals(biomes.lookup.P.rolesByKey.Miniboss.routeRules, oneShotRouteRules())
    lu.assertNil(biomes.lookup.Q.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.Q.rolesByKey.Miniboss.roomOptions[4].key, "Q_MiniBoss05")
    lu.assertEquals(biomes.lookup.Q.rolesByKey.Combat.reward, noneReward())
    lu.assertEquals(biomes.lookup.Q.rolesByKey.Miniboss.reward, roomStoreReward("TyphonBossRewards"))
    lu.assertEquals(biomes.lookup.Q.rolesByKey.Miniboss.routeRules, maxSelectionRouteRules(2))

    lu.assertEquals(biomes.lookup.O.adapter, "multiEncounterFixed")
    lu.assertEquals(biomes.lookup.O.rolesByKey.Combat.reward, noneReward())
    lu.assertEquals(biomes.lookup.O.rolesByKey.Combat.encounterPolicy, "O_CombatData")
    lu.assertEquals(biomes.lookup.O.rolesByKey.Fountain.reward, majorMinorReward())
    assertOneShotRole(biomes.lookup.O.rolesByKey.Story)
    assertOneShotRole(biomes.lookup.O.rolesByKey.Fountain)
    assertOneShotRole(biomes.lookup.O.rolesByKey.Midshop)
    lu.assertNil(biomes.lookup.O.rolesByKey.Trial)
    assertOneShotRole(biomes.lookup.O.rolesByKey.Devotion)
    lu.assertEquals(biomes.lookup.O.rolesByKey.Devotion.roomOptions[1].key, "O_Devotion01")
    lu.assertEquals(biomes.lookup.O.rolesByKey.Devotion.reward, devotionReward())
    lu.assertEquals(biomes.lookup.O.rolesByKey.Devotion.requiredLayer, "rewards")
    lu.assertEquals(biomes.lookup.O.rolesByKey.Miniboss.roomOptions[2].key, "O_MiniBoss02")
    lu.assertEquals(biomes.lookup.O.rolesByKey.Miniboss.routeRules, oneShotRouteRules())

    lu.assertNil(biomes.lookup.H.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.H.rolesByKey.Combat.mapOptions[1].key, "H_Combat01")
    lu.assertEquals(biomes.lookup.H.rolesByKey.Combat.reward, fieldsCagesReward("RunProgress", {
        ineligibleRewardTypes = { "Devotion" },
        rewardGeneration = {
            effectTiming = "afterBatch",
        },
    }))
    lu.assertEquals(biomes.lookup.H.rolesByKey.Miniboss.roomOptions[1].encounter, "MiniBossVampire")
    lu.assertEquals(biomes.lookup.H.rolesByKey.Miniboss.roomOptions[2].encounter, "MiniBossLamia")
    lu.assertEquals(biomes.lookup.H.rolesByKey.Miniboss.reward, roomStoreReward("RunProgress", {
        eligibleRewardTypes = { "Boon" },
    }))
    lu.assertEquals(biomes.lookup.H.rolesByKey.Miniboss.routeRules, oneShotRouteRules())
    lu.assertEquals(biomes.lookup.H.rolesByKey.Bridge.reward, noneReward())

    lu.assertEquals(biomes.lookup.I.rolesByKey.Goal.mapOptions[1].key, "I_Combat01")
    lu.assertEquals(biomes.lookup.I.rolesByKey.Goal.reward, forcedReward("ClockworkGoal"))
    lu.assertEquals(biomes.lookup.I.rolesByKey.ExtensionCombat.reward, roomStoreReward("TartarusRewards", {
        ineligibleRewardTypes = { "Boon" },
    }))
    lu.assertNil(biomes.lookup.I.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.I.rolesByKey.Story.roomOptions[1].key, "I_Story01")
    lu.assertEquals(biomes.lookup.I.rolesByKey.Story.maxCreationsThisRun, 1)
    lu.assertEquals(biomes.lookup.I.rolesByKey.Fountain.roomOptions[1].key, "I_Reprieve01")
    lu.assertEquals(biomes.lookup.I.rolesByKey.Fountain.reward, roomStoreReward("TartarusRewards", {
        ineligibleRewardTypes = { "Devotion" },
    }))
    lu.assertEquals(biomes.lookup.I.rolesByKey.Fountain.maxCreationsThisRun, 1)
    lu.assertNil(biomes.lookup.I.rolesByKey.Midshop)
    lu.assertEquals(biomes.lookup.I.rolesByKey.Miniboss.roomOptions[2].key, "I_MiniBoss02")
    lu.assertEquals(biomes.lookup.I.rolesByKey.Miniboss.maxCreationsThisRun, 1)

    lu.assertEquals(biomes.lookup.N.rolesByKey.Combat.mapOptions[1].key, "N_Combat05")
    lu.assertEquals(biomes.lookup.N.rolesByKey.Combat.reward, roomStoreReward("HubRewards"))
    lu.assertEquals(biomes.lookup.N.rolesByKey.Story.roomOptions[1].key, "N_Story01")
    lu.assertEquals(biomes.lookup.N.rolesByKey.Story.roomOptions[1].label, "Medea")
    assertOneShotRole(biomes.lookup.N.rolesByKey.Story)
    lu.assertEquals(biomes.lookup.N.rolesByKey.Miniboss.roomOptions[1].encounter, "MiniBossSatyrCrossbow")
    lu.assertEquals(biomes.lookup.N.rolesByKey.Miniboss.roomOptions[2].encounter, "MiniBossBoar")
    lu.assertEquals(biomes.lookup.N.rolesByKey.Miniboss.reward, roomStoreReward("RunProgress", {
        eligibleRewardTypes = { "Boon" },
    }))
    lu.assertEquals(biomes.lookup.N.rolesByKey.Miniboss.routeRules, oneShotRouteRules())
end

function TestRunPlannerData.testBiomeOptionsDeclareAvailabilityMetadata()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    local erebus = biomes.lookup.F.rolesByKey
    lu.assertEquals(erebus.Combat.mapOptions[1].availability.biomeEncounterDepth, { max = 5 })
    lu.assertEquals(erebus.Combat.mapOptions[1].exitCount, 1)
    lu.assertEquals(erebus.Combat.mapOptions[5].availability.biomeEncounterDepth, { min = 5 })
    lu.assertEquals(erebus.Combat.mapOptions[9].exitCount, 1)
    lu.assertEquals(erebus.Story.roomOptions[1].availability.biomeDepthCache, { min = 4, max = 8 })
    lu.assertEquals(erebus.Story.roomOptions[1].exitCount, 2)
    lu.assertEquals(erebus.Midshop.roomOptions[1].availability.biomeDepthCache, { min = 4, max = 6 })
    lu.assertEquals(erebus.Midshop.routeRequirements, midshopRequirements())
    lu.assertEquals(optionByKey(erebus.Combat.mapOptions, "F_Combat05").availability.biomeEncounterDepth, { min = 5 })
    lu.assertEquals(optionByKey(erebus.Combat.mapOptions, "F_Combat05").reward, majorMinorReward({
        allowDevotion = true,
    }))
    lu.assertEquals(erebus.Miniboss.roomOptions[3].exitCount, 1)

    local oceanus = biomes.lookup.G.rolesByKey
    lu.assertEquals(oceanus.Combat.mapOptions[18].availability.biomeEncounterDepth, { max = 2 })
    lu.assertEquals(oceanus.Combat.mapOptions[18].availability.biomeDepthCache, { max = 3 })
    lu.assertEquals(oceanus.Combat.mapOptions[18].exitCount, 3)
    lu.assertEquals(oceanus.Story.roomOptions[1].availability.biomeDepthCache, { min = 3, max = 6 })
    lu.assertEquals(oceanus.Story.roomOptions[1].exitCount, 1)
    lu.assertEquals(oceanus.Midshop.roomOptions[1].availability.biomeDepthCache, { min = 3, max = 5 })
    lu.assertEquals(oceanus.Midshop.routeRequirements, midshopRequirements())
    lu.assertEquals(optionByKey(oceanus.Combat.mapOptions, "G_Combat03").availability.biomeEncounterDepth, { min = 3 })
    lu.assertEquals(optionByKey(oceanus.Combat.mapOptions, "G_Combat03").reward, majorMinorReward({
        allowDevotion = true,
    }))
    lu.assertEquals(oceanus.Miniboss.roomOptions[2].exitCount, 1)

    local fields = biomes.lookup.H.rolesByKey
    lu.assertEquals(fields.Combat.mapOptions[1].maxCageRewards, 5)
    lu.assertEquals(fields.Combat.mapOptions[4].maxCageRewards, 4)
    lu.assertEquals(fields.Combat.mapOptions[9].maxCageRewards, 2)
    lu.assertEquals(fields.Combat.mapOptions[9].availability.biomeDepthCache, { max = 3 })
    lu.assertEquals(fields.Combat.mapOptions[15].availability.biomeDepthCache, { max = 3 })
    lu.assertEquals(fields.Miniboss.roomOptions[1].availability.biomeDepthCache, { min = 2, max = 4 })
    lu.assertEquals(fields.Miniboss.routeRules, oneShotRouteRules())
    lu.assertEquals(fields.Bridge.roomOptions[1].availability.biomeDepthCache, { exact = 3 })

    local thessaly = biomes.lookup.O.rolesByKey
    lu.assertEquals(thessaly.Combat.mapOptions[13].availability.biomeDepthCache, { min = 6 })
    lu.assertEquals(thessaly.Story.roomOptions[1].availability.biomeEncounterDepth, { minExclusive = 3 })
    lu.assertEquals(thessaly.Fountain.roomOptions[1].availability.biomeDepthCache, { min = 3, max = 5 })
    lu.assertEquals(thessaly.Devotion.roomOptions[1].availability.biomeEncounterDepth, { min = 2 })
    lu.assertEquals(thessaly.Miniboss.routeRules, oneShotRouteRules())

    local olympus = biomes.lookup.P.rolesByKey
    lu.assertEquals(olympus.Combat.mapOptions[1].availability.biomeEncounterDepth, { min = 3 })
    lu.assertEquals(olympus.Combat.mapOptions[3].availability.biomeEncounterDepth, { max = 4 })
    lu.assertEquals(olympus.Story.roomOptions[1].availability.biomeEncounterDepth, { minExclusive = 2 })
    lu.assertEquals(olympus.Midshop.roomOptions[1].availability.biomeEncounterDepth, { minExclusive = 4 })
    lu.assertEquals(olympus.Miniboss.roomOptions[1].availability.biomeDepthCache, { min = 4, max = 7 })
    lu.assertTrue(olympus.Miniboss.roomOptions[1].availability.requiresMultipleOfferedDoors)

    local summit = biomes.lookup.Q.rolesByKey
    lu.assertEquals(summit.Combat.mapOptions[10].availability.biomeDepthCache, { exact = 1 })
    lu.assertEquals(summit.Combat.mapOptions[12].availability.biomeDepthCache, { exact = 5 })
    lu.assertEquals(summit.Miniboss.roomOptions[1].key, "Q_MiniBoss02")
    lu.assertEquals(summit.Miniboss.roomOptions[1].availability.biomeDepthCache, { exact = 3 })
    lu.assertEquals(summit.Miniboss.roomOptions[4].availability.biomeDepthCache, { exact = 3 })
end

function TestRunPlannerData.testTartarusClockworkLayoutModelsGoalRoute()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local tartarus = biomes.lookup.I

    lu.assertEquals(tartarus.slotLayout.fixedBeforeRoute[1].roomKey, "I_Intro")
    lu.assertEquals(tartarus.slotLayout.fixedBeforeRoute[1].reward, noneReward())
    lu.assertEquals(tartarus.slotLayout.fixedAfterGoals[1].roomOptions[1].key, "I_PreBoss01")
    lu.assertEquals(tartarus.slotLayout.fixedAfterGoals[1].roomOptions[2].key, "I_PreBoss02")
    lu.assertEquals(tartarus.slotLayout.fixedAfterGoals[1].reward, shopReward("I_WorldShop"))

    lu.assertEquals(tartarus.clockwork.forcedFirstRouteRole, "Goal")
    lu.assertEquals(tartarus.clockwork.routeCounters, {
        clockworkGoal = {
            maxCreationsThisRun = 5,
        },
        clockworkNonGoalReward = {
            maxCreationsThisRun = 6,
        },
    })

    lu.assertEquals(#tartarus.clockwork.goalRoom.roomOptions, 24)
    lu.assertEquals(tartarus.clockwork.goalRoom.roomOptions[1].exitCount, 2)
    lu.assertTrue(tartarus.clockwork.goalRoom.roomOptions[1].supportsExtensionChoice)
    lu.assertEquals(tartarus.clockwork.goalRoom.roomOptions[2].exitCount, 1)
    lu.assertFalse(tartarus.clockwork.goalRoom.roomOptions[2].supportsExtensionChoice)
    lu.assertEquals(tartarus.clockwork.goalRoom.roomOptions[12].exitCount, 2)
    lu.assertTrue(tartarus.clockwork.goalRoom.roomOptions[12].supportsExtensionChoice)
    lu.assertEquals(tartarus.clockwork.goalRoom.roomOptions[24].exitCount, 1)
    lu.assertFalse(tartarus.clockwork.goalRoom.roomOptions[24].supportsExtensionChoice)
    lu.assertEquals(tartarus.clockwork.goalRoom.reward, forcedReward("ClockworkGoal"))
    lu.assertEquals(tartarus.clockwork.goalRoom.increments, { clockworkGoal = 1 })
    lu.assertEquals(tartarus.clockwork.extensionRoom.combatOptions[1].reward, roomStoreReward("TartarusRewards", {
        ineligibleRewardTypes = { "Boon" },
    }))

    local combat24 = tartarus.clockwork.goalRoom.roomOptions[24]
    lu.assertEquals(combat24.key, "I_Combat24")
    lu.assertEquals(combat24.availability.biomeDepthCache, { max = 5 })

    lu.assertEquals(tartarus.clockwork.extensionRoom.combatOptions[1].key, "I_Combat01")
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.story[1].key, "I_Story01")
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.story[1].reward, noneReward())
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.story[1].exitCount, 1)
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.story[1].availability.biomeDepthCache, { min = 2 })
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.fountain[1].key, "I_Reprieve01")
    lu.assertEquals(
        tartarus.clockwork.extensionRoom.specialOptions.fountain[1].reward,
        roomStoreReward("TartarusRewards", { ineligibleRewardTypes = { "Devotion" } })
    )
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.fountain[1].exitCount, 2)
    lu.assertEquals(tartarus.rolesByKey.ExtensionCombat.increments, { clockworkNonGoalReward = 1 })
    lu.assertEquals(tartarus.rolesByKey.Story.increments, { clockworkStory = 1 })
    lu.assertEquals(tartarus.rolesByKey.Story.maxCreationsThisRun, 1)
    lu.assertEquals(tartarus.rolesByKey.Fountain.increments, { clockworkNonGoalReward = 1 })
    lu.assertEquals(tartarus.rolesByKey.Fountain.maxCreationsThisRun, 1)
    lu.assertEquals(tartarus.rolesByKey.Miniboss.increments, { clockworkNonGoalReward = 1 })
    lu.assertEquals(tartarus.rolesByKey.Miniboss.maxCreationsThisRun, 1)
    lu.assertEquals(tartarus.rolesByKey.Miniboss.requiresPrevious, { supportsExtensionChoice = true })
    lu.assertNil(tartarus.clockwork.extensionRoom.specialOptions.shop)
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.miniboss[2].exitCount, 2)
    lu.assertTrue(tartarus.clockwork.extensionRoom.specialOptions.miniboss[2].supportsExtensionChoice)
end

function TestRunPlannerData.testEphyraHubLayoutModelsPylonRoute()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local ephyra = biomes.lookup.N

    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[1].roomKey, "N_Opening01")
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[1].reward, roomStoreReward("OpeningRunProgress"))
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[2].roomKey, "N_PreHub01")
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[2].reward, roomStoreReward("OpeningRunProgress"))
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[3].roomKey, "N_Hub")
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[3].reward, noneReward())
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[3].roomHistoryCost, 0)
    lu.assertEquals(ephyra.slotLayout.fixedAfterHub[1].roomKey, "N_PreBoss01")
    lu.assertEquals(ephyra.slotLayout.fixedAfterHub[1].reward, shopReward("WorldShop"))

    lu.assertEquals(ephyra.hub.roomKey, "N_Hub")
    lu.assertEquals(ephyra.hub.requiredPylons, 6)
    lu.assertEquals(ephyra.hub.availableDoorCount, { min = 9, max = 10 })
    lu.assertEquals(ephyra.hub.sideRoomAvailability.default, "")
    lu.assertEquals(ephyra.hub.sideRoomAvailability.modes, {
        { key = "", label = "Vanilla" },
        { key = "Disabled", label = "Disabled" },
        { key = "Enabled", label = "Enabled" },
    })
    lu.assertEquals(#ephyra.hub.combatRooms, 23)
    lu.assertEquals(#ephyra.hub.hubDoorRooms, 26)

    local combat12 = ephyra.hub.combatRoomsByKey.N_Combat12
    lu.assertEquals(combat12.hubDoorId, 561389)
    lu.assertEquals(combat12.reward, roomStoreReward("EasyHubRewards"))
    lu.assertEquals(#combat12.sideDoors, 3)
    lu.assertEquals(combat12.sideDoors[1], {
        doorId = 558352,
        roomKey = "N_Sub09",
        features = { surfaceShop = true },
        reward = roomStoreReward("SubRoomRewardsHard"),
    })
    lu.assertEquals(combat12.sideDoors[3], {
        doorId = 566545,
        roomKey = "N_Sub07",
        features = { surfaceShop = true },
        reward = roomStoreReward("SubRoomRewards"),
    })

    lu.assertEquals(ephyra.hub.combatRoomsByKey.N_Combat01.sideDoors, {})
    lu.assertEquals(ephyra.hub.combatRoomsByKey.N_Combat17.reward, roomStoreReward("EasyHubRewards"))
    lu.assertEquals(ephyra.hub.combatRoomsByKey.N_Combat23.sideDoors[3].roomKey, "N_Sub15")
    lu.assertEquals(ephyra.hub.subroomRewardStores.N_Sub14, "SubRoomRewardsHard")
    lu.assertEquals(ephyra.hub.subroomRewardStores.N_Sub15, "SubRoomRewards")

    lu.assertEquals(ephyra.hub.minibossAvailability.mode, "oneOf")
    lu.assertEquals(ephyra.hub.minibossAvailability.rooms, { "N_MiniBoss01", "N_MiniBoss02" })
    lu.assertEquals(ephyra.hub.sideRoomAvailability.identity, "parentCombatRoomAndDoorId")
    lu.assertEquals(ephyra.hub.sideRoomAvailability.default, "")
end

function TestRunPlannerData.testFieldsLayoutModelsCageRoute()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local fields = biomes.lookup.H

    lu.assertEquals(fields.fields.routeCount.requiredBeforePreboss, 4)
    lu.assertEquals(fields.fields.routeCount.countedRooms, "CombatMinibossBridge")

    lu.assertEquals(#fields.fields.combatRooms, 15)
    lu.assertEquals(fields.fields.combatRoomsByKey.H_Combat01.maxCageRewards, 5)
    lu.assertEquals(fields.fields.combatRoomsByKey.H_Combat04.maxCageRewards, 4)
    lu.assertEquals(fields.fields.combatRoomsByKey.H_Combat13.maxCageRewards, 2)
    lu.assertEquals(fields.fields.combatRoomsByKey.H_Combat13.availability.biomeDepthCache, { max = 3 })

    lu.assertEquals(#fields.fields.minibossRooms, 2)
    lu.assertEquals(fields.fields.minibossRoomsByKey.H_MiniBoss01.encounter, "MiniBossVampire")
    lu.assertEquals(fields.fields.minibossRoomsByKey.H_MiniBoss02.encounter, "MiniBossLamia")

    lu.assertEquals(fields.rolesByKey.Bridge.roomOptions[1].key, "H_Bridge01")
    lu.assertEquals(fields.rolesByKey.Bridge.roomOptions[1].availability.biomeDepthCache, { exact = 3 })

    local cagePolicy = fields.fields.cageRewardPolicy
    lu.assertEquals(cagePolicy.rewardStore, "RunProgress")
    lu.assertEquals(cagePolicy.countControl.min, 2)
    lu.assertEquals(cagePolicy.countControl.max, 3)
    lu.assertEquals(cagePolicy.countControl.options[2].cageRewardCount, 2)
    lu.assertEquals(cagePolicy.countControl.options[3].cageRewardCount, 3)
    lu.assertEquals(cagePolicy.countControl.options[3].requiresAllOfferedRoomsSupport, 3)
    lu.assertEquals(cagePolicy.maxDoorDepthChanceTable[4], {
        maxDoorChance = 0.80,
        ceilingCheck = true,
    })
    lu.assertEquals(cagePolicy.locationModel, "VanillaRandomLootPoint")
end

function TestRunPlannerData.testThessalyCombatPolicyModelsShipEncounters()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local policy = biomes.lookup.O.combatEncounterPolicy

    lu.assertEquals(policy.key, "O_CombatData")
    lu.assertEquals(policy.countControl.default, "Vanilla")
    lu.assertEquals(policy.countControl.options[2].key, "TwoCombats")
    lu.assertEquals(policy.countControl.options[2].realCombatCount, 2)
    lu.assertEquals(policy.countControl.options[3].key, "ThreeCombats")
    lu.assertEquals(policy.countControl.options[3].realCombatCount, 3)
    lu.assertEquals(policy.countControl.options[3].availableAtBiomeEncounterDepth, { min = 2, max = 5 })

    lu.assertEquals(policy.legs[1].key, "Intro")
    lu.assertEquals(policy.legs[1].reward, noneReward())
    lu.assertFalse(policy.legs[1].hasReward)
    lu.assertFalse(policy.legs[1].countsForRoomEncounterDepth)
    lu.assertEquals(policy.legs[2].key, "Encounter1")
    lu.assertEquals(policy.legs[2].reward, majorMinorReward())
    lu.assertTrue(policy.legs[2].required)
    lu.assertEquals(policy.legs[3].key, "Encounter2")
    lu.assertEquals(policy.legs[3].reward, majorMinorReward())
    lu.assertEquals(policy.legs[3].vanillaChance, 0.6)
    lu.assertEquals(policy.legs[3].availableAtBiomeEncounterDepth, { min = 2, max = 5 })
end
