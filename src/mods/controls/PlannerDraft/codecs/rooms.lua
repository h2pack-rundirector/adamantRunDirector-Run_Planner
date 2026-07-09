local rooms = {}

local MAX_ROOMS = 96

local function stringField(key, default, maxLen)
    return {
        key = key,
        type = "string",
        default = default or "",
        maxLen = maxLen or 64,
    }
end

local function intField(key, default, min, max)
    return {
        key = key,
        type = "int",
        default = default or 0,
        min = min or 0,
        max = max or 999,
    }
end

local function routeAddressRows(extra)
    local row = {
        stringField("RouteKey", "Underworld", 32),
        intField("BiomeIndex", 1, 1, 16),
        stringField("BiomeKey", "F", 32),
        intField("RoomIndex", 1, 1, MAX_ROOMS),
    }
    for _, node in ipairs(extra or {}) do
        row[#row + 1] = node
    end
    return row
end

function rooms.storageNode()
    return {
        key = "Rooms",
        type = "table",
        maxRows = MAX_ROOMS,
        defaultRows = 0,
        row = routeAddressRows({
            stringField("RoomKey", "", 64),
            intField("SelectedDoorIndex", 0, 0, 8),
            stringField("BatchRule", "", 64),
        }),
    }
end

function rooms.ensureBiome(draft, biomeIndex, biomeKey)
    local biome = draft.biomes[biomeIndex]
    if biome == nil then
        biome = {
            biomeKey = biomeKey,
            rooms = {},
        }
        draft.biomes[biomeIndex] = biome
    elseif biome.biomeKey == nil or biome.biomeKey == "" then
        biome.biomeKey = biomeKey
    end
    return biome
end

function rooms.read(fields, draft)
    local rows = fields.Rooms
    for index = 1, rows:count() do
        local routeKey = rows:read(index, "RouteKey")
        if draft.routeKey == nil or draft.routeKey == "" then
            draft.routeKey = routeKey
        end

        local biomeIndex = rows:read(index, "BiomeIndex")
        local biome = rooms.ensureBiome(draft, biomeIndex, rows:read(index, "BiomeKey"))
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
