return function(importer)
    local layout = importer("mods/data/biomes/i_tartarus_layout.lua")(importer)
    local rewards = importer("mods/data/rewards.lua")(importer)
    local routeRules = importer("mods/data/route_rules.lua")

    return {
        key = "I",
        label = "Tartarus",
        region = "Underworld",
        adapter = "clockworkGoal",
        slotLayout = {
            coordinate = "ClockworkGoalRoute",
            routeStartRow = 1,
            routeEndRow = 11,
            requiredGoalRewards = 5,
            maxRouteRows = 11,
            default = {
                kind = "goal",
                alternate = "VanillaSafe",
            },
            fixedBeforeRoute = {
                {
                    key = "Intro",
                    label = "Intro",
                    roomKey = "I_Intro",
                    reward = rewards.roomStore("RunProgress", {
                        ineligibleRewardTypes = rewards.rewardSet("OpeningRoomBans"),
                    }),
                    locked = true,
                },
            },
            fixedAfterGoals = {
                {
                    key = "Preboss",
                    label = "Preboss Shop",
                    roomOptions = {
                        { key = "I_PreBoss01", label = "Chronos Shop" },
                        { key = "I_PreBoss02", label = "Chronos Shop Restored" },
                    },
                    reward = rewards.shop("I_WorldShop"),
                },
            },
        },
        clockwork = {
            requiredGoalRewards = 5,
            maxRouteRows = 11,
            goalReward = "ClockworkGoal",
            remainingGoalCounter = "RemainingClockworkGoals",
            extensionRewardBudget = {
                mode = "Vanilla",
                min = 3,
                max = 6,
                counter = "BiomeRewardsSpawned",
            },
            extensionChoice = {
                default = false,
                requiresPreviousRoomSupportsExtensionChoice = true,
            },
            goalRoom = {
                roomOptions = layout.combatRooms,
                reward = rewards.forcedReward("ClockworkGoal"),
                countsGoalReward = true,
                countsNonGoalReward = false,
            },
            extensionRoom = {
                combatOptions = layout.combatRooms,
                specialOptions = layout.specialExtensionRooms,
                countsGoalReward = false,
            },
        },
        roles = {
            {
                key = "Vanilla",
                label = "Vanilla",
                reward = rewards.none(),
            },
            {
                key = "Goal",
                label = "Clockwork Goal",
                mapOptions = layout.combatRooms,
                reward = rewards.forcedReward("ClockworkGoal"),
                countsGoalReward = true,
            },
            {
                key = "ExtensionCombat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.roomStore("TartarusRewards", {
                    ineligibleRewardTypes = rewards.rewardSet("ClockworkExtensionCombatBans"),
                }),
                countsNonGoalReward = true,
            },
            {
                key = "Trial",
                label = "Trial",
                mapOptions = layout.combatRooms,
                reward = rewards.devotion({ rewardStore = "TartarusRewards" }),
                routeRules = routeRules.role("Trial"),
                countsNonGoalReward = true,
                reserve = true,
            },
            {
                key = "Story",
                label = "Story",
                roomOptions = layout.specialExtensionRooms.story,
                reward = rewards.none(),
                routeRules = routeRules.role("Story"),
                reserve = true,
            },
            {
                key = "Fountain",
                label = "Fountain",
                roomOptions = layout.specialExtensionRooms.fountain,
                reward = rewards.roomStore("TartarusRewards"),
                routeRules = routeRules.role("Fountain"),
                reserve = true,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.specialExtensionRooms.miniboss,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                routeRules = routeRules.role("Miniboss"),
                reserve = true,
            },
        },
    }
end
