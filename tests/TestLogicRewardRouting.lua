local lu = require("luaunit")
local harness = require("tests.support.logic_harness")

-- luacheck: globals TestRunPlannerLogicRewardRouting
TestRunPlannerLogicRewardRouting = {}

local testImport = harness.testImport
local loadCatalog = harness.loadCatalog
local loadRoutePlan = harness.loadRoutePlan
local loadRewardRouting = harness.loadRewardRouting
local logsContain = harness.logsContain
local plannedBiomeSnapshot = harness.plannedBiomeSnapshot
local runtimeForCatalog = harness.runtimeForCatalog

local function prebossRewardOffers()
    local choiceGroup = {
        key = "prebossChoice",
        effectTiming = "sameChoiceUnion",
    }
    return {
        {
            address = "prebossShop",
            label = "Shop",
            kind = "shop",
            shopProfile = "WorldShop",
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
            ineligibleRewardTypes = {
                "Devotion",
                "RoomMoneyDrop",
            },
            rewardAliasStart = 4,
            rewardAliasCount = 2,
            rewardChoiceGroup = choiceGroup,
        },
    }
end

local function withShopGlobals(callback)
    local previousStoreData = _G.StoreData
    local previousConsumableData = _G.ConsumableData
    local previousGetProcessedValue = _G.GetProcessedValue
    _G.StoreData = {
        WorldShop = {
            GroupsOf = {
                {
                    OptionsData = {
                        { Name = "RandomLoot" },
                        { Name = "BlindBoxLoot" },
                        { Name = "ShopHermesUpgrade" },
                    },
                },
                {
                    OptionsData = {
                        { Name = "WeaponUpgradeDrop" },
                        { Name = "RoomRewardHealDrop" },
                        { Name = "MaxHealthDrop" },
                        { Name = "ArmorBoost" },
                    },
                },
                {
                    OptionsData = {
                        { Name = "MaxManaDrop" },
                        { Name = "StackUpgrade", Cost = 100 },
                        { Name = "StoreRewardRandomStack", Cost = 50 },
                        { Name = "SpellDrop" },
                        { Name = "TalentDrop" },
                    },
                },
            },
        },
    }
    _G.ConsumableData = {
        RandomLoot = {
            ResourceCosts = {
                Money = 125,
            },
        },
    }
    _G.GetProcessedValue = function(value, args, processedKey)
        lu.assertNil(args)
        lu.assertEquals(processedKey, "ResourceCosts")
        local copy = {}
        for key, amount in pairs(value) do
            copy[key] = amount
        end
        return copy
    end

    local ok, result = pcall(callback)
    _G.StoreData = previousStoreData
    _G.ConsumableData = previousConsumableData
    _G.GetProcessedValue = previousGetProcessedValue
    if not ok then
        error(result, 0)
    end
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingLogsPlannedRewardChoice()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local logs = {}
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "F_Combat01",
                roleKey = "Combat",
                optionKey = "F_Combat01",
                valid = true,
                rewardKind = "roomStore",
                rewards = { "Boon", "ZeusUpgrade" },
                rewardLoot = { "ZeusUpgrade" },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
        RewardPriorities = {},
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local baseCalled = false
    local rewardType = rewardRouting.chooseRoomReward(runtime, function(run, room, rewardStoreName, previouslyChosenRewards, args)
        baseCalled = true
        lu.assertIs(run, currentRun)
        lu.assertEquals(room.Name, "F_Combat01")
        lu.assertEquals(rewardStoreName, "RunProgress")
        lu.assertEquals(previouslyChosenRewards[1].RewardType, "MaxHealthDrop")
        lu.assertEquals(args.Marker, "test")
        return "Boon"
    end, currentRun, {
        Name = "F_Combat01",
        RoomSetName = "F",
    }, "RunProgress", {
        {
            RewardType = "MaxHealthDrop",
        },
    }, {
        Marker = "test",
    })

    lu.assertTrue(baseCalled)
    lu.assertEquals(rewardType, "Boon")
    lu.assertTrue(logsContain(logs, "choose set=F room=F_Combat01"))
    lu.assertTrue(logsContain(logs, "row=3"))
    lu.assertTrue(logsContain(logs, "planned=Boon"))
    lu.assertTrue(logsContain(logs, "actual=Boon"))
    lu.assertTrue(logsContain(logs, "action=forced"))
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingPrioritizesEphyraMainPylonReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        N = plannedBiomeSnapshot("N", "hubPylon", {
            {
                rowIndex = 4,
                routeOrdinal = 1,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_Combat02",
                roleKey = "Combat",
                optionKey = "N_Combat02",
                valid = true,
                rewardKind = "roomStore",
                rewardStore = "HubRewards",
                rewards = { "Boon", "HeraUpgrade" },
                rewardLoot = { "HeraUpgrade" },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            Name = "N_Hub",
            RoomSetName = "N",
        },
        BiomeDepthCache = 2,
        RewardPriorities = {
            "WeaponUpgrade",
        },
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "N",
    })

    local room = {
        Name = "N_Combat02",
        RoomSetName = "N",
    }
    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
        lu.assertEquals(currentRun.RewardPriorities[2], "WeaponUpgrade")
        return "Boon"
    end, currentRun, room, "HubRewards", {}, {
        Door = {
            ObjectId = 560725,
        },
    })

    lu.assertEquals(rewardType, "Boon")
    lu.assertEquals(room.ForceLootName, "HeraUpgrade")
    lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingPrioritizesEphyraSideRoomReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        N = plannedBiomeSnapshot("N", "hubPylon", {
            {
                rowIndex = 4,
                routeOrdinal = 1,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_Combat02",
                roleKey = "Combat",
                optionKey = "N_Combat02",
                valid = true,
                rewardKind = "roomStore",
                rewardStore = "HubRewards",
                rewards = { "Boon", "HeraUpgrade" },
                rewardLoot = { "HeraUpgrade" },
                sideRooms = {
                    {
                        sideIndex = 1,
                        doorId = 558353,
                        roomKey = "N_Sub01",
                        enabled = true,
                        modeKey = "Enabled",
                        rewardKind = "roomStore",
                        rewardStore = "SubRoomRewards",
                        rewards = { "RoomMoneyDrop" },
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            Name = "N_Combat02",
            RoomSetName = "N",
        },
        BiomeDepthCache = 2,
        RewardPriorities = {
            "RoomMoneyTinyDrop",
        },
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "N",
    })

    local room = {
        Name = "N_Sub01",
        RoomSetName = "N_SubRooms",
    }
    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "RoomMoneyDrop")
        lu.assertEquals(currentRun.RewardPriorities[2], "RoomMoneyTinyDrop")
        return "RoomMoneyDrop"
    end, currentRun, room, "SubRoomRewards", {}, {
        Door = {
            ObjectId = 558353,
        },
    })

    lu.assertEquals(rewardType, "RoomMoneyDrop")
    lu.assertEquals(currentRun.RewardPriorities[1], "RoomMoneyTinyDrop")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingLeavesUnmatchedEphyraSideRoomVanilla()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        N = plannedBiomeSnapshot("N", "hubPylon", {
            {
                rowIndex = 4,
                routeOrdinal = 1,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "N_Combat02",
                roleKey = "Combat",
                optionKey = "N_Combat02",
                valid = true,
                rewardKind = "roomStore",
                rewardStore = "HubRewards",
                rewards = { "Boon", "HeraUpgrade" },
                rewardLoot = { "HeraUpgrade" },
                sideRooms = {
                    {
                        sideIndex = 1,
                        doorId = 558353,
                        roomKey = "N_Sub01",
                        enabled = true,
                        modeKey = "Enabled",
                        rewardKind = "roomStore",
                        rewardStore = "SubRoomRewards",
                        rewards = { "RoomMoneyDrop" },
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            Name = "N_Combat02",
            RoomSetName = "N",
        },
        BiomeDepthCache = 2,
        RewardPriorities = {
            "RoomMoneyTinyDrop",
        },
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "N",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "RoomMoneyTinyDrop")
        return "RoomMoneyTinyDrop"
    end, currentRun, {
        Name = "N_Sub01",
        RoomSetName = "N_SubRooms",
    }, "SubRoomRewards", {}, {
        Door = {
            ObjectId = 558352,
        },
    })

    lu.assertEquals(rewardType, "RoomMoneyTinyDrop")
    lu.assertEquals(currentRun.RewardPriorities[1], "RoomMoneyTinyDrop")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingLogsSetupRewardContext()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local logs = {}
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "F_Combat01",
                roleKey = "Combat",
                optionKey = "F_Combat01",
                valid = true,
                rewardKind = "roomStore",
                rewards = { "Boon", "ZeusUpgrade" },
                rewardLoot = { "ZeusUpgrade" },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
    }
    local room = {
        Name = "F_Combat01",
        RoomSetName = "F",
        ChosenRewardType = "Boon",
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local result = rewardRouting.setupRoomReward(runtime, function()
        room.ForceLootName = "ZeusUpgrade"
        return "base-result"
    end, currentRun, room, {}, {})

    lu.assertEquals(result, "base-result")
    lu.assertTrue(logsContain(logs, "setup set=F room=F_Combat01"))
    lu.assertTrue(logsContain(logs, "row=3"))
    lu.assertTrue(logsContain(logs, "chosen=Boon"))
    lu.assertTrue(logsContain(logs, "loot=ZeusUpgrade"))
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingForcesLinearMinorRewardStore()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local logs = {}
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "F_Combat01",
                roleKey = "Combat",
                optionKey = "F_Combat01",
                valid = true,
                rewardKind = "majorMinor",
                rewards = { "Minor", "", "", "GiftDrop" },
                rewardPicks = {
                    {
                        key = "rewardType",
                        alias = "Reward4Key",
                        value = "GiftDrop",
                        rewardStore = "MetaProgress",
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local baseCalled = false
    local store = rewardRouting.chooseNextRewardStore(runtime, function()
        baseCalled = true
        return "RunProgress"
    end, currentRun)

    lu.assertFalse(baseCalled)
    lu.assertEquals(store, "MetaProgress")
    lu.assertEquals(currentRun.NextRewardStoreName, "MetaProgress")
    lu.assertTrue(logsContain(logs, "forced=MetaProgress"))
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingPrioritizesLinearRewardType()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "F_Combat01",
                roleKey = "Combat",
                optionKey = "F_Combat01",
                valid = true,
                rewardKind = "majorMinor",
                rewards = { "Major", "WeaponUpgrade" },
                rewardPicks = {
                    {
                        key = "rewardType",
                        alias = "Reward2Key",
                        value = "WeaponUpgrade",
                        rewardStore = "RunProgress",
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
        RewardPriorities = {
            "Boon",
        },
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
        lu.assertEquals(currentRun.RewardPriorities[2], "Boon")
        return "WeaponUpgrade"
    end, currentRun, {
        Name = "F_Combat01",
        RoomSetName = "F",
    }, "RunProgress", {}, {})

    lu.assertEquals(rewardType, "WeaponUpgrade")
    lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingForcesCompositePrebossRoomReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 12,
                routeOrdinal = 11,
                biomeDepthCache = 10,
                biomeDepthCacheCost = 0,
                slotKind = "preboss",
                roleKey = "Preboss",
                valid = true,
                rewardKind = "preboss",
                rewardOffers = prebossRewardOffers(),
                rewards = {
                    "RandomLoot",
                    "ArmorBoost",
                    "StackUpgrade",
                    "Boon",
                    "ZeusUpgrade",
                },
                rewardLoot = {
                    "DemeterUpgrade",
                },
                rewardPicks = {
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
                        value = "DemeterUpgrade",
                    },
                    {
                        key = "rewardType",
                        kind = "rewardType",
                        alias = "Reward4Key",
                        value = "Boon",
                        rewardStore = "RunProgress",
                    },
                    {
                        key = "boonSource",
                        kind = "boonSource",
                        alias = "Reward5Key",
                        value = "ZeusUpgrade",
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 10,
        RewardPriorities = {
            "WeaponUpgrade",
        },
    }
    local room = {
        Name = "F_PreBoss01",
        RoomSetName = "F",
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
        lu.assertEquals(currentRun.RewardPriorities[2], "WeaponUpgrade")
        return "Boon"
    end, currentRun, room, "RunProgress", {}, {})

    lu.assertEquals(rewardType, "Boon")
    lu.assertEquals(room.ForceLootName, "ZeusUpgrade")
    lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingDoesNotForcePrebossShopOfferAsRoomReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 12,
                routeOrdinal = 11,
                biomeDepthCache = 10,
                biomeDepthCacheCost = 0,
                slotKind = "preboss",
                roleKey = "Preboss",
                valid = true,
                rewardKind = "preboss",
                rewardOffers = prebossRewardOffers(),
                rewards = {
                    "RandomLoot",
                    "ArmorBoost",
                    "StackUpgrade",
                    "",
                    "",
                },
                rewardLoot = {
                    "DemeterUpgrade",
                },
                rewardPicks = {
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
                        value = "DemeterUpgrade",
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 10,
        RewardPriorities = {
            "WeaponUpgrade",
        },
    }
    local room = {
        Name = "F_PreBoss01",
        RoomSetName = "F",
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
        return "MaxHealthDrop"
    end, currentRun, room, "RunProgress", {}, {})

    lu.assertEquals(rewardType, "MaxHealthDrop")
    lu.assertNil(room.ForceLootName)
    lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingForcesPrebossShopOptions()
    withShopGlobals(function()
        local catalog = loadCatalog()
        local routePlan = loadRoutePlan()
        local rewardRouting = loadRewardRouting(routePlan, {
            print = function()
            end,
        })
        local runtime = runtimeForCatalog(routePlan, catalog, {
            F = plannedBiomeSnapshot("F", "fixedLinear", {
                {
                    rowIndex = 12,
                    routeOrdinal = 11,
                    biomeDepthCache = 10,
                    biomeDepthCacheCost = 0,
                    slotKind = "preboss",
                    roleKey = "Preboss",
                    valid = true,
                    rewardKind = "preboss",
                    rewardOffers = prebossRewardOffers(),
                    rewards = {
                        "RandomLoot",
                        "ArmorBoost",
                        "StoreRewardRandomStack",
                    },
                    rewardLoot = {
                        "DemeterUpgrade",
                    },
                    rewardPicks = {
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
                            value = "DemeterUpgrade",
                        },
                        {
                            key = "MajorNonBoon",
                            kind = "shopOption",
                            alias = "Reward2Key",
                            value = "ArmorBoost",
                        },
                        {
                            key = "Minor",
                            kind = "shopOption",
                            alias = "Reward3Key",
                            value = "StoreRewardRandomStack",
                        },
                    },
                },
            }),
        })
        local currentRun = {
            CurrentRoom = {
                Name = "F_PreBoss01",
                RoomSetName = "F",
                StoreDataName = "WorldShop",
            },
            BiomeDepthCache = 10,
        }
        routePlan.refresh(catalog, runtime, currentRun, {
            StartingBiome = "F",
        })

        local baseCalled = false
        local store = rewardRouting.fillInShopOptions(runtime, function(args)
            baseCalled = true
            lu.assertEquals(args.RoomName, "F_PreBoss01")
            return {
                StoreOptions = {
                    { Name = "BlindBoxLoot", Type = "Consumable" },
                    { Name = "MaxHealthDrop", Type = "Consumable" },
                    { Name = "MaxManaDrop", Type = "Consumable" },
                },
            }
        end, {
            RoomName = "F_PreBoss01",
            StoreData = _G.StoreData.WorldShop,
        }, currentRun)

        lu.assertTrue(baseCalled)
        lu.assertEquals(store.StoreOptions[1].Name, "RandomLoot")
        lu.assertEquals(store.StoreOptions[1].Type, "Boon")
        lu.assertEquals(store.StoreOptions[1].Args.ForceLootName, "DemeterUpgrade")
        lu.assertEquals(store.StoreOptions[1].Args.ResourceCosts.Money, 125)
        lu.assertEquals(store.StoreOptions[2].Name, "ArmorBoost")
        lu.assertEquals(store.StoreOptions[2].Type, "Consumable")
        lu.assertEquals(store.StoreOptions[3].Name, "StoreRewardRandomStack")
        lu.assertEquals(store.StoreOptions[3].Type, "Consumable")
        lu.assertEquals(store.StoreOptions[3].CostOverride, 50)
    end)
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingUsesCurrentRoomForPrebossShopWhenArgsRoomIsStale()
    withShopGlobals(function()
        local catalog = loadCatalog()
        local routePlan = loadRoutePlan()
        local logs = {}
        local rewardRouting = loadRewardRouting(routePlan, {
            print = function(text)
                logs[#logs + 1] = text
            end,
        })
        local runtime = runtimeForCatalog(routePlan, catalog, {
            F = plannedBiomeSnapshot("F", "fixedLinear", {
                {
                    rowIndex = 12,
                    routeOrdinal = 11,
                    biomeDepthCache = 10,
                    biomeDepthCacheCost = 0,
                    slotKind = "preboss",
                    roleKey = "Preboss",
                    valid = true,
                    rewardKind = "preboss",
                    rewardOffers = prebossRewardOffers(),
                    rewards = {
                        "RandomLoot",
                        "ArmorBoost",
                        "StoreRewardRandomStack",
                    },
                    rewardLoot = {
                        "DemeterUpgrade",
                    },
                    rewardPicks = {
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
                            value = "DemeterUpgrade",
                        },
                        {
                            key = "MajorNonBoon",
                            kind = "shopOption",
                            alias = "Reward2Key",
                            value = "ArmorBoost",
                        },
                        {
                            key = "Minor",
                            kind = "shopOption",
                            alias = "Reward3Key",
                            value = "StoreRewardRandomStack",
                        },
                    },
                },
            }),
        })
        local currentRun = {
            CurrentRoom = {
                Name = "F_PreBoss01",
                RoomSetName = "F",
                StoreDataName = "WorldShop",
            },
            BiomeDepthCache = 10,
        }
        routePlan.refresh(catalog, runtime, currentRun, {
            StartingBiome = "F",
        })

        local store = rewardRouting.fillInShopOptions(runtime, function(args)
            lu.assertEquals(args.RoomName, "F_Combat07")
            return {
                StoreOptions = {
                    { Name = "BlindBoxLoot", Type = "Consumable" },
                    { Name = "MaxHealthDrop", Type = "Consumable" },
                    { Name = "MaxManaDrop", Type = "Consumable" },
                },
            }
        end, {
            RoomName = "F_Combat07",
            StoreData = _G.StoreData.WorldShop,
        }, currentRun)

        lu.assertEquals(store.StoreOptions[1].Name, "RandomLoot")
        lu.assertEquals(store.StoreOptions[1].Args.ForceLootName, "DemeterUpgrade")
        lu.assertEquals(store.StoreOptions[2].Name, "ArmorBoost")
        lu.assertEquals(store.StoreOptions[3].Name, "StoreRewardRandomStack")
        lu.assertTrue(logsContain(logs, "shop set=F"))
        lu.assertTrue(logsContain(logs, "argsRoom=F_Combat07"))
    end)
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingLeavesUnplannedPrebossShopSlotsVanilla()
    withShopGlobals(function()
        local catalog = loadCatalog()
        local routePlan = loadRoutePlan()
        local rewardRouting = loadRewardRouting(routePlan, {
            print = function()
            end,
        })
        local runtime = runtimeForCatalog(routePlan, catalog, {
            F = plannedBiomeSnapshot("F", "fixedLinear", {
                {
                    rowIndex = 12,
                    routeOrdinal = 11,
                    biomeDepthCache = 10,
                    biomeDepthCacheCost = 0,
                    slotKind = "preboss",
                    roleKey = "Preboss",
                    valid = true,
                    rewardKind = "preboss",
                    rewardOffers = prebossRewardOffers(),
                    rewards = {
                        "",
                        "ArmorBoost",
                        "",
                    },
                    rewardPicks = {
                        {
                            key = "MajorNonBoon",
                            kind = "shopOption",
                            alias = "Reward2Key",
                            value = "ArmorBoost",
                        },
                    },
                },
            }),
        })
        local currentRun = {
            CurrentRoom = {
                Name = "F_PreBoss01",
                RoomSetName = "F",
                StoreDataName = "WorldShop",
            },
            BiomeDepthCache = 10,
        }
        routePlan.refresh(catalog, runtime, currentRun, {
            StartingBiome = "F",
        })

        local store = rewardRouting.fillInShopOptions(runtime, function()
            return {
                StoreOptions = {
                    { Name = "BlindBoxLoot", Type = "Consumable" },
                    { Name = "MaxHealthDrop", Type = "Consumable" },
                    { Name = "MaxManaDrop", Type = "Consumable" },
                },
            }
        end, {
            RoomName = "F_PreBoss01",
            StoreData = _G.StoreData.WorldShop,
        }, currentRun)

        lu.assertEquals(store.StoreOptions[1].Name, "BlindBoxLoot")
        lu.assertEquals(store.StoreOptions[2].Name, "ArmorBoost")
        lu.assertEquals(store.StoreOptions[3].Name, "MaxManaDrop")
    end)
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingRespectsPrebossShopRestockExclusions()
    withShopGlobals(function()
        local catalog = loadCatalog()
        local routePlan = loadRoutePlan()
        local rewardRouting = loadRewardRouting(routePlan, {
            print = function()
            end,
        })
        local runtime = runtimeForCatalog(routePlan, catalog, {
            F = plannedBiomeSnapshot("F", "fixedLinear", {
                {
                    rowIndex = 12,
                    routeOrdinal = 11,
                    biomeDepthCache = 10,
                    biomeDepthCacheCost = 0,
                    slotKind = "preboss",
                    roleKey = "Preboss",
                    valid = true,
                    rewardKind = "preboss",
                    rewardOffers = prebossRewardOffers(),
                    rewards = {
                        "RandomLoot",
                        "ArmorBoost",
                        "StoreRewardRandomStack",
                    },
                    rewardLoot = {
                        "DemeterUpgrade",
                    },
                    rewardPicks = {
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
                            value = "DemeterUpgrade",
                        },
                        {
                            key = "MajorNonBoon",
                            kind = "shopOption",
                            alias = "Reward2Key",
                            value = "ArmorBoost",
                        },
                        {
                            key = "Minor",
                            kind = "shopOption",
                            alias = "Reward3Key",
                            value = "StoreRewardRandomStack",
                        },
                    },
                },
            }),
        })
        local currentRun = {
            CurrentRoom = {
                Name = "F_PreBoss01",
                RoomSetName = "F",
                StoreDataName = "WorldShop",
            },
            BiomeDepthCache = 10,
        }
        routePlan.refresh(catalog, runtime, currentRun, {
            StartingBiome = "F",
        })

        local store = rewardRouting.fillInShopOptions(runtime, function()
            return {
                StoreOptions = {
                    { Name = "BlindBoxLoot", Type = "Consumable" },
                    { Name = "MaxHealthDrop", Type = "Consumable" },
                    { Name = "MaxManaDrop", Type = "Consumable" },
                },
            }
        end, {
            RoomName = "F_PreBoss01",
            StoreData = _G.StoreData.WorldShop,
            ExclusionNames = {
                "DemeterUpgrade",
                "ArmorBoost",
            },
        }, currentRun)

        lu.assertEquals(store.StoreOptions[1].Name, "BlindBoxLoot")
        lu.assertEquals(store.StoreOptions[2].Name, "MaxHealthDrop")
        lu.assertEquals(store.StoreOptions[3].Name, "StoreRewardRandomStack")
    end)
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingForcesLinearBoonSource()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = plannedBiomeSnapshot("F", "fixedLinear", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "F_Combat01",
                roleKey = "Combat",
                optionKey = "F_Combat01",
                valid = true,
                rewardKind = "majorMinor",
                rewards = { "Major", "Boon", "ZeusUpgrade" },
                rewardPicks = {
                    {
                        key = "rewardType",
                        alias = "Reward2Key",
                        value = "Boon",
                        rewardStore = "RunProgress",
                    },
                    {
                        key = "boonSource",
                        alias = "Reward3Key",
                        value = "ZeusUpgrade",
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
        RewardPriorities = {},
    }
    local room = {
        Name = "F_Combat01",
        RoomSetName = "F",
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        return "Boon"
    end, currentRun, room, "RunProgress", {}, {})

    lu.assertEquals(rewardType, "Boon")
    lu.assertEquals(room.ForceLootName, "ZeusUpgrade")
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingForcesLinearDevotionSources()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local executionPlan = testImport("mods/logic/execution_plan.lua")
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local biomeSnapshot = plannedBiomeSnapshot("G", "fixedLinear", {
        {
            rowIndex = 3,
            routeOrdinal = 2,
            biomeDepthCache = 1,
            biomeDepthCacheCost = 1,
            slotKind = "biomeRow",
            roomKey = "G_Combat01",
            roleKey = "Combat",
            optionKey = "G_Combat01",
            valid = true,
            rewardKind = "majorMinor",
            rewards = { "Major", "Devotion", "", "", "ZeusUpgrade", "HeraUpgrade" },
            rewardPicks = {
                {
                    key = "rewardType",
                    alias = "Reward2Key",
                    value = "Devotion",
                    rewardStore = "RunProgress",
                },
                {
                    key = "lootAName",
                    alias = "Reward5Key",
                    value = "ZeusUpgrade",
                },
                {
                    key = "lootBName",
                    alias = "Reward6Key",
                    value = "HeraUpgrade",
                },
            },
        },
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        G = biomeSnapshot,
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "G",
        },
        BiomeDepthCache = 1,
    }
    local room = {
        Name = "G_Combat01",
        RoomSetName = "G",
        ChosenRewardType = "Devotion",
    }
    routePlan.store(runtime, {
        active = true,
        valid = true,
        routeKey = "Underworld",
        executionPlan = executionPlan.compile({
            routeKey = "Underworld",
            biomes = {
                biomeSnapshot,
            },
        }, {
            layers = {
                rooms = true,
                rewards = true,
            },
        }),
    })

    rewardRouting.setupRoomReward(runtime, function()
        room.Encounter = {
            LootAName = "ApolloUpgrade",
            LootBName = "DemeterUpgrade",
        }
    end, currentRun, room, {}, {})

    lu.assertEquals(room.Encounter.LootAName, "ZeusUpgrade")
    lu.assertEquals(room.Encounter.LootBName, "HeraUpgrade")
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingDoesNotForceBoonSourceWhenRewardTypeDiffers()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local executionPlan = testImport("mods/logic/execution_plan.lua")
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local biomeSnapshot = plannedBiomeSnapshot("F", "fixedLinear", {
        {
            rowIndex = 3,
            routeOrdinal = 2,
            biomeDepthCache = 1,
            biomeDepthCacheCost = 1,
            slotKind = "biomeRow",
            roomKey = "F_Combat01",
            roleKey = "Combat",
            optionKey = "F_Combat01",
            valid = true,
            rewardKind = "majorMinor",
            rewards = { "Major", "Boon", "ZeusUpgrade" },
            rewardPicks = {
                {
                    key = "rewardType",
                    alias = "Reward2Key",
                    value = "Boon",
                    rewardStore = "RunProgress",
                },
                {
                    key = "boonSource",
                    alias = "Reward3Key",
                    value = "ZeusUpgrade",
                },
            },
        },
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        F = biomeSnapshot,
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "F",
        },
        BiomeDepthCache = 1,
    }
    local room = {
        Name = "F_Combat01",
        RoomSetName = "F",
        ChosenRewardType = "MaxHealthDrop",
    }
    routePlan.store(runtime, {
        active = true,
        valid = true,
        routeKey = "Underworld",
        executionPlan = executionPlan.compile({
            routeKey = "Underworld",
            biomes = {
                biomeSnapshot,
            },
        }, {
            layers = {
                rooms = true,
                rewards = true,
            },
        }),
    })

    rewardRouting.setupRoomReward(runtime, function()
    end, currentRun, room, {}, {})

    lu.assertNil(room.ForceLootName)
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingForcesThessalyEncounterRewardStore()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local logs = {}
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function(text)
            logs[#logs + 1] = text
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        O = plannedBiomeSnapshot("O", "multiEncounterFixed", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "O_Combat01",
                roleKey = "Combat",
                optionKey = "O_Combat01",
                valid = true,
                rewardKind = "none",
                encounterRewardLegs = {
                    {
                        legIndex = 1,
                        rewardKind = "majorMinor",
                        rewards = { "Minor", "", "", "GiftDrop" },
                        rewardPicks = {
                            {
                                key = "rewardType",
                                alias = "Reward4Key",
                                value = "GiftDrop",
                                rewardStore = "MetaProgress",
                            },
                        },
                    },
                },
            },
        }),
    })
    local encounter = {}
    local room = {
        Name = "O_Combat01",
        RoomSetName = "O",
        Encounters = {
            {},
            encounter,
        },
        Encounter = encounter,
    }
    local currentRun = {
        CurrentRoom = room,
        BiomeDepthCache = 1,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "O",
    })

    local baseCalled = false
    local store = rewardRouting.chooseNextRewardStore(runtime, function()
        baseCalled = true
        return "RunProgress"
    end, currentRun)

    lu.assertFalse(baseCalled)
    lu.assertEquals(store, "MetaProgress")
    lu.assertEquals(currentRun.NextRewardStoreName, "MetaProgress")
    lu.assertTrue(logsContain(logs, "store set=O"))
    lu.assertTrue(logsContain(logs, "forced=MetaProgress"))
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingFallsBackToThessalyRowRewardStoreOutsideShipEncounter()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        O = plannedBiomeSnapshot("O", "multiEncounterFixed", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "O_Reprieve01",
                roleKey = "Fountain",
                optionKey = "O_Reprieve01",
                valid = true,
                rewardKind = "majorMinor",
                rewards = { "Minor", "", "", "GiftDrop" },
                rewardPicks = {
                    {
                        key = "rewardType",
                        alias = "Reward4Key",
                        value = "GiftDrop",
                        rewardStore = "MetaProgress",
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            Name = "O_Combat01",
            RoomSetName = "O",
        },
        BiomeDepthCache = 1,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "O",
    })

    local store = rewardRouting.chooseNextRewardStore(runtime, function()
        return "RunProgress"
    end, currentRun)

    lu.assertEquals(store, "MetaProgress")
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingForcesFirstThessalyWheelReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        O = plannedBiomeSnapshot("O", "multiEncounterFixed", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "O_Combat01",
                roleKey = "Combat",
                optionKey = "O_Combat01",
                valid = true,
                rewardKind = "none",
                encounterRewardLegs = {
                    {
                        legIndex = 1,
                        rewardKind = "majorMinor",
                        rewards = { "Major", "Boon", "HeraUpgrade" },
                        rewardPicks = {
                            {
                                key = "rewardType",
                                alias = "Reward2Key",
                                value = "Boon",
                                rewardStore = "RunProgress",
                            },
                            {
                                key = "boonSource",
                                alias = "Reward3Key",
                                value = "HeraUpgrade",
                            },
                        },
                    },
                },
            },
        }),
    })
    local encounter = {}
    local room = {
        Name = "O_Combat01",
        RoomSetName = "O",
        Encounters = {
            {},
            encounter,
        },
        Encounter = encounter,
    }
    local currentRun = {
        CurrentRoom = room,
        BiomeDepthCache = 1,
        RewardPriorities = {
            "WeaponUpgrade",
        },
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "O",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
        lu.assertEquals(currentRun.RewardPriorities[2], "WeaponUpgrade")
        return "Boon"
    end, currentRun, room, "RunProgress", {}, {})

    lu.assertEquals(rewardType, "Boon")
    lu.assertEquals(room.ForceLootName, "HeraUpgrade")
    lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingDoesNotForceLaterThessalyWheelAlternatives()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        O = plannedBiomeSnapshot("O", "multiEncounterFixed", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "O_Combat01",
                roleKey = "Combat",
                optionKey = "O_Combat01",
                valid = true,
                rewardKind = "none",
                encounterRewardLegs = {
                    {
                        legIndex = 1,
                        rewardKind = "majorMinor",
                        rewards = { "Major", "Boon", "HeraUpgrade" },
                        rewardPicks = {
                            {
                                key = "rewardType",
                                alias = "Reward2Key",
                                value = "Boon",
                                rewardStore = "RunProgress",
                            },
                            {
                                key = "boonSource",
                                alias = "Reward3Key",
                                value = "HeraUpgrade",
                            },
                        },
                    },
                },
            },
        }),
    })
    local encounter = {}
    local room = {
        Name = "O_Combat01",
        RoomSetName = "O",
        Encounters = {
            {},
            encounter,
        },
        Encounter = encounter,
    }
    local currentRun = {
        CurrentRoom = room,
        BiomeDepthCache = 1,
        RewardPriorities = {
            "WeaponUpgrade",
        },
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "O",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
        return "Boon"
    end, currentRun, room, "RunProgress", {
        {
            RewardType = "MaxHealthDrop",
        },
    }, {})

    lu.assertEquals(rewardType, "Boon")
    lu.assertNil(room.ForceLootName)
    lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingPrioritizesTartarusGoalOnlyOnFirstReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        I = plannedBiomeSnapshot("I", "clockworkGoal", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "I_Combat01",
                roleKey = "Combat",
                optionKey = "I_Combat01",
                valid = true,
                rewardKind = "fixedReward",
                fixedRewardType = "ClockworkGoal",
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "I",
        },
        BiomeDepthCache = 1,
        RewardPriorities = {
            "Boon",
        },
    }
    local room = {
        Name = "I_Combat01",
        RoomSetName = "I",
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local firstRewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "ClockworkGoal")
        lu.assertEquals(currentRun.RewardPriorities[2], "Boon")
        return "ClockworkGoal"
    end, currentRun, room, "TartarusRewards", {}, {})

    lu.assertEquals(firstRewardType, "ClockworkGoal")
    lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
    lu.assertNil(currentRun.RewardPriorities[2])

    local secondRewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
        return "StackUpgradeTriple"
    end, currentRun, room, "TartarusRewards", {
        {
            RewardType = "ClockworkGoal",
        },
    }, {})

    lu.assertEquals(secondRewardType, "StackUpgradeTriple")
    lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingPrioritizesTartarusExtensionOnlyAfterGoalReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        I = plannedBiomeSnapshot("I", "clockworkGoal", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "I_Combat02",
                roleKey = "Combat",
                optionKey = "I_Combat02",
                valid = true,
                rewardKind = "roomStore",
                rewardStore = "TartarusRewards",
                rewards = { "StackUpgradeTriple" },
                rewardPicks = {
                    {
                        key = "rewardType",
                        alias = "Reward1Key",
                        value = "StackUpgradeTriple",
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "I",
        },
        BiomeDepthCache = 2,
        RewardPriorities = {
            "Boon",
        },
    }
    local room = {
        Name = "I_Combat02",
        RoomSetName = "I",
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local firstRewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
        return "ClockworkGoal"
    end, currentRun, room, "TartarusRewards", {}, {})

    lu.assertEquals(firstRewardType, "ClockworkGoal")
    lu.assertEquals(currentRun.RewardPriorities[1], "Boon")

    local secondRewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "StackUpgradeTriple")
        lu.assertEquals(currentRun.RewardPriorities[2], "Boon")
        return "StackUpgradeTriple"
    end, currentRun, room, "TartarusRewards", {
        {
            RewardType = "ClockworkGoal",
        },
    }, {})

    lu.assertEquals(secondRewardType, "StackUpgradeTriple")
    lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingKeepsTartarusExtensionStoreVanilla()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        I = plannedBiomeSnapshot("I", "clockworkGoal", {
            {
                rowIndex = 3,
                routeOrdinal = 2,
                biomeDepthCache = 2,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "I_Combat02",
                roleKey = "Combat",
                optionKey = "I_Combat02",
                valid = true,
                rewardKind = "roomStore",
                rewardStore = "TartarusRewards",
                rewards = { "StackUpgradeTriple" },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            Name = "I_Combat02",
            RoomSetName = "I",
        },
        BiomeDepthCache = 2,
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local baseCalled = false
    local store = rewardRouting.chooseNextRewardStore(runtime, function()
        baseCalled = true
        return "TartarusRewards"
    end, currentRun)

    lu.assertTrue(baseCalled)
    lu.assertEquals(store, "TartarusRewards")
    lu.assertNil(currentRun.NextRewardStoreName)
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingPrioritizesFirstFieldsCageReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        H = plannedBiomeSnapshot("H", "fieldsCageRoute", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "H_Combat01",
                roleKey = "Combat",
                optionKey = "H_Combat01",
                valid = true,
                rewardKind = "fieldsCages",
                rewardStore = "RunProgress",
                rewardSourceCount = 2,
                rewards = { "Boon", "WeaponUpgrade" },
                rewardLoot = { "HeraUpgrade" },
                rewardPicks = {
                    {
                        key = "Cage1",
                        alias = "Reward1Key",
                        value = "Boon",
                    },
                    {
                        key = "Cage1Loot",
                        alias = "Reward1LootKey",
                        value = "HeraUpgrade",
                    },
                    {
                        key = "Cage2",
                        alias = "Reward2Key",
                        value = "WeaponUpgrade",
                    },
                },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "H",
        },
        BiomeDepthCache = 1,
        RewardPriorities = {
            "WeaponUpgrade",
        },
    }
    local room = {
        Name = "H_Combat01",
        RoomSetName = "H",
        CageRewards = {},
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
        lu.assertEquals(currentRun.RewardPriorities[2], "WeaponUpgrade")
        return "Boon"
    end, currentRun, room, "RunProgress", {
        {
            RewardType = "MaxHealthDrop",
        },
    }, {})

    lu.assertEquals(rewardType, "Boon")
    lu.assertEquals(room.ForceLootName, "HeraUpgrade")
    lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingPrioritizesSecondFieldsCageReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        H = plannedBiomeSnapshot("H", "fieldsCageRoute", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "H_Combat01",
                roleKey = "Combat",
                optionKey = "H_Combat01",
                valid = true,
                rewardKind = "fieldsCages",
                rewardStore = "RunProgress",
                rewardSourceCount = 2,
                rewards = { "Boon", "WeaponUpgrade" },
                rewardLoot = { "HeraUpgrade" },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "H",
        },
        BiomeDepthCache = 1,
        RewardPriorities = {
            "Boon",
        },
    }
    local room = {
        Name = "H_Combat01",
        RoomSetName = "H",
        CageRewards = {
            {
                RewardType = "Boon",
                ForceLootName = "HeraUpgrade",
            },
        },
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
        lu.assertEquals(currentRun.RewardPriorities[2], "Boon")
        return "WeaponUpgrade"
    end, currentRun, room, "RunProgress", {
        {
            RewardType = "MaxHealthDrop",
        },
        {
            RewardType = "Boon",
            ForceLootName = "HeraUpgrade",
        },
    }, {})

    lu.assertEquals(rewardType, "WeaponUpgrade")
    lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
    lu.assertNil(currentRun.RewardPriorities[2])
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingDoesNotForceHiddenFieldsDoorReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        H = plannedBiomeSnapshot("H", "fieldsCageRoute", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "H_Combat01",
                roleKey = "Combat",
                optionKey = "H_Combat01",
                valid = true,
                rewardKind = "fieldsCages",
                rewardStore = "RunProgress",
                rewardSourceCount = 2,
                rewards = { "Boon", "WeaponUpgrade" },
                rewardLoot = { "HeraUpgrade" },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "H",
        },
        BiomeDepthCache = 1,
        RewardPriorities = {
            "WeaponUpgrade",
        },
    }
    local room = {
        Name = "H_Combat01",
        RoomSetName = "H",
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
        return "MaxHealthDrop"
    end, currentRun, room, "RunProgress", {}, {
        Door = {},
    })

    lu.assertEquals(rewardType, "MaxHealthDrop")
    lu.assertNil(room.ForceLootName)
    lu.assertEquals(currentRun.RewardPriorities[1], "WeaponUpgrade")
end

function TestRunPlannerLogicRewardRouting.testRewardRoutingDoesNotForceUnplannedFieldsCageReward()
    local catalog = loadCatalog()
    local routePlan = loadRoutePlan()
    local rewardRouting = loadRewardRouting(routePlan, {
        print = function()
        end,
    })
    local runtime = runtimeForCatalog(routePlan, catalog, {
        H = plannedBiomeSnapshot("H", "fieldsCageRoute", {
            {
                rowIndex = 2,
                routeOrdinal = 1,
                biomeDepthCache = 1,
                biomeDepthCacheCost = 1,
                slotKind = "biomeRow",
                roomKey = "H_Combat01",
                roleKey = "Combat",
                optionKey = "H_Combat01",
                valid = true,
                rewardKind = "fieldsCages",
                rewardStore = "RunProgress",
                rewardSourceCount = 2,
                rewards = { "Boon", "WeaponUpgrade" },
                rewardLoot = { "HeraUpgrade" },
            },
        }),
    })
    local currentRun = {
        CurrentRoom = {
            RoomSetName = "H",
        },
        BiomeDepthCache = 1,
        RewardPriorities = {
            "Boon",
        },
    }
    local room = {
        Name = "H_Combat01",
        RoomSetName = "H",
        CageRewards = {
            { RewardType = "Boon", ForceLootName = "HeraUpgrade" },
            { RewardType = "WeaponUpgrade" },
        },
    }
    routePlan.refresh(catalog, runtime, currentRun, {
        StartingBiome = "F",
    })

    local rewardType = rewardRouting.chooseRoomReward(runtime, function()
        lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
        return "StackUpgrade"
    end, currentRun, room, "RunProgress", room.CageRewards, {})

    lu.assertEquals(rewardType, "StackUpgrade")
    lu.assertEquals(currentRun.RewardPriorities[1], "Boon")
end
