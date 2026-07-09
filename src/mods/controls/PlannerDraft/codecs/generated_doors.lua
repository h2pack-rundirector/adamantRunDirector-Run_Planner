local common = import("mods/controls/PlannerDraft/codecs/common.lua")

local generatedDoors = {}

local MAX_DOORS = 384

function generatedDoors.storageNode()
    return {
        key = "GeneratedDoors",
        type = "table",
        maxRows = MAX_DOORS,
        defaultRows = 0,
        row = common.routeAddressRows({
            common.intField("DoorIndex", 1, 1, 16),
            common.intField("ExitIndex", 1, 1, 16),
            common.stringField("TargetRoomKey", "", 64),
        }),
    }
end

function generatedDoors.read(fields, draft)
    local rows = fields.GeneratedDoors
    for index = 1, rows:count() do
        local biome = common.ensureBiome(draft, rows:read(index, "BiomeIndex"), rows:read(index, "BiomeKey"))
        local room = common.ensureRoom(biome, rows:read(index, "RoomIndex"))

        room.generatedDoors = room.generatedDoors or {
            batchRule = "Standard",
            selectedDoorIndex = nil,
            doors = {},
        }
        local doorIndex = rows:read(index, "DoorIndex")
        room.generatedDoors.doors[doorIndex] = {
            exitIndex = rows:read(index, "ExitIndex"),
            targetRoomKey = rows:read(index, "TargetRoomKey"),
        }
    end
end

function generatedDoors.append(fields, routeKey, biomeIndex, biomeKey, roomIndex, doorIndex, door)
    return fields.GeneratedDoors:append({
        RouteKey = routeKey,
        BiomeIndex = biomeIndex,
        BiomeKey = biomeKey,
        RoomIndex = roomIndex,
        DoorIndex = doorIndex,
        ExitIndex = door.exitIndex or 0,
        TargetRoomKey = door.targetRoomKey or "",
    })
end

return generatedDoors
