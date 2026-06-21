return function(importer, deps)
    local layout = importer("mods/biomes/declarations/h_fields_layout.lua")()
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
                    key = "Preboss",
                    label = "Preboss Shop",
                    roomKey = layout.prebossRoom.key,
                    reward = rewards.shop("WorldShop"),
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
            bridge = layout.bridge,
            cageRewardPolicy = layout.cageRewardPolicy,
            offerPolicy = "H_FieldsCage",
        },
        roles = {
            {
                key = "Vanilla",
                label = "Vanilla",
                reward = rewards.none(),
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.fieldsCages({
                    rewardStore = "RunProgress",
                    ineligibleRewardTypes = { "Devotion" },
                }),
                cageRewardPolicy = "H_FieldsCageRewards",
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
                reward = rewards.fieldsBridge(),
                biomeEncounterDepthCost = 0,
                reserve = true,
            },
        },
    }
end
