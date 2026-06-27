return function(deps)
    local layout = import("mods/biomes/declarations/n_ephyra_layout.lua")(deps)
    local rewardLayout = import("mods/biomes/declarations/n_ephyra_rewards.lua")(deps)
    local topology = import("mods/biomes/declarations/n_ephyra_topology.lua")({
        layout = layout,
        rewardLayout = rewardLayout,
    })
    local parser = deps.parser
    local rewards = deps.rewards
    local routeRules = deps.routeRules

    return {
        key = "N",
        label = "Ephyra",
        region = "Surface",
        adapter = "hubPylon",
        roomTopology = topology,
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
                    room = layout.openingRoom,
                    reward = rewards.roomStore("RunProgress", { ineligibleRewardSet = "OpeningRoomBans" }),
                    biomeEncounterDepthCost = 1,
                    locked = true,
                },
                {
                    key = "PreHub",
                    label = "Pre-Hub",
                    room = layout.preHubRoom,
                    reward = rewards.roomStore("RunProgress", { ineligibleRewardSet = "OpeningRoomBans" }),
                    biomeEncounterDepthCost = 0,
                    locked = true,
                },
                {
                    key = "Hub",
                    label = "Hub",
                    room = layout.hubRoom,
                    reward = rewards.none(),
                    roomHistoryCost = 0,
                    biomeEncounterDepthCost = 0,
                    locked = true,
                },
            },
            fixedAfterHub = {
                {
                    kind = "preboss",
                    key = "Preboss",
                    label = "Preboss Shop",
                    reward = rewards.shop("WorldShop"),
                    biomeEncounterDepthCost = 0,
                },
            },
        },
        hub = {
            roomKey = layout.hubRoom.key,
            pylonRoomHistoryCost = 2,
            doorSelectionFunction = "ChooseAvailableN_HubDoors",
            doorTypes = { "EphyraExitDoor" },
            pylonObjective = "SoulPylon",
            combatRooms = layout.combatRooms,
            combatRoomsByKey = layout.combatRoomsByKey,
            minibossRooms = layout.minibossRooms,
            minibossRoomsByKey = layout.minibossRoomsByKey,
            storyRooms = layout.storyRooms,
            storyRoomsByKey = layout.storyRoomsByKey,
            subroomRewardStores = layout.subroomRewardStores,
            sideRoomAvailability = {
                identity = "parentCombatRoomAndDoorId",
                vanillaPolicy = {
                    minPerPylon = 0.5,
                    chanceAfterMinimum = 0.3,
                },
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
