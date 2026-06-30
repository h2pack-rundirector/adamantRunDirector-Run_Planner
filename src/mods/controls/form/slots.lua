local slots = {}

local function numericCost(value, fallback)
    if value == nil then
        return fallback
    end
    local cost = math.floor(tonumber(value) or fallback or 0)
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

local function configuredSlotCost(slot)
    if slot ~= nil and slot.roomHistoryCost ~= nil then
        return numericCost(slot.roomHistoryCost, 0)
    end
    return 0
end

function slots.applyRouteSlots(instance)
    local seenIdentity = {}
    for _, slot in ipairs(instance.routeSlots or {}) do
        local cost = configuredSlotCost(slot)
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

return slots
