return function(deps)
    local layout = deps.layout

    return {
        kind = "hubDoorBatch",
        hub = {
            roomKey = layout.hubRoom.key,
            availableDoorCount = { min = 9, max = 10 },
            generatedDoorCount = 10,
            generatedRewardExitCount = 10,
            selectedDoorCount = 6,
            effectTiming = "afterGroup",
            traversal = {
                opening = {
                    roomHistoryCost = 1,
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 1,
                },
                preHub = {
                    roomHistoryCost = 1,
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                hubVisit = {
                    roomHistoryCost = 1,
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                pylonEntry = {
                    roomHistoryCost = 1,
                    biomeDepthCacheCost = 1,
                },
                sideRoom = {
                    roomHistoryCost = 1,
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                pylonRestore = {
                    roomHistoryCost = 1,
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                hubReturn = {
                    roomHistoryCost = 1,
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                preboss = {
                    roomHistoryCost = 1,
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
            },
            doorRooms = layout.hubDoorRooms,
            minibossAvailability = {
                mode = "oneOf",
                rooms = { "N_MiniBoss01", "N_MiniBoss02" },
            },
        },
    }
end
