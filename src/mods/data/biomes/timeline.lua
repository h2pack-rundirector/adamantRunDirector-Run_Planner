local timeline = {}

local function defaultBossRooms(biomeKey)
    return {
        { key = tostring(biomeKey) .. "_Boss01", label = "Boss" },
        { key = tostring(biomeKey) .. "_Boss02", label = "Boss Alternate" },
    }
end

function timeline.standard(biomeKey, opts)
    opts = opts or {}
    return {
        defaultRoomHistoryCost = opts.defaultRoomHistoryCost or 1,
        roomHistoryCostBySlotKind = opts.roomHistoryCostBySlotKind,
        afterBiome = {
            {
                key = "Boss",
                label = "Boss",
                roomOptions = opts.bossRooms or defaultBossRooms(biomeKey),
                roomHistoryCost = opts.bossRoomHistoryCost or 1,
            },
            {
                key = "PostBoss",
                label = "Post-Boss",
                roomKey = opts.postBossRoomKey or (tostring(biomeKey) .. "_PostBoss01"),
                roomHistoryCost = opts.postBossRoomHistoryCost or 1,
            },
        },
    }
end

return timeline
