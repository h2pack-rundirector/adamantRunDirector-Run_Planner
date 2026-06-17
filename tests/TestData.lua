local lu = require("luaunit")

-- luacheck: globals TestRunPlannerData
TestRunPlannerData = {}

local function findStorage(storage, alias)
    for _, node in ipairs(storage) do
        if node.alias == alias then
            return node
        end
    end
end

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

local DEVOTION_REQUIREMENT_LOOT_NAMES = {
    "AphroditeUpgrade",
    "ApolloUpgrade",
    "DemeterUpgrade",
    "HephaestusUpgrade",
    "HestiaUpgrade",
    "HeraUpgrade",
    "PoseidonUpgrade",
    "ZeusUpgrade",
}

local REWARD_SETS = {
    OpeningRoomBans = {
        "RoomMoneyDrop",
        "MaxHealthDrop",
        "MaxManaDrop",
    },
    HubCombatRoomEasyBans = {
        "WeaponUpgrade",
        "HermesUpgrade",
        "HephaestusUpgrade",
    },
    PreBossRoomBans = {
        "RoomMoneyDrop",
    },
    ClockworkExtensionCombatBans = {
        "Boon",
    },
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

local function majorMinorReward()
    return {
        kind = "majorMinor",
        majorRewardStore = "RunProgress",
        minorRewardStore = "MetaProgress",
    }
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

local function devotionRequirement()
    return {
        kind = "priorDistinctGodLoot",
        minDistinct = 2,
        countedLootNames = DEVOTION_REQUIREMENT_LOOT_NAMES,
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

local function devotionReward(opts)
    local reward = forcedReward("Devotion", opts)
    reward.pick = devotionPick()
    reward.routeRequirements = {
        devotionRequirement(),
        previousExitCountRequirement(),
    }
    return reward
end

local function shopReward(shopProfile)
    return {
        kind = "shop",
        shopProfile = shopProfile,
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
    return reward
end

local function fieldsBridgeReward()
    return {
        kind = "fieldsBridge",
        storyReward = "Story",
        shopReward = "Shop",
        shopProfile = "WorldShop",
    }
end

local function shipWheelReward()
    return {
        kind = "shipWheel",
        storeSource = "ChooseNextRewardStore",
        defaultRewardStore = "RunProgress",
    }
end

function TestRunPlannerData.testStorageDeclaresInitialPlannerControls()
    local data = dofile("src/mods/data.lua")
    local storage = data.buildStorage()

    lu.assertEquals(findStorage(storage, "RoomRoutingEnabled").type, "bool")
    lu.assertFalse(findStorage(storage, "RoomRoutingEnabled").default)
    lu.assertEquals(findStorage(storage, "RewardRoutingEnabled").type, "bool")
    lu.assertFalse(findStorage(storage, "RewardRoutingEnabled").default)
    lu.assertEquals(findStorage(storage, "PlanMode").default, "Prefer")
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

    lu.assertEquals(biomes.lookup.F.slotLayout.coordinate, "BiomeDepthCache")
    lu.assertEquals(biomes.lookup.F.slotLayout.depthRange, { min = 0, max = 10 })
    lu.assertEquals(biomes.lookup.F.slotLayout.routeStartDepth, 1)
    lu.assertEquals(biomes.lookup.F.slotLayout.routeEndDepth, 9)

    lu.assertEquals(biomes.lookup.G.slotLayout.depthRange, { min = 1, max = 8 })
    lu.assertEquals(biomes.lookup.G.slotLayout.routeStartDepth, 1)
    lu.assertEquals(biomes.lookup.G.slotLayout.routeEndDepth, 7)

    lu.assertEquals(biomes.lookup.H.adapter, "fieldsCageRoute")
    lu.assertEquals(biomes.lookup.H.slotLayout.coordinate, "FieldsRoutePick")
    lu.assertEquals(biomes.lookup.H.slotLayout.routeStartPick, 1)
    lu.assertEquals(biomes.lookup.H.slotLayout.routeEndPick, 4)

    lu.assertEquals(biomes.lookup.I.adapter, "clockworkGoal")
    lu.assertEquals(biomes.lookup.I.slotLayout.coordinate, "ClockworkGoalRoute")
    lu.assertEquals(biomes.lookup.I.slotLayout.routeStartRow, 1)
    lu.assertEquals(biomes.lookup.I.slotLayout.routeEndRow, 11)
    lu.assertEquals(biomes.lookup.I.slotLayout.requiredGoalRewards, 5)

    lu.assertEquals(biomes.lookup.N.adapter, "hubPylon")
    lu.assertEquals(biomes.lookup.N.slotLayout.coordinate, "SoulPylon")
    lu.assertEquals(biomes.lookup.N.slotLayout.routeStartPick, 1)
    lu.assertEquals(biomes.lookup.N.slotLayout.routeEndPick, 6)
    lu.assertEquals(biomes.lookup.N.slotLayout.requiredPylons, 6)

    lu.assertEquals(biomes.lookup.O.slotLayout.depthRange, { min = 1, max = 7 })
    lu.assertEquals(biomes.lookup.O.slotLayout.routeStartDepth, 1)
    lu.assertEquals(biomes.lookup.O.slotLayout.routeEndDepth, 6)

    lu.assertEquals(biomes.lookup.P.slotLayout.depthRange, { min = 1, max = 9 })
    lu.assertEquals(biomes.lookup.P.slotLayout.routeStartDepth, 1)
    lu.assertEquals(biomes.lookup.P.slotLayout.routeEndDepth, 8)

    lu.assertEquals(biomes.lookup.Q.slotLayout.depthRange, { min = 1, max = 7 })
    lu.assertEquals(biomes.lookup.Q.slotLayout.routeStartDepth, 1)
    lu.assertEquals(biomes.lookup.Q.slotLayout.routeEndDepth, 6)
end

function TestRunPlannerData.testRewardTypeMetadataSeparatesBoonHermesAndDevotion()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertEquals(biomes.rewardTypes.lookup.Boon.pick, boonSourcePick())
    lu.assertEquals(biomes.rewardTypes.lookup.HermesUpgrade.kind, "standaloneLoot")
    lu.assertNil(biomes.rewardTypes.lookup.HermesUpgrade.pick)
    lu.assertEquals(biomes.rewardTypes.lookup.Devotion.pick, devotionPick())
    lu.assertEquals(biomes.rewardTypes.lookup.Devotion.routeRequirements, {
        devotionRequirement(),
        previousExitCountRequirement(),
    })
end

function TestRunPlannerData.testBiomeDefinitionsDeclareDepthSpecials()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    local fOpening = biomes.lookup.F.slotLayout.special[0]
    lu.assertEquals(fOpening.kind, "opening")
    lu.assertEquals(fOpening.roomOptions[1].key, "F_Opening01")
    lu.assertTrue(fOpening.locked)

    local fPreboss = biomes.lookup.F.slotLayout.special[10]
    lu.assertEquals(fPreboss.roomKey, "F_PreBoss01")
    lu.assertEquals(fPreboss.branches[1].key, "Shop")
    lu.assertEquals(fPreboss.branches[1].reward, shopReward("WorldShop"))
    lu.assertEquals(fPreboss.branches[2].key, "MajorReward")
    lu.assertEquals(fPreboss.branches[2].reward, roomStoreReward("RunProgress", {
        ineligibleRewardTypes = REWARD_SETS.PreBossRoomBans,
    }))

    local gIntro = biomes.lookup.G.slotLayout.entry
    lu.assertEquals(gIntro.kind, "intro")
    lu.assertEquals(gIntro.roomKey, "G_Intro")
    lu.assertTrue(gIntro.locked)
    lu.assertNil(biomes.lookup.G.slotLayout.special[1])

    local gPreboss = biomes.lookup.G.slotLayout.special[8]
    lu.assertEquals(gPreboss.roomKey, "G_PreBoss01")
    lu.assertEquals(gPreboss.branches[1].reward, shopReward("WorldShop"))

    lu.assertEquals(biomes.lookup.H.slotLayout.fixedBeforeRoute[1].roomKey, "H_Intro")
    lu.assertEquals(biomes.lookup.H.slotLayout.fixedBeforeRoute[1].reward, noneReward())
    lu.assertEquals(biomes.lookup.H.slotLayout.fixedAfterRoute[1].roomKey, "H_PreBoss01")
    lu.assertEquals(biomes.lookup.H.slotLayout.fixedAfterRoute[1].reward, shopReward("WorldShop"))

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
    lu.assertEquals(pPreboss.branches[1].reward, shopReward("WorldShop"))

    local qIntro = biomes.lookup.Q.slotLayout.entry
    lu.assertEquals(qIntro.kind, "intro")
    lu.assertEquals(qIntro.roomKey, "Q_Intro")
    lu.assertTrue(qIntro.locked)
    lu.assertNil(biomes.lookup.Q.slotLayout.special[1])

    local qPreboss = biomes.lookup.Q.slotLayout.special[7]
    lu.assertEquals(qPreboss.roomKey, "Q_PreBoss01")
    lu.assertEquals(#qPreboss.branches, 1)
    lu.assertEquals(qPreboss.branches[1].key, "Shop")
    lu.assertEquals(qPreboss.branches[1].reward, shopReward("Q_WorldShop"))

    local oPreboss = biomes.lookup.O.slotLayout.special[7]
    lu.assertEquals(oPreboss.roomKey, "O_PreBoss01")
    lu.assertEquals(#oPreboss.branches, 1)
    lu.assertEquals(oPreboss.branches[1].key, "Shop")
    lu.assertEquals(oPreboss.branches[1].reward, shopReward("WorldShop"))
end

function TestRunPlannerData.testBiomeDefinitionsDeclareRoleCapabilities()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)

    lu.assertNotNil(biomes.lookup.F.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Combat.mapOptions[1].key, "F_Combat01")
    lu.assertEquals(biomes.lookup.F.rolesByKey.Combat.reward, majorMinorReward())
    lu.assertEquals(biomes.lookup.F.rolesByKey.Fountain.reward, majorMinorReward())
    assertOneShotRole(biomes.lookup.F.rolesByKey.Story)
    assertOneShotRole(biomes.lookup.F.rolesByKey.Fountain)
    assertOneShotRole(biomes.lookup.F.rolesByKey.Midshop)
    assertOneShotRole(biomes.lookup.F.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.F.rolesByKey.Trial.reward, devotionReward({ rewardStore = "RunProgress" }))
    lu.assertEquals(biomes.lookup.F.rolesByKey.Miniboss.roomOptions[1].key, "F_MiniBoss01")
    lu.assertEquals(biomes.lookup.F.rolesByKey.Miniboss.reward, roomStoreReward("RunProgress", {
        eligibleRewardTypes = { "Boon" },
    }))
    lu.assertEquals(biomes.lookup.F.rolesByKey.Miniboss.routeRules, oneShotRouteRules())

    lu.assertEquals(biomes.lookup.G.rolesByKey.Combat.reward, majorMinorReward())
    lu.assertEquals(biomes.lookup.G.rolesByKey.Fountain.reward, majorMinorReward())
    assertOneShotRole(biomes.lookup.G.rolesByKey.Story)
    assertOneShotRole(biomes.lookup.G.rolesByKey.Fountain)
    assertOneShotRole(biomes.lookup.G.rolesByKey.Midshop)
    assertOneShotRole(biomes.lookup.G.rolesByKey.Trial)

    lu.assertNil(biomes.lookup.P.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.P.rolesByKey.Combat.reward, majorMinorReward())
    lu.assertEquals(biomes.lookup.P.rolesByKey.Fountain.reward, majorMinorReward())
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
    lu.assertEquals(biomes.lookup.O.rolesByKey.Combat.reward, shipWheelReward())
    lu.assertEquals(biomes.lookup.O.rolesByKey.Combat.encounterPolicy, "O_CombatData")
    lu.assertEquals(biomes.lookup.O.rolesByKey.Fountain.reward, majorMinorReward())
    assertOneShotRole(biomes.lookup.O.rolesByKey.Story)
    assertOneShotRole(biomes.lookup.O.rolesByKey.Fountain)
    assertOneShotRole(biomes.lookup.O.rolesByKey.Midshop)
    assertOneShotRole(biomes.lookup.O.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.O.rolesByKey.Trial.roomOptions[1].key, "O_Devotion01")
    lu.assertEquals(biomes.lookup.O.rolesByKey.Trial.reward, devotionReward({ rewardStore = "RunProgress" }))
    lu.assertEquals(biomes.lookup.O.rolesByKey.Miniboss.roomOptions[2].key, "O_MiniBoss02")
    lu.assertEquals(biomes.lookup.O.rolesByKey.Miniboss.routeRules, oneShotRouteRules())

    lu.assertNil(biomes.lookup.H.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.H.rolesByKey.Combat.mapOptions[1].key, "H_Combat01")
    lu.assertEquals(biomes.lookup.H.rolesByKey.Combat.reward, fieldsCagesReward("RunProgress"))
    lu.assertEquals(biomes.lookup.H.rolesByKey.Miniboss.roomOptions[1].encounter, "MiniBossVampire")
    lu.assertEquals(biomes.lookup.H.rolesByKey.Miniboss.roomOptions[2].encounter, "MiniBossLamia")
    lu.assertEquals(biomes.lookup.H.rolesByKey.Miniboss.reward, roomStoreReward("RunProgress", {
        eligibleRewardTypes = { "Boon" },
    }))
    lu.assertEquals(biomes.lookup.H.rolesByKey.Miniboss.routeRules, oneShotRouteRules())
    lu.assertEquals(biomes.lookup.H.rolesByKey.Bridge.reward, fieldsBridgeReward())

    lu.assertEquals(biomes.lookup.I.rolesByKey.Goal.mapOptions[1].key, "I_Combat01")
    lu.assertEquals(biomes.lookup.I.rolesByKey.Goal.reward, forcedReward("ClockworkGoal"))
    lu.assertEquals(biomes.lookup.I.rolesByKey.ExtensionCombat.reward, roomStoreReward("TartarusRewards", {
        ineligibleRewardTypes = REWARD_SETS.ClockworkExtensionCombatBans,
    }))
    lu.assertEquals(biomes.lookup.I.rolesByKey.Trial.mapOptions[1].key, "I_Combat01")
    lu.assertEquals(biomes.lookup.I.rolesByKey.Trial.reward, devotionReward({ rewardStore = "TartarusRewards" }))
    assertOneShotRole(biomes.lookup.I.rolesByKey.Trial)
    lu.assertEquals(biomes.lookup.I.rolesByKey.Story.roomOptions[1].key, "I_Story01")
    assertOneShotRole(biomes.lookup.I.rolesByKey.Story)
    lu.assertEquals(biomes.lookup.I.rolesByKey.Fountain.roomOptions[1].key, "I_Reprieve01")
    lu.assertEquals(biomes.lookup.I.rolesByKey.Fountain.reward, roomStoreReward("TartarusRewards"))
    assertOneShotRole(biomes.lookup.I.rolesByKey.Fountain)
    lu.assertNil(biomes.lookup.I.rolesByKey.Midshop)
    lu.assertEquals(biomes.lookup.I.rolesByKey.Miniboss.roomOptions[2].key, "I_MiniBoss02")
    lu.assertEquals(biomes.lookup.I.rolesByKey.Miniboss.routeRules, oneShotRouteRules())

    lu.assertEquals(biomes.lookup.N.rolesByKey.Combat.mapOptions[1].key, "N_Combat01")
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
    lu.assertEquals(erebus.Story.roomOptions[1].availability.biomeDepth, { min = 4, max = 8 })
    lu.assertEquals(erebus.Story.roomOptions[1].exitCount, 2)
    lu.assertEquals(erebus.Midshop.roomOptions[1].availability.biomeDepth, { min = 4, max = 6 })
    lu.assertEquals(erebus.Midshop.routeRequirements, midshopRequirements())
    lu.assertEquals(erebus.Trial.mapOptions[1].key, "F_Combat05")
    lu.assertEquals(erebus.Trial.mapOptions[1].availability.biomeEncounterDepth, { min = 5 })
    lu.assertEquals(erebus.Trial.reward.routeRequirements[2], previousExitCountRequirement())
    lu.assertEquals(erebus.Miniboss.roomOptions[3].exitCount, 1)

    local oceanus = biomes.lookup.G.rolesByKey
    lu.assertEquals(oceanus.Combat.mapOptions[18].availability.biomeEncounterDepth, { max = 2 })
    lu.assertEquals(oceanus.Combat.mapOptions[18].availability.biomeDepth, { max = 3 })
    lu.assertEquals(oceanus.Combat.mapOptions[18].exitCount, 3)
    lu.assertEquals(oceanus.Story.roomOptions[1].availability.biomeDepth, { min = 3, max = 6 })
    lu.assertEquals(oceanus.Story.roomOptions[1].exitCount, 1)
    lu.assertEquals(oceanus.Midshop.roomOptions[1].availability.biomeDepth, { min = 3, max = 5 })
    lu.assertEquals(oceanus.Midshop.routeRequirements, midshopRequirements())
    lu.assertEquals(oceanus.Trial.mapOptions[2].availability.biomeEncounterDepth, { min = 3 })
    lu.assertEquals(oceanus.Trial.reward.routeRequirements[2], previousExitCountRequirement())
    lu.assertEquals(oceanus.Miniboss.roomOptions[2].exitCount, 1)

    local fields = biomes.lookup.H.rolesByKey
    lu.assertEquals(fields.Combat.mapOptions[1].maxCageRewards, 5)
    lu.assertEquals(fields.Combat.mapOptions[4].maxCageRewards, 4)
    lu.assertEquals(fields.Combat.mapOptions[9].maxCageRewards, 2)
    lu.assertEquals(fields.Combat.mapOptions[9].availability.biomeDepth, { max = 3 })
    lu.assertEquals(fields.Combat.mapOptions[15].availability.biomeDepth, { max = 3 })
    lu.assertEquals(fields.Miniboss.roomOptions[1].availability.biomeDepth, { min = 2, max = 4 })
    lu.assertEquals(fields.Miniboss.routeRules, oneShotRouteRules())
    lu.assertEquals(fields.Bridge.roomOptions[1].availability.priorCombatOrMinibossRooms, { exact = 2 })

    local thessaly = biomes.lookup.O.rolesByKey
    lu.assertEquals(thessaly.Combat.mapOptions[13].availability.biomeDepth, { min = 6 })
    lu.assertEquals(thessaly.Combat.mapOptions[13].availability.requiresGeneratedIntroEncounters, 3)
    lu.assertEquals(thessaly.Story.roomOptions[1].availability.biomeEncounterDepth, { minExclusive = 3 })
    lu.assertEquals(thessaly.Fountain.roomOptions[1].availability.biomeDepth, { min = 3, max = 5 })
    lu.assertEquals(thessaly.Trial.roomOptions[1].availability.biomeEncounterDepth, { min = 2 })
    lu.assertEquals(thessaly.Miniboss.routeRules, oneShotRouteRules())

    local olympus = biomes.lookup.P.rolesByKey
    lu.assertEquals(olympus.Combat.mapOptions[1].availability.biomeEncounterDepth, { min = 3 })
    lu.assertEquals(olympus.Combat.mapOptions[3].availability.biomeEncounterDepth, { max = 4 })
    lu.assertEquals(olympus.Story.roomOptions[1].availability.biomeEncounterDepth, { minExclusive = 2 })
    lu.assertEquals(olympus.Midshop.roomOptions[1].availability.biomeEncounterDepth, { minExclusive = 4 })
    lu.assertEquals(olympus.Miniboss.roomOptions[1].availability.biomeDepth, { min = 4, max = 7 })
    lu.assertTrue(olympus.Miniboss.roomOptions[1].availability.requiresMultipleOfferedDoors)

    local summit = biomes.lookup.Q.rolesByKey
    lu.assertEquals(summit.Combat.mapOptions[10].availability.biomeDepth, { exact = 1 })
    lu.assertEquals(summit.Combat.mapOptions[12].availability.biomeDepth, { exact = 5 })
    lu.assertEquals(summit.Miniboss.roomOptions[1].key, "Q_MiniBoss02")
    lu.assertEquals(summit.Miniboss.roomOptions[1].availability.biomeDepth, { exact = 3 })
    lu.assertEquals(summit.Miniboss.roomOptions[4].availability.biomeDepth, { exact = 3 })
end

function TestRunPlannerData.testTartarusClockworkLayoutModelsGoalRoute()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local tartarus = biomes.lookup.I

    lu.assertEquals(tartarus.slotLayout.fixedBeforeRoute[1].roomKey, "I_Intro")
    lu.assertEquals(tartarus.slotLayout.fixedBeforeRoute[1].reward, roomStoreReward("RunProgress", {
        ineligibleRewardTypes = REWARD_SETS.OpeningRoomBans,
    }))
    lu.assertEquals(tartarus.slotLayout.fixedAfterGoals[1].roomOptions[1].key, "I_PreBoss01")
    lu.assertEquals(tartarus.slotLayout.fixedAfterGoals[1].roomOptions[2].key, "I_PreBoss02")
    lu.assertEquals(tartarus.slotLayout.fixedAfterGoals[1].reward, shopReward("I_WorldShop"))

    lu.assertEquals(tartarus.clockwork.requiredGoalRewards, 5)
    lu.assertEquals(tartarus.clockwork.maxRouteRows, 11)
    lu.assertEquals(tartarus.clockwork.goalReward, "ClockworkGoal")
    lu.assertEquals(tartarus.clockwork.remainingGoalCounter, "RemainingClockworkGoals")
    lu.assertEquals(tartarus.clockwork.extensionRewardBudget, {
        mode = "Vanilla",
        min = 3,
        max = 6,
        counter = "BiomeRewardsSpawned",
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
    lu.assertEquals(tartarus.clockwork.extensionRoom.combatOptions[1].reward, roomStoreReward("TartarusRewards", {
        ineligibleRewardTypes = REWARD_SETS.ClockworkExtensionCombatBans,
    }))

    local combat24 = tartarus.clockwork.goalRoom.roomOptions[24]
    lu.assertEquals(combat24.key, "I_Combat24")
    lu.assertEquals(combat24.availability.biomeDepth, { max = 5 })

    lu.assertEquals(tartarus.clockwork.extensionRoom.combatOptions[1].key, "I_Combat01")
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.story[1].key, "I_Story01")
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.story[1].reward, noneReward())
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.story[1].countsNonGoalReward, false)
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.story[1].exitCount, 1)
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.fountain[1].key, "I_Reprieve01")
    lu.assertEquals(
        tartarus.clockwork.extensionRoom.specialOptions.fountain[1].reward,
        roomStoreReward("TartarusRewards")
    )
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.fountain[1].countsNonGoalReward, true)
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.fountain[1].exitCount, 2)
    lu.assertNil(tartarus.clockwork.extensionRoom.specialOptions.shop)
    lu.assertEquals(tartarus.clockwork.extensionRoom.specialOptions.miniboss[2].exitCount, 2)
    lu.assertTrue(tartarus.clockwork.extensionRoom.specialOptions.miniboss[2].supportsExtensionChoice)
end

function TestRunPlannerData.testEphyraHubLayoutModelsPylonRoute()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local ephyra = biomes.lookup.N

    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[1].roomKey, "N_Opening01")
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[1].reward, roomStoreReward("RunProgress", {
        ineligibleRewardTypes = REWARD_SETS.OpeningRoomBans,
    }))
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[2].roomKey, "N_PreHub01")
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[2].reward, roomStoreReward("RunProgress", {
        ineligibleRewardTypes = REWARD_SETS.OpeningRoomBans,
    }))
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[3].roomKey, "N_Hub")
    lu.assertEquals(ephyra.slotLayout.fixedBeforeHub[3].reward, noneReward())
    lu.assertEquals(ephyra.slotLayout.fixedAfterHub[1].roomKey, "N_PreBoss01")
    lu.assertEquals(ephyra.slotLayout.fixedAfterHub[1].reward, shopReward("WorldShop"))

    lu.assertEquals(ephyra.hub.roomKey, "N_Hub")
    lu.assertEquals(ephyra.hub.requiredPylons, 6)
    lu.assertEquals(ephyra.hub.availableDoorCount, { min = 9, max = 10 })
    lu.assertEquals(#ephyra.hub.combatRooms, 23)
    lu.assertEquals(#ephyra.hub.hubDoorRooms, 26)

    local combat12 = ephyra.hub.combatRoomsByKey.N_Combat12
    lu.assertEquals(combat12.hubDoorId, 561389)
    lu.assertEquals(combat12.reward, roomStoreReward("HubRewards", {
        ineligibleRewardTypes = REWARD_SETS.HubCombatRoomEasyBans,
    }))
    lu.assertEquals(#combat12.sideDoors, 3)
    lu.assertEquals(combat12.sideDoors[1], {
        doorId = 558352,
        roomKey = "N_Sub09",
        reward = roomStoreReward("SubRoomRewardsHard"),
    })
    lu.assertEquals(combat12.sideDoors[3], {
        doorId = 566545,
        roomKey = "N_Sub07",
        reward = roomStoreReward("SubRoomRewards"),
    })

    lu.assertEquals(ephyra.hub.combatRoomsByKey.N_Combat01.sideDoors, {})
    lu.assertEquals(ephyra.hub.combatRoomsByKey.N_Combat17.reward, roomStoreReward("HubRewards", {
        ineligibleRewardTypes = REWARD_SETS.HubCombatRoomEasyBans,
    }))
    lu.assertEquals(ephyra.hub.combatRoomsByKey.N_Combat23.sideDoors[3].roomKey, "N_Sub15")
    lu.assertEquals(ephyra.hub.subroomRewardStores.N_Sub14, "SubRoomRewardsHard")
    lu.assertEquals(ephyra.hub.subroomRewardStores.N_Sub15, "SubRoomRewards")

    lu.assertEquals(ephyra.hub.minibossAvailability.mode, "oneOf")
    lu.assertEquals(ephyra.hub.minibossAvailability.rooms, { "N_MiniBoss01", "N_MiniBoss02" })
    lu.assertEquals(ephyra.hub.sideRoomAvailability.identity, "parentCombatRoomAndDoorId")
    lu.assertEquals(ephyra.hub.sideRoomAvailability.default, "Vanilla")
end

function TestRunPlannerData.testFieldsLayoutModelsCageRoute()
    local data = dofile("src/mods/data.lua")
    local biomes = data.loadBiomes(testImport)
    local fields = biomes.lookup.H

    lu.assertEquals(fields.fields.routePicks, 4)
    lu.assertEquals(fields.fields.routeCount.requiredBeforePreboss, 4)
    lu.assertEquals(fields.fields.routeCount.countedRooms, "CombatMinibossBridge")

    lu.assertEquals(#fields.fields.combatRooms, 15)
    lu.assertEquals(fields.fields.combatRoomsByKey.H_Combat01.maxCageRewards, 5)
    lu.assertEquals(fields.fields.combatRoomsByKey.H_Combat04.maxCageRewards, 4)
    lu.assertEquals(fields.fields.combatRoomsByKey.H_Combat13.maxCageRewards, 2)
    lu.assertEquals(fields.fields.combatRoomsByKey.H_Combat13.availability.biomeDepth, { max = 3 })

    lu.assertEquals(#fields.fields.minibossRooms, 2)
    lu.assertEquals(fields.fields.minibossRoomsByKey.H_MiniBoss01.encounter, "MiniBossVampire")
    lu.assertEquals(fields.fields.minibossRoomsByKey.H_MiniBoss02.encounter, "MiniBossLamia")

    lu.assertEquals(fields.fields.bridge.roomKey, "H_Bridge01")
    lu.assertEquals(fields.fields.bridge.roomOptions[1].availability.priorCombatOrMinibossRooms, { exact = 2 })
    lu.assertEquals(fields.fields.bridge.rewardModes[2].key, "Shop")
    lu.assertEquals(fields.fields.bridge.rewardModes[3].key, "Story")
    lu.assertEquals(fields.fields.bridge.rewardModes[4].key, "Nemesis")

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
    lu.assertEquals(policy.legs[2].key, "Combat1")
    lu.assertEquals(policy.legs[2].reward, shipWheelReward())
    lu.assertTrue(policy.legs[2].required)
    lu.assertEquals(policy.legs[3].key, "Combat2")
    lu.assertEquals(policy.legs[3].reward, shipWheelReward())
    lu.assertEquals(policy.legs[3].vanillaChance, 0.6)
    lu.assertEquals(policy.legs[3].availableAtBiomeEncounterDepth, { min = 2, max = 5 })
end

function TestRunPlannerData.testPlanModesExposePreferenceAndStrictMode()
    local data = dofile("src/mods/data.lua")

    lu.assertEquals(data.PLAN_MODE_VALUES, { "Prefer", "Strict" })
end
