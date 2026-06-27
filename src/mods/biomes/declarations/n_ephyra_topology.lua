return function(deps)
    local layout = deps.layout
    local rewardLayout = deps.rewardLayout

    return {
        kind = "hubDoorBatch",
        hub = {
            roomKey = layout.hubRoom.key,
            availableDoorCount = { min = 9, max = 10 },
            generatedDoorCount = 10,
            generatedRewardExitCount = 10,
            selectedDoorCount = 6,
            rewardRowGroup = rewardLayout.hubPylons,
            effectTiming = "afterGroup",
            doorRooms = layout.hubDoorRooms,
            minibossAvailability = {
                mode = "oneOf",
                rooms = { "N_MiniBoss01", "N_MiniBoss02" },
            },
        },
    }
end
