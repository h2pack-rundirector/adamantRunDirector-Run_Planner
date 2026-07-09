local common = import("mods/controls/PlannerDraft/codecs/common.lua")

local rooms = {}

function rooms.storageNode()
    return {
        key = "Rooms",
        type = "table",
        maxRows = common.MAX_ROOMS,
        defaultRows = 0,
        row = common.routeAddressRows({
            common.stringField("RoomKey", "", 64),
            common.intField("SelectedDoorIndex", 0, 0, 8),
            common.stringField("BatchRule", "", 64),
        }),
    }
end

function rooms.read(fields, draft)
    local rows = fields.Rooms
    for index = 1, rows:count() do
        local routeKey = rows:read(index, "RouteKey")
        if draft.routeKey == nil or draft.routeKey == "" then
            draft.routeKey = routeKey
        end

        local biomeIndex = rows:read(index, "BiomeIndex")
        local biome = common.ensureBiome(draft, biomeIndex, rows:read(index, "BiomeKey"))
        local roomIndex = rows:read(index, "RoomIndex")
        biome.rooms[roomIndex] = {
            roomKey = rows:read(index, "RoomKey"),
        }

        local batchRule = rows:read(index, "BatchRule")
        local selectedDoorIndex = rows:read(index, "SelectedDoorIndex")
        if batchRule ~= "" or selectedDoorIndex > 0 then
            biome.rooms[roomIndex].generatedDoors = {
                batchRule = batchRule,
                selectedDoorIndex = selectedDoorIndex > 0 and selectedDoorIndex or nil,
                doors = {},
            }
        end
    end
end

function rooms.append(fields, routeKey, biomeIndex, biomeKey, roomIndex, room)
    local generatedDoors = room.generatedDoors or {}
    return fields.Rooms:append({
        RouteKey = routeKey,
        BiomeIndex = biomeIndex,
        BiomeKey = biomeKey,
        RoomIndex = roomIndex,
        RoomKey = room.roomKey or "",
        SelectedDoorIndex = generatedDoors.selectedDoorIndex or 0,
        BatchRule = generatedDoors.batchRule or "",
    })
end

return rooms
