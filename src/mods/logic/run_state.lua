local runState = {}

local function firstListValue(values)
    if type(values) ~= "table" then
        return nil
    end
    return values[1]
end

local function numeric(value, fallback)
    return math.floor(tonumber(value or fallback or 0) or fallback or 0)
end

function runState.currentRun(currentRun)
    return currentRun or _G.CurrentRun
end

function runState.previousRoom(currentRun)
    local getPreviousRoom = _G.GetPreviousRoom
    if type(getPreviousRoom) == "function" then
        return getPreviousRoom(currentRun)
    end
    local history = currentRun and currentRun.RoomHistory or nil
    return history and history[#history] or nil
end

function runState.startingBiome(currentRun, args)
    args = args or {}
    if args.StartingBiome ~= nil and args.StartingBiome ~= "" then
        return args.StartingBiome
    end
    return currentRun
        and currentRun.CurrentRoom
        and currentRun.CurrentRoom.RoomSetName
        or nil
end

function runState.roomSetName(room)
    return room and room.RoomSetName or nil
end

function runState.roomName(room)
    return room and (room.GenusName or room.Name) or nil
end

function runState.currentBiomeKey(currentRun, args, room)
    args = args or {}
    if room ~= nil then
        local roomSetName = runState.roomSetName(room)
        if roomSetName ~= nil and roomSetName ~= "" then
            return roomSetName
        end
    end

    local currentRoom = currentRun and currentRun.CurrentRoom or nil
    local roomSetName = args.RoomSetName or currentRoom and currentRoom.RoomSetName or "F"
    if args.ForceNextRoomSet ~= nil or currentRoom and currentRoom.ForceNextRoomSet ~= nil then
        roomSetName = args.ForceNextRoomSet or currentRoom.ForceNextRoomSet
    elseif currentRoom and currentRoom.NextRoomSet ~= nil then
        roomSetName = firstListValue(currentRoom.NextRoomSet)
    elseif currentRoom and currentRoom.UsePreviousRoomSet then
        local prevRoom = runState.previousRoom(currentRun) or currentRoom
        roomSetName = prevRoom.RoomSetName
    end
    return roomSetName
end

function runState.routeForBiome(catalog, biomeKey)
    if biomeKey == nil then
        return nil
    end

    for _, route in ipairs(catalog and catalog.routes and catalog.routes.ordered or {}) do
        for _, routeBiomeKey in ipairs(route.biomes or {}) do
            if routeBiomeKey == biomeKey then
                return route
            end
        end
    end
    return nil
end

function runState.routeKeyForBiome(catalog, biomeKey)
    local route = runState.routeForBiome(catalog, biomeKey)
    return route and route.key or nil
end

function runState.routeForRun(catalog, currentRun, args, room)
    return runState.routeForBiome(catalog, runState.currentBiomeKey(currentRun, args, room))
end

function runState.routeKey(catalog, currentRun, args, room)
    local route = runState.routeForRun(catalog, currentRun, args, room)
    return route and route.key or nil
end

function runState.isRoute(catalog, currentRun, args, room, routeKey)
    return runState.routeKey(catalog, currentRun, args, room) == routeKey
end

function runState.isDreamRun(currentRun)
    return currentRun ~= nil and currentRun.IsDreamRun == true
end

function runState.runDepthCache(currentRun)
    return numeric(currentRun and currentRun.RunDepthCache, 0)
end

function runState.runEncounterDepth(currentRun)
    return numeric(currentRun and currentRun.EncounterDepth, 0)
end

function runState.biomeDepthCache(currentRun)
    return numeric(currentRun and currentRun.BiomeDepthCache, 0)
end

function runState.nextBiomeDepthCache(currentRun)
    return runState.biomeDepthCache(currentRun) + 1
end

function runState.biomeEncounterDepth(currentRun)
    return numeric(currentRun and currentRun.BiomeEncounterDepth, 0)
end

return runState
