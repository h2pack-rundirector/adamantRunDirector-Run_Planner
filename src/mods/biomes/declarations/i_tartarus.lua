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
            forcedFirstRouteRole = "Goal",
            routeCounters = {
                clockworkGoal = {
                    maxCreationsThisRun = 5,
                },
                clockworkNonGoalReward = {
                    maxCreationsThisRun = 6,
                },
            },
            goalRoom = {
                roomOptions = layout.combatRooms,
                reward = rewards.forcedReward("ClockworkGoal"),
                increments = { clockworkGoal = 1 },
            },
            extensionRoom = {
                combatOptions = layout.combatRooms,
                specialOptions = layout.specialExtensionRooms,
            },
        },
        roles = {
            {
                key = "Vanilla",
                label = "Vanilla",
                reward = rewards.none(),
                biomeEncounterDepthCost = routeRules.encounterDepthCost(0, 1),
            },
            {
                key = "Goal",
                label = "Goal Room",
                mapOptions = layout.combatRooms,
                reward = rewards.forcedReward("ClockworkGoal"),
                increments = { clockworkGoal = 1 },
                biomeEncounterDepthCost = 1,
            },
            {
                key = "ExtensionCombat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.roomStore("ClockworkExtensionRewards"),
                increments = { clockworkNonGoalReward = 1 },
                requiresPrevious = { supportsExtensionChoice = true },
                biomeEncounterDepthCost = 1,
            },
            {
                key = "Story",
                label = "Story",
                roomOptions = layout.specialExtensionRooms.story,
                reward = rewards.none(),
                increments = { clockworkStory = 1 },
                maxCreationsThisRun = 1,
                requiresPrevious = { supportsExtensionChoice = true },
                biomeEncounterDepthCost = 0,
                reserve = true,
            },
            {
                key = "Fountain",
                label = "Fountain",
                roomOptions = layout.specialExtensionRooms.fountain,
                reward = rewards.roomStore("TartarusRewards", { ineligibleRewardTypes = { "Devotion" } }),
                increments = { clockworkNonGoalReward = 1 },
                maxCreationsThisRun = 1,
                requiresPrevious = { supportsExtensionChoice = true },
                biomeEncounterDepthCost = 0,
                reserve = true,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.specialExtensionRooms.miniboss,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                requiresConcreteOption = true,
                increments = { clockworkNonGoalReward = 1 },
                maxCreationsThisRun = 1,
                requiresPrevious = { supportsExtensionChoice = true },
                reserve = true,
            },
        },
    }
end
