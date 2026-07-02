local horizon = {}

horizon.ROW_CAPACITY = 32
horizon.TAB_CAPACITY = 4

local TAB_ORDER = {
    rooms = 1,
    rewards = 2,
}

local BIOME_STRIDE = horizon.TAB_CAPACITY * horizon.ROW_CAPACITY

local function isRewardInvalid(invalid)
    return invalid ~= nil and (invalid.rewardType ~= nil or invalid.address ~= nil)
end

local function isSideInvalid(invalid)
    local address = invalid and invalid.address or nil
    return invalid ~= nil
        and (
            invalid.tabKey == "sideRooms"
            or invalid.eventSourceKind == "side"
            or (type(address) == "string" and string.sub(address, 1, 5) == "side:")
        )
end

function horizon.tabOrder(tabKey)
    return TAB_ORDER[tabKey]
end

function horizon.tabKeyForInvalid(invalid)
    if invalid ~= nil and invalid.renderTabKey ~= nil then
        return invalid.renderTabKey
    end
    if invalid ~= nil and invalid.tabKey ~= nil then
        if invalid.tabKey == "sideRooms" then
            if isRewardInvalid(invalid) then
                return "rewards"
            end
            return "rooms"
        end
        return invalid.tabKey
    end
    if isRewardInvalid(invalid) then
        return "rewards"
    end
    if isSideInvalid(invalid) then
        return "rooms"
    end
    return "rooms"
end

function horizon.key(opts)
    local routeBiomeIndex = opts.routeBiomeIndex
    local tabOrder = opts.tabOrder or (opts.tabKey and horizon.tabOrder(opts.tabKey))
    local routeOrdinal = opts.routeOrdinal
    if routeBiomeIndex == nil or tabOrder == nil or routeOrdinal == nil then
        return nil
    end
    return routeBiomeIndex * BIOME_STRIDE
        + (tabOrder - 1) * horizon.ROW_CAPACITY
        + routeOrdinal
end

function horizon.after(currentKey, horizonKey)
    return currentKey ~= nil and horizonKey ~= nil and currentKey > horizonKey
end

function horizon.routeOrdinalForInvalid(invalid)
    if invalid ~= nil and invalid.renderRouteOrdinal ~= nil then
        return invalid.renderRouteOrdinal
    end
    return invalid and invalid.routeOrdinal or nil
end

return horizon
