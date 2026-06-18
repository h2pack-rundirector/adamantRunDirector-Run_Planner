return function(importer)
    local layout = importer("mods/data/biomes/n_ephyra_layout.lua")(importer)
    local timeline = importer("mods/data/biomes/timeline.lua")
    local rewards = importer("mods/data/rewards.lua")(importer)
    local routeRules = importer("mods/data/route_rules.lua")

    return {
        key = "N",
        label = "Ephyra",
        region = "Surface",
        adapter = "hubPylon",
        timeline = timeline.standard("N", {
            roomHistoryCostBySlotKind = {
                pylonPick = 2,
            },
        }),
        slotLayout = {
            coordinate = "SoulPylon",
            routeStartPick = 1,
            routeEndPick = 6,
            requiredPylons = 6,
            default = {
                kind = "pylonPick",
                alternate = "VanillaSafe",
            },
            fixedBeforeHub = {
                {
                    key = "Opening",
                    label = "Opening",
                    roomKey = "N_Opening01",
                    reward = rewards.roomStore("OpeningRunProgress"),
                    locked = true,
                },
                {
                    key = "PreHub",
                    label = "Pre-Hub",
                    roomKey = "N_PreHub01",
                    reward = rewards.roomStore("OpeningRunProgress"),
                    locked = true,
                },
                {
                    key = "Hub",
                    label = "Hub",
                    roomKey = "N_Hub",
                    reward = rewards.none(),
                    locked = true,
                },
            },
            fixedAfterHub = {
                {
                    key = "Preboss",
                    label = "Preboss Shop",
                    roomKey = "N_PreBoss01",
                    reward = rewards.shop("WorldShop"),
                },
            },
        },
        hub = {
            roomKey = "N_Hub",
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
            offerPolicy = "N_HubPylons",
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
            },
            {
                key = "Combat",
                label = "Combat",
                mapOptions = layout.combatRooms,
                reward = rewards.roomStore("HubRewards"),
                sideRooms = {
                    identity = "parentCombatRoomAndDoorId",
                },
            },
            {
                key = "Story",
                label = "Story",
                roomOptions = layout.storyRooms,
                reward = rewards.none(),
                routeRules = routeRules.role("Story"),
                reserve = true,
            },
            {
                key = "Miniboss",
                label = "Miniboss",
                roomOptions = layout.minibossRooms,
                reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
                routeRules = routeRules.role("Miniboss"),
                reserve = true,
            },
        },
    }
end
