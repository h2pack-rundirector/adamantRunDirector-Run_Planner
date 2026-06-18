local timeline = {}

local DEFAULT_ROOM_HISTORY_COST = 1

local function numericCost(value, fallback)
    if value == nil then
        return fallback
    end
    local cost = math.floor(tonumber(value) or fallback or DEFAULT_ROOM_HISTORY_COST)
    if cost < 0 then
        return 0
    end
    return cost
end

local function slotIdentity(slot)
    if slot == nil then
        return nil
    end
    if slot.roomHistoryIdentity ~= nil then
        return slot.roomHistoryIdentity
    end
    if slot.roomKey ~= nil then
        return tostring(slot.kind or "slot") .. ":" .. tostring(slot.roomKey)
    end
    return nil
end

local function configuredSlotCost(instance, slot)
    local config = instance.biome and instance.biome.timeline or {}
    local kindCosts = config.roomHistoryCostBySlotKind or {}
    if slot ~= nil and slot.roomHistoryCost ~= nil then
        return numericCost(slot.roomHistoryCost, DEFAULT_ROOM_HISTORY_COST)
    end
    if slot ~= nil and kindCosts[slot.kind] ~= nil then
        return numericCost(kindCosts[slot.kind], DEFAULT_ROOM_HISTORY_COST)
    end
    return numericCost(config.defaultRoomHistoryCost, DEFAULT_ROOM_HISTORY_COST)
end

function timeline.applyRouteSlots(instance)
    local seenIdentity = {}
    for _, slot in ipairs(instance.routeSlots or {}) do
        local cost = configuredSlotCost(instance, slot)
        local identity = slotIdentity(slot)
        if identity ~= nil then
            if seenIdentity[identity] then
                cost = 0
            else
                seenIdentity[identity] = true
            end
        end
        slot.roomHistoryCost = cost
        slot.roomHistoryIdentity = identity
    end
end

function timeline.afterBiome(instance)
    return instance.biome
        and instance.biome.timeline
        and instance.biome.timeline.afterBiome
        or {}
end

function timeline.entryCost(entry)
    return numericCost(entry and entry.roomHistoryCost, DEFAULT_ROOM_HISTORY_COST)
end

return timeline
