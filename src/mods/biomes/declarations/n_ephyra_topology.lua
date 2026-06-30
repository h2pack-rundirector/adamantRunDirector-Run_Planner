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
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 1,
                },
                preHub = {
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                hubVisit = {
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                pylonEntry = {
                    biomeDepthCacheCost = 1,
                },
                sideRoom = {
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                pylonRestore = {
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                hubReturn = {
                    biomeDepthCacheCost = 1,
                    biomeEncounterDepthCost = 0,
                },
                preboss = {
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
