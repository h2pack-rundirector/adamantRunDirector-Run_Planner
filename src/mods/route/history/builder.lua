local deps = ... or {}

local routeHistory = deps.history

local historyBuilder = {}

local EMPTY_LIST = {}

local function rowPosition(snapshot, row)
    return {
        routeKey = snapshot.routeKey,
        controlName = snapshot.controlName,
        biomeKey = row.biomeKey or snapshot.biomeKey,
        rowIndex = row.rowIndex,
        routeOrdinal = row.routeOrdinal,
        roomHistoryOrdinal = row.roomHistoryOrdinal,
        runDepthCache = row.runDepthCache,
        runEncounterDepth = row.runEncounterDepth,
        biomeDepthCache = row.biomeDepthCache,
        biomeEncounterDepth = row.biomeEncounterDepth,
    }
end

local function emitRoom(history, snapshot, row, fields)
    fields = fields or {}
    local roomKey = fields.roomKey or row.roomKey
    if roomKey == nil or roomKey == "" then
        return nil
    end

    return routeHistory.emitAt(history, rowPosition(snapshot, row), {
        kind = "room",
        eventKey = roomKey,
        groupKey = fields.groupKey or row.roleKey,
        sourceKind = fields.sourceKind or "row",
        sourceIndex = fields.sourceIndex,
        roomKey = roomKey,
        roleKey = row.roleKey,
        optionKey = row.optionKey,
        slotKind = row.slotKind,
        slotLabel = row.slotLabel,
        parentRoomKey = fields.parentRoomKey,
        enabled = fields.enabled,
        entered = fields.entered,
        source = fields.source or row,
    })
end

local function emitSideRooms(history, snapshot, row)
    for _, sideRoom in ipairs(row.sideRooms or EMPTY_LIST) do
        if sideRoom.entered == true then
            emitRoom(history, snapshot, row, {
                sourceKind = "side",
                sourceIndex = sideRoom.sideIndex,
                groupKey = "SideRoom",
                roomKey = sideRoom.roomKey,
                parentRoomKey = row.roomKey,
                enabled = sideRoom.enabled,
                entered = sideRoom.entered,
                source = sideRoom,
            })
        end
    end
end

local function emitSnapshotRows(history, snapshot)
    for _, row in ipairs(snapshot.rows or EMPTY_LIST) do
        emitRoom(history, snapshot, row)
        emitSideRooms(history, snapshot, row)
    end
end

function historyBuilder.build(routeSnapshots)
    local history = routeHistory.create()
    for _, routeSnapshot in ipairs(routeSnapshots or EMPTY_LIST) do
        emitSnapshotRows(history, routeSnapshot)
    end
    return history
end

return historyBuilder
