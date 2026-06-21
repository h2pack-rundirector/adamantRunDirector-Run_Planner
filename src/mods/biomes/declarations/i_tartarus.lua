return function(importer, deps)
    local layout = importer("mods/biomes/declarations/i_tartarus_layout.lua")(importer, deps)
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules

    return {
        key = "I",
        label = "Tartarus",
        region = "Underworld",
        adapter = "clockworkGoal",
        timeline = parser.standardTimeline("I", {
            bossRooms = {
                { key = "I_Boss01", label = "Boss" },
            },
            postBossFeatures = { wellShop = true },
        }),
        featurePolicies = {
            wellShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            routeRowLabelPrefix = "Step",
            biomeDepthCacheStart = 1,
            defaultFixedBiomeDepthCacheCost = 0,
            routeBiomeDepthCacheCost = 1,
            routeStartOrdinal = 1,
            routeEndOrdinal = 12,
            fixedBeforeRoute = {
                {
                    key = "Intro",
                    label = "Intro",
                    isBiomeEntry = true,
                    roomKey = "I_Intro",
                    reward = rewards.none(),
                    biomeEncounterDepthCost = 0,
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
                    biomeEncounterDepthCost = 0,
                },
            },
        },
        clockwork = {
            requiredGoalRewards = 5,
            forcedFirstRouteRole = "Goal",
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
                reward = rewards.roomStore("ClockworkExtensionRewards"),
                countsNonGoalReward = true,
            },
            {
                key = "Story",
                label = "Story",
                roomOptions = layout.specialExtensionRooms.story,
                reward = rewards.none(),
                routeRules = routeRules.role("Story"),
                biomeEncounterDepthCost = 0,
                reserve = true,
            },
            {
                key = "Fountain",
                label = "Fountain",
                roomOptions = layout.specialExtensionRooms.fountain,
                reward = rewards.roomStore("TartarusRewards", { ineligibleRewardTypes = { "Devotion" } }),
                routeRules = routeRules.role("Fountain"),
                biomeEncounterDepthCost = 0,
                reserve = true,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.specialExtensionRooms.miniboss,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                requiresConcreteOption = true,
                routeRules = routeRules.role("Miniboss"),
                reserve = true,
            },
        },
    }
end
