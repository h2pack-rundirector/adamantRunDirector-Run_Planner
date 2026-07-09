local common = {}

common.MAX_ROOMS = 96

function common.stringField(key, default, maxLen)
    return {
        key = key,
        type = "string",
        default = default or "",
        maxLen = maxLen or 64,
    }
end

function common.intField(key, default, min, max)
    return {
        key = key,
        type = "int",
        default = default or 0,
        min = min or 0,
        max = max or 999,
    }
end

function common.boolField(key, default)
    return {
        key = key,
        type = "bool",
        default = default == true,
    }
end

function common.routeAddressRows(extra)
    local row = {
        common.stringField("RouteKey", "Underworld", 32),
        common.intField("BiomeIndex", 1, 1, 16),
        common.stringField("BiomeKey", "F", 32),
        common.intField("RoomIndex", 1, 1, common.MAX_ROOMS),
    }
    for _, node in ipairs(extra or {}) do
        row[#row + 1] = node
    end
    return row
end

function common.ensureBiome(draft, biomeIndex, biomeKey)
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

function common.ensureRoom(biome, roomIndex)
    local room = biome.rooms[roomIndex]
    if room == nil then
        room = {
            roomKey = "",
        }
        biome.rooms[roomIndex] = room
    end
    return room
end

return common
