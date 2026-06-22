return function(importer, deps)
    local layout = importer("mods/biomes/declarations/n_ephyra_layout.lua")(importer, deps)
    local rewardLayout = importer("mods/biomes/declarations/n_ephyra_rewards.lua")(importer, deps)
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules

    return {
        key = "N",
        label = "Ephyra",
        region = "Surface",
        adapter = "hubPylon",
        timeline = parser.standardTimeline("N", {
            postBossFeatures = { surfaceShop = true },
        }),
        featurePolicies = {
            surfaceShop = {
                roomHistoryDepth = { min = 3 },
            },
        },
        slotLayout = {
            routeRowLabelPrefix = "Pylon",
            biomeDepthCacheStart = 1,
            defaultFixedBiomeDepthCacheCost = 0,
            routeBiomeDepthCacheCost = 1,
            routeStartOrdinal = 1,
            routeEndOrdinal = 6,
            fixedBeforeHub = {
                {
                    key = "Opening",
                    label = "Opening",
                    isBiomeEntry = true,
                    roomKey = "N_Opening01",
                    reward = rewards.roomStore("OpeningRunProgress"),
                    features = { chaos = true },
                    biomeEncounterDepthCost = 1,
                    locked = true,
                },
                {
                    key = "PreHub",
                    label = "Pre-Hub",
                    roomKey = "N_PreHub01",
                    reward = rewards.roomStore("OpeningRunProgress"),
                    biomeEncounterDepthCost = 0,
                    locked = true,
                },
                {
                    key = "Hub",
                    label = "Hub",
                    roomKey = "N_Hub",
                    reward = rewards.none(),
                    roomHistoryCost = 0,
                    biomeEncounterDepthCost = 0,
                    locked = true,
                },
            },
            fixedAfterHub = {
                {
                    key = "Preboss",
                    label = "Preboss Shop",
                    roomKey = "N_PreBoss01",
                    reward = rewards.shop("WorldShop"),
                    biomeEncounterDepthCost = 0,
                },
            },
        },
        hub = {
            roomKey = "N_Hub",
            pylonRoomHistoryCost = 2,
            doorSelectionFunction = "ChooseAvailableN_HubDoors",
            doorTypes = { "EphyraExitDoor" },
            availableDoorCount = { min = 9, max = 10 },
            requiredPylons = 6,
            pylonObjective = "SoulPylon",
            combatRooms = layout.combatRooms,
            combatRoomsByKey = layout.combatRoomsByKey,
            minibossRooms = layout.minibossRooms,
            minibossRoomsByKey = layout.minibossRoomsByKey,
            storyRooms = layout.storyRooms,
            storyRoomsByKey = layout.storyRoomsByKey,
            hubDoorRooms = layout.hubDoorRooms,
            subroomRewardStores = layout.subroomRewardStores,
            rewardRowGroup = rewardLayout.hubPylons,
            minibossAvailability = {
                mode = "oneOf",
                rooms = { "N_MiniBoss01", "N_MiniBoss02" },
            },
            sideRoomAvailability = {
                identity = "parentCombatRoomAndDoorId",
                default = "",
                modes = {
                    { key = "", label = "Vanilla" },
                    { key = "Disabled", label = "Disabled" },
                    { key = "Enabled", label = "Enabled" },
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
                mapOptions = layout.combatRooms,
                reward = rewards.roomStore("HubRewards"),
                biomeEncounterDepthCost = 1,
                sideRooms = {
                    identity = "parentCombatRoomAndDoorId",
                },
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
