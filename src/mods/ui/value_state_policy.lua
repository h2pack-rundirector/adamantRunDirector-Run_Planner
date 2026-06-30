local policy = {}

policy.NORMAL = "normal"
policy.STRUCTURAL_IMPOSSIBLE = "structuralImpossible"
policy.CONTEXT_BLOCKED = "contextBlocked"
policy.REQUIRED_SELECTION_MISSING = "requiredSelectionMissing"
policy.WARNING = "warning"

local FAILURE_CODE_REASONS = {
    biome_depth_unavailable = policy.STRUCTURAL_IMPOSSIBLE,
}

local TOPOLOGY_STRUCTURAL_SUFFIXES = {
    sibling_same_room = true,
    sibling_room_planned = true,
    sibling_miniboss_after_selected = true,
    sibling_same_sibling_room = true,
    sibling_room_generated = true,
}

local function topologySuffix(namespace, code)
    local prefix = tostring(namespace or "topology") .. "_"
    code = tostring(code or "")
    if string.sub(code, 1, #prefix) ~= prefix then
        return nil
    end
    return string.sub(code, #prefix + 1)
end

function policy.reasonForFailureCode(code)
    if code == nil then
        return policy.CONTEXT_BLOCKED
    end
    return FAILURE_CODE_REASONS[code] or policy.CONTEXT_BLOCKED
end

function policy.reasonForTopologySiblingCode(namespace, code)
    local suffix = topologySuffix(namespace, code)
    if TOPOLOGY_STRUCTURAL_SUFFIXES[suffix] then
        return policy.STRUCTURAL_IMPOSSIBLE
    end
    return policy.reasonForFailureCode(code)
end

function policy.valueStateForReason(valueStates, reason)
    if reason == nil or reason == policy.NORMAL then
        return valueStates.NORMAL
    elseif reason == policy.STRUCTURAL_IMPOSSIBLE then
        return valueStates.HIDDEN
    elseif reason == policy.WARNING then
        return valueStates.WARNING
    end
    return valueStates.INVALID
end

function policy.valueStateForFailureCode(valueStates, code)
    return policy.valueStateForReason(valueStates, policy.reasonForFailureCode(code))
end

function policy.valueStateForTopologySiblingStatus(valueStates, namespace, status)
    if status == nil or status.valid then
        return valueStates.NORMAL
    end
    return policy.valueStateForReason(
        valueStates,
        policy.reasonForTopologySiblingCode(namespace, status.code)
    )
end

return policy
