local deps = ...
local routeValueStates = deps.valueStates

local valueStateHelpers = {}

function valueStateHelpers.history(instance, rowIndex, controlAlias)
    local routeContext = instance.routeContext
    if routeContext == nil or routeContext.historyValueStates == nil then
        return nil
    end
    return routeContext:historyValueStates(
        instance.routeKey,
        instance.biomeKey,
        rowIndex,
        controlAlias
    )
end

function valueStateHelpers.rowInactive(instance, rowIndex)
    local routeContext = instance.routeContext
    if routeContext == nil or routeContext.historyRowInactive == nil then
        return false
    end
    return routeContext:historyRowInactive(instance.routeKey, instance.biomeKey, rowIndex)
end

function valueStateHelpers.merge(owner, baseStates, overlayStates)
    if overlayStates == nil then
        return baseStates
    end

    local merged = owner._mergedValueStates
    if merged == nil then
        merged = {}
        owner._mergedValueStates = merged
    else
        for key in pairs(merged) do
            merged[key] = nil
        end
    end

    for value, state in pairs(baseStates or {}) do
        routeValueStates.set(merged, value, state)
    end
    for value, state in pairs(overlayStates) do
        routeValueStates.set(merged, value, state)
    end

    return merged
end

return valueStateHelpers
