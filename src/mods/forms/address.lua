local address = {}

local function clone(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

function address.route(routeKey)
    return {
        routeKey = routeKey,
    }
end

function address.biome(routeKey, biomeIndex)
    return {
        routeKey = routeKey,
        biomeIndex = biomeIndex,
    }
end

function address.room(routeKey, biomeIndex, roomIndex)
    return {
        routeKey = routeKey,
        biomeIndex = biomeIndex,
        roomIndex = roomIndex,
    }
end

function address.door(routeKey, biomeIndex, roomIndex, doorIndex)
    return {
        routeKey = routeKey,
        biomeIndex = biomeIndex,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
    }
end

function address.offer(routeKey, biomeIndex, roomIndex, doorIndex, offerIndex)
    return {
        routeKey = routeKey,
        biomeIndex = biomeIndex,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
        offerIndex = offerIndex,
    }
end

function address.withField(base, field)
    local copy = clone(base)
    copy.field = field
    return copy
end

return address
