local viewHelpers = {}

function viewHelpers.selectedDoorOptionCache()
    return setmetatable({}, {
        __mode = "k",
    })
end

function viewHelpers.selectedDoorOptions(state, generatedDoors)
    if generatedDoors == nil then
        return state.emptyOptions
    end

    local doors = generatedDoors.doors or state.emptyOptions.values
    local doorCount = #doors
    local cached = state.selectedDoorOptionCache[generatedDoors]
    if cached ~= nil and cached.doorCount == doorCount then
        return cached.options
    end

    local values = {}
    local labels = {}
    for index = 1, doorCount do
        values[index] = index
        labels[index] = "Door " .. tostring(index)
    end

    local optionSet = {
        values = values,
        labels = labels,
    }
    state.selectedDoorOptionCache[generatedDoors] = {
        doorCount = doorCount,
        options = optionSet,
    }
    return optionSet
end

local function roomAt(state, roomIndex)
    local biome = state.currentBiome()
    return biome and biome.rooms and biome.rooms[roomIndex] or nil
end

local function roomLocationLabel(state, roomIndex)
    local label = "Room " .. tostring(roomIndex)
    local room = roomAt(state, roomIndex)
    if room ~= nil and room.roomKey ~= nil then
        label = label .. " (" .. tostring(room.roomKey) .. ")"
    end
    return label
end

function viewHelpers.feedbackLocationLabel(state, address)
    if address == nil then
        return nil
    end

    local parts = {}
    if address.roomIndex ~= nil then
        parts[#parts + 1] = roomLocationLabel(state, address.roomIndex)
    elseif address.biomeIndex ~= nil then
        parts[#parts + 1] = "Biome " .. tostring(address.biomeIndex)
    elseif address.routeKey ~= nil then
        parts[#parts + 1] = "Route " .. tostring(address.routeKey)
    end

    if address.doorIndex ~= nil then
        parts[#parts + 1] = "door " .. tostring(address.doorIndex)
    end
    if address.offerPointIndex ~= nil then
        parts[#parts + 1] = "offer point " .. tostring(address.offerPointIndex)
    end
    if address.offerIndex ~= nil then
        local offerLabel = address.doorIndex ~= nil and "reward " or "offer "
        parts[#parts + 1] = offerLabel .. tostring(address.offerIndex)
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " ")
end

return viewHelpers
