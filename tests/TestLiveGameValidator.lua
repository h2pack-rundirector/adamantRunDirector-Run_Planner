local lu = require("luaunit")

-- luacheck: globals TestRunPlannerLiveGameValidator
TestRunPlannerLiveGameValidator = {}

local function issueCodes(issues)
    local codes = {}
    for _, issue in ipairs(issues) do
        codes[issue.code] = true
    end
    return codes
end

local function validator()
    return dofile("src/mods/biomes/live_validator.lua")
end

local function rewardDomain()
    return {
        rewardStores = {
            RunProgress = {},
            HubRewards = {},
        },
        shops = {
            WorldShop = {},
        },
    }
end

local function featureDefinitions()
    return {
        byKey = {
            Well = {
                vanillaNamedRequirement = "WellShopRequirements",
            },
        },
    }
end

local function tinyCatalog()
    return {
        ordered = {
            {
                key = "X",
                slotLayout = {
                    entry = {
                        roomKey = "X_Intro",
                    },
                    special = {
                        [2] = {
                            roomOptions = {
                                { key = "X_PreBoss" },
                            },
                        },
                    },
                    fixedAfterRoute = {
                        {
                            roomKey = "X_AfterRoute",
                        },
                    },
                },
                timeline = {
                    afterBiome = {
                        {
                            roomKey = "X_PostBoss",
                        },
                    },
                },
                hub = {
                    roomKey = "X_Hub",
                    combatRooms = {
                        { key = "X_Combat01" },
                    },
                },
                roomTopology = {
                    hub = {
                        doorRooms = {
                            {
                                roomKey = "X_DoorRoom",
                            },
                        },
                    },
                },
                fields = {
                    minibossRooms = {
                        { key = "X_FieldMini" },
                    },
                },
                roles = {
                    {
                        key = "Combat",
                        mapOptions = {
                            {
                                key = "X_Combat01",
                                sideDoors = {
                                    {
                                        roomKey = "X_Sub01",
                                    },
                                },
                            },
                        },
                    },
                    {
                        key = "Story",
                        roomOptions = {
                            { key = "X_Story01" },
                        },
                    },
                },
            },
        },
    }
end

local function liveGame()
    return {
        RoomData = {
            BaseRoom = {
                WellShopRequirements = {},
            },
            X_AfterRoute = {},
            X_Combat01 = {},
            X_DoorRoom = {},
            X_FieldMini = {},
            X_Hub = {},
            X_Intro = {},
            X_PostBoss = {},
            X_PreBoss = {},
            X_Story01 = {},
            X_Sub01 = {},
        },
        RewardStoreData = {
            RunProgress = {},
            HubRewards = {},
        },
        StoreData = {
            WorldShop = {},
        },
    }
end

function TestRunPlannerLiveGameValidator.testLiveValidatorAcceptsMatchingGameTables()
    local issues = validator().validate(tinyCatalog(), {
        game = liveGame(),
        rewardDomain = rewardDomain(),
        featureDefinitions = featureDefinitions(),
    })

    lu.assertEquals(#issues, 0)
end

function TestRunPlannerLiveGameValidator.testLiveValidatorReportsGameDataDrift()
    local game = liveGame()
    game.RoomData.X_DoorRoom = nil
    game.RoomData.BaseRoom.WellShopRequirements = nil
    game.RewardStoreData.HubRewards = nil
    game.StoreData.WorldShop = nil

    local codes = issueCodes(validator().validate(tinyCatalog(), {
        game = game,
        rewardDomain = rewardDomain(),
        featureDefinitions = featureDefinitions(),
    }))

    lu.assertTrue(codes.missing_live_room)
    lu.assertTrue(codes.missing_live_reward_store)
    lu.assertTrue(codes.missing_live_shop)
    lu.assertTrue(codes.missing_live_feature_requirement)
end

function TestRunPlannerLiveGameValidator.testLogicAttachRunsLiveValidatorOnlyInDebugMode()
    local calls = 0
    local passedRewardDomain
    local domain = rewardDomain()
    local activationCallback
    local logic = assert(loadfile("src/mods/logic.lua"))({
        catalog = {},
        routePlan = {
            defineCache = function()
            end,
            registerHooks = function()
            end,
        },
        roomRouting = {
            registerHooks = function()
            end,
        },
        rewardRouting = {
            registerHooks = function()
            end,
        },
        npcRouting = {
            registerHooks = function()
            end,
        },
        featureRouting = {
            registerHooks = function()
            end,
        },
        liveGameValidator = {
            run = function(_, opts)
                calls = calls + 1
                passedRewardDomain = opts.rewardDomain
            end,
        },
        rewards = {
            rewardDomain = domain,
        },
    })
    logic.attach({
        cache = {
            define = function()
            end,
        },
        hooks = {
            wrap = function()
            end,
        },
        onActivate = function(callback)
            activationCallback = callback
        end,
    })

    activationCallback({}, {
        data = {
            read = function()
                return false
            end,
        },
    })
    lu.assertEquals(calls, 0)

    activationCallback({}, {
        data = {
            read = function(alias)
                return alias == "DebugMode"
            end,
        },
    })
    lu.assertEquals(calls, 1)
    lu.assertIs(passedRewardDomain, domain)
end
