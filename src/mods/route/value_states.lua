local valueStates = {}

valueStates.NORMAL = 0
valueStates.HIDDEN = 1
valueStates.INVALID = 2
valueStates.WARNING = 3

valueStates.failureCodeStates = {
    biome_depth_unavailable = valueStates.HIDDEN,
}

local function normalize(state)
    local value = math.floor(tonumber(state) or valueStates.NORMAL)
    if value < valueStates.NORMAL then
        return valueStates.NORMAL
    end
    return value
end

function valueStates.merge(first, second)
    first = normalize(first)
    second = normalize(second)
    if first == valueStates.NORMAL then
        return second
    elseif second == valueStates.NORMAL then
        return first
    end
    return math.min(first, second)
end

function valueStates.forFailureCode(code)
    if code == nil then
        return valueStates.INVALID
    end
    return valueStates.failureCodeStates[code] or valueStates.INVALID
end

function valueStates.forFailureCodeOrNormal(code)
    if code == nil then
        return valueStates.NORMAL
    end
    return valueStates.forFailureCode(code)
end

function valueStates.forStatus(status)
    if status == nil or status.valid then
        return valueStates.NORMAL
    end
    return valueStates.forFailureCode(status.code)
end

function valueStates.set(target, key, state)
    state = valueStates.merge(target[key], state)
    if state == valueStates.NORMAL then
        target[key] = nil
    else
        target[key] = state
    end
    return target[key]
end

return valueStates
