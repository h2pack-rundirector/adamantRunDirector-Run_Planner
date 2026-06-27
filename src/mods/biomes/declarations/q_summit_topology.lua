return function(deps)
    local layout = deps.layout

    local function roomByKey(roomKey)
        for _, room in ipairs(layout.minibossRooms or {}) do
            if room.key == roomKey then
                return room
            end
        end
        return nil
    end

    local function miniboss(roomKey)
        local room = roomByKey(roomKey)
        return {
            structure = "Miniboss",
            roomKey = roomKey,
            label = room and room.label or roomKey,
            rewardStore = "TyphonBossRewards",
            offerCount = 1,
        }
    end

    local minibossPairs = {
        {
            key = "Q_Depth3Minibosses",
            biomeDepthCache = 3,
            nodes = {
                miniboss("Q_MiniBoss02"),
                miniboss("Q_MiniBoss05"),
            },
        },
        {
            key = "Q_Depth6Minibosses",
            biomeDepthCache = 6,
            nodes = {
                miniboss("Q_MiniBoss03"),
                miniboss("Q_MiniBoss04"),
            },
        },
    }

    local byRoomKey = {}
    for _, pair in ipairs(minibossPairs) do
        local nodesByRoomKey = {}
        for _, node in ipairs(pair.nodes) do
            nodesByRoomKey[node.roomKey] = node
        end
        pair.nodesByRoomKey = nodesByRoomKey
        for _, node in ipairs(pair.nodes) do
            byRoomKey[node.roomKey] = pair
        end
    end

    return {
        deterministicPairs = minibossPairs,
        deterministicPairsByRoomKey = byRoomKey,
    }
end
