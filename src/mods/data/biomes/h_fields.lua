return function(importer)
    local layout = importer("mods/data/biomes/h_fields_layout.lua")()
    local timeline = importer("mods/data/biomes/timeline.lua")
    local rewards = importer("mods/data/rewards.lua")(importer)
    local routeRules = importer("mods/data/route_rules.lua")

    return {
        key = "H",
        label = "Fields",
        region = "Underworld",
        adapter = "fieldsCageRoute",
        timeline = timeline.standard("H", {
            postBossFeatures = { wellShop = true },
        }),
        featurePolicies = {
            wellShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            coordinate = "FieldsRoutePick",
            routeStartPick = 1,
            routeEndPick = 4,
            default = {
                kind = "fieldsPick",
                alternate = "VanillaSafe",
                biomeEncounterDepthCost = 0,
            },
            fixedBeforeRoute = {
                {
                    key = "Intro",
                    label = "Intro",
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
            routePicks = 4,
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
                biomeEncounterDepthCost = 0,
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.fieldsCages({
                    rewardStore = "RunProgress",
                }),
                cageRewardPolicy = "H_FieldsCageRewards",
                biomeEncounterDepthCost = 0,
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
