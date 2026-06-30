local horizon = {}

horizon.ROW_CAPACITY = 32
horizon.TAB_CAPACITY = 4

local TAB_ORDER = {
    rooms = 1,
    rewards = 2,
    sideRooms = 3,
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
            or invalid.sourceKind == "side"
            or (type(address) == "string" and string.sub(address, 1, 5) == "side:")
        )
end

function horizon.tabOrder(tabKey)
    return TAB_ORDER[tabKey]
end

function horizon.tabKeyForInvalid(invalid)
    if invalid ~= nil and invalid.tabKey ~= nil then
        return invalid.tabKey
    end
    if isSideInvalid(invalid) then
        return "sideRooms"
    end
    if isRewardInvalid(invalid) then
        return "rewards"
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

return horizon
