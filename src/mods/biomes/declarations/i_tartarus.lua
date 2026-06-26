return function(deps)
    local goalCombatRole = "GoalCombat"
    local rewardCombatRole = "RewardCombat"
    local layout = import("mods/biomes/declarations/i_tartarus_layout.lua")(deps)
    local topology = import("mods/biomes/declarations/i_tartarus_topology.lua")({
        layout = layout,
        goalCombatRole = goalCombatRole,
        rewardCombatRole = rewardCombatRole,
    })
    local parser = deps.parser
    local rewards = deps.rewards

    return {
        key = "I",
        label = "Tartarus",
        region = "Underworld",
        adapter = "clockworkGoal",
        roomTopology = topology,
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
                    room = layout.introRoom,
                    reward = rewards.none(),
                    biomeEncounterDepthCost = 0,
                    locked = true,
                },
            },
            fixedAfterGoals = {
                {
                    key = "Preboss",
                    label = "Preboss Shop",
                    reward = rewards.shop("I_WorldShop"),
                    biomeEncounterDepthCost = 0,
                },
            },
        },
        clockwork = {
            forcedFirstRouteRole = goalCombatRole,
            routeCounters = {
                clockworkGoal = {
                    maxCreationsThisRun = 5,
                },
                clockworkNonGoalReward = {
                    maxCreationsThisRun = 6,
                },
            },
        },
        roles = {
            {
                key = goalCombatRole,
                label = "Goal",
                mapOptions = layout.combatRooms,
                reward = rewards.none(),
                increments = { clockworkGoal = 1 },
                npcRoleKeys = { "Combat" },
                targetKinds = { combatSlot = true },
                biomeEncounterDepthCost = 1,
            },
            {
                key = rewardCombatRole,
                label = "Reward Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.roomStore("TartarusRewards", { ineligibleRewardTypes = { "Boon" } }),
                increments = { clockworkNonGoalReward = 1 },
                requiresPrevious = { supportsExtensionChoice = true },
                npcRoleKeys = { "Combat" },
                targetKinds = { combatSlot = true },
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
