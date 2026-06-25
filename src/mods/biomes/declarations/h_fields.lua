return function(deps)
    local layout = import("mods/biomes/declarations/h_fields_layout.lua")()
    local rewardLayout = import("mods/biomes/declarations/h_fields_rewards.lua")(deps)
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules

    return {
        key = "H",
        label = "Fields",
        region = "Underworld",
        adapter = "fieldsCageRoute",
        timeline = parser.standardTimeline("H", {
            postBossFeatures = { wellShop = true },
        }),
        featurePolicies = {
            wellShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            routeRowLabelPrefix = "Pick",
            biomeDepthCacheStart = 1,
            defaultFixedBiomeDepthCacheCost = 0,
            routeBiomeDepthCacheCost = 1,
            routeStartOrdinal = 1,
            routeEndOrdinal = 4,
            fixedBeforeRoute = {
                {
                    key = "Intro",
                    label = "Intro",
                    isBiomeEntry = true,
                    roomKey = layout.introRoom.key,
                    reward = rewards.none(),
                    biomeEncounterDepthCost = 0,
                    locked = true,
                },
            },
            fixedAfterRoute = {
                {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss",
                    roomKey = layout.prebossRoom.key,
                    reward = rewards.preboss("WorldShop", "RunProgress", {
                        ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
                    }),
                    biomeEncounterDepthCost = 0,
                },
            },
        },
        fields = {
            routeCount = {
                counter = "RoomsEntered",
                requiredBeforePreboss = 4,
                countedRooms = "CombatMinibossBridge",
            },
            combatRooms = layout.combatRooms,
            combatRoomsByKey = layout.combatRoomsByKey,
            minibossRooms = layout.minibossRooms,
            minibossRoomsByKey = layout.minibossRoomsByKey,
            cageRewardPolicy = layout.cageRewardPolicy,
            offerTopology = layout.offerTopology,
        },
        roles = {
            {
                key = "Vanilla",
                label = "Vanilla",
                reward = rewards.none(),
                biomeEncounterDepthCost = routeRules.encounterDepthCost(0, 1),
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewardLayout.combatCages,
                cageRewardPolicy = "H_FieldsCageRewards",
                biomeEncounterDepthCost = 1,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                requiresConcreteOption = true,
                routeRules = routeRules.role("Miniboss"),
                reserve = true,
            },
            {
                key = "Bridge",
                label = "Echo",
                roomOptions = { layout.bridgeRoom },
                reward = rewards.none(),
                biomeEncounterDepthCost = 0,
                reserve = true,
            },
        },
    }
end
