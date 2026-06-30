local policy = _G.import
    and _G.import("mods/ui/value_state_policy.lua")
    or dofile("src/mods/ui/value_state_policy.lua")

local valueStates = {}

valueStates.NORMAL = 0
valueStates.HIDDEN = 1
valueStates.INVALID = 2
valueStates.WARNING = 3

valueStates.policy = policy

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
    return policy.valueStateForFailureCode(valueStates, code)
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

function valueStates.forTopologySiblingStatus(namespace, status)
    return policy.valueStateForTopologySiblingStatus(valueStates, namespace, status)
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
