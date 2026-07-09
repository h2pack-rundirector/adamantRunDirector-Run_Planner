local identity = {}

local function appendAddress(address, key, value)
    if value ~= nil then
        address[key] = value
    end
end

local function appendId(parts, label, value)
    if value ~= nil then
        parts[#parts + 1] = label .. tostring(value)
    end
end

local function routeAddress(context)
    local address = {}
    appendAddress(address, "routeKey", context.routeKey)
    appendAddress(address, "biomeIndex", context.biomeIndex)
    appendAddress(address, "roomIndex", context.roomIndex)
    appendAddress(address, "doorIndex", context.doorIndex)
    appendAddress(address, "offerPointIndex", context.offerPointIndex)
    appendAddress(address, "offerIndex", context.offerIndex)
    return address
end

local function routeIdParts(context)
    local parts = {}
    appendId(parts, "route", context.routeKey)
    appendId(parts, "_biome", context.biomeIndex)
    appendId(parts, "_room", context.roomIndex)
    appendId(parts, "_door", context.doorIndex)
    appendId(parts, "_offerPoint", context.offerPointIndex)
    appendId(parts, "_offer", context.offerIndex)
    return parts
end

local function create(kind, context, extra)
    local parts = routeIdParts(context)
    for _, part in ipairs(extra or {}) do
        parts[#parts + 1] = "_" .. tostring(part)
    end
    return {
        kind = kind,
        address = routeAddress(context),
        id = table.concat(parts),
    }
end

function identity.room(context)
    return create("room", {
        routeKey = context.routeKey,
        biomeIndex = context.biomeIndex,
        roomIndex = context.roomIndex,
    })
end

function identity.generatedDoor(context)
    return create("generatedDoor", {
        routeKey = context.routeKey,
        biomeIndex = context.biomeIndex,
        roomIndex = context.roomIndex,
        doorIndex = context.doorIndex,
    })
end

function identity.generatedOffer(context, offerIndex)
    local offerContext = {
        routeKey = context.routeKey,
        biomeIndex = context.biomeIndex,
        roomIndex = context.roomIndex,
        doorIndex = context.doorIndex,
        offerIndex = offerIndex or context.offerIndex or 1,
    }
    return create("generatedOffer", offerContext)
end

function identity.roomOffer(context, offerPointIndex, offerIndex)
    local offerContext = {
        routeKey = context.routeKey,
        biomeIndex = context.biomeIndex,
        roomIndex = context.roomIndex,
        offerPointIndex = offerPointIndex or context.offerPointIndex or 1,
        offerIndex = offerIndex or context.offerIndex or 1,
    }
    return create("roomOffer", offerContext)
end

function identity.control(form, label, field)
    return tostring(label) .. "##" .. tostring(form.id) .. "_" .. tostring(field)
end

function identity.address(form)
    return form.address
end

return identity
