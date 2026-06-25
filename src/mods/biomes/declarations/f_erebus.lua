return function(deps)
    local layout = import("mods/biomes/declarations/f_erebus_layout.lua")
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules
    local combatRooms = parser.withReward(
        layout.combatRooms,
        layout.devotionCombatRooms,
        rewards.majorMinor({ allowDevotion = true })
    )

    return {
        key = "F",
        label = "Erebus",
        region = "Underworld",
        adapter = "fixedLinear",
        rewardRatio = {
            targetMetaProgress = 0.315,
        },
        timeline = parser.standardTimeline("F", {
            postBossFeatures = { wellShop = true },
        }),
        featurePolicies = {
            wellShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            routeRowLabelPrefix = "Depth",
            biomeDepthCacheStart = 0,
            defaultFixedBiomeDepthCacheCost = 0,
            routeBiomeDepthCacheCost = 1,
            depthRange = { min = 0, max = 11 },
            routeStartOrdinal = 1,
            routeEndOrdinal = 10,
            special = {
                [0] = {
                    kind = "opening",
                    isBiomeEntry = true,
                    key = "Opening",
                    label = "Opening",
                    roomOptions = layout.openingRooms,
                    reward = rewards.roomStore("RunProgress", { ineligibleRewardSet = "OpeningRoomBans" }),
                    biomeEncounterDepthCost = 1,
                    locked = true,
                },
                [11] = {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss",
                    roomKey = layout.prebossRoom.key,
                    biomeDepthCache = 10,
                    biomeEncounterDepthCost = 0,
                    reward = rewards.preboss("WorldShop", "RunProgress", {
                        ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
                    }),
                },
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
                key = "Combat",
                label = "Combat",
                mapOptions = combatRooms,
                reward = rewards.majorMinor(),
                biomeEncounterDepthCost = 1,
            },
            {
                key = "Story",
                label = "Story",
                roomOptions = layout.storyRooms,
                reward = rewards.none(),
                biomeEncounterDepthCost = 0,
                routeRules = routeRules.role("Story"),
                reserve = true,
            },
            {
                key = "Fountain",
                label = "Fountain",
                roomOptions = layout.fountainRooms,
                reward = rewards.majorMinor(),
                biomeEncounterDepthCost = 0,
                routeRules = routeRules.role("Fountain"),
                reserve = true,
            },
            {
                key = "Midshop",
                label = "Shop",
                roomOptions = layout.shopRooms,
                reward = rewards.shop("WorldShop"),
                biomeEncounterDepthCost = 0,
                routeRules = routeRules.role("Midshop"),
                routeRequirements = routeRules.midshopRequirements(),
                reserve = true,
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
        },
    }
end
