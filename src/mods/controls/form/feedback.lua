local deps = ...
local routeValueStates = deps.valueStates

local feedback = {}

local function appliedFeedback(instance)
    local routeContext = instance.routeContext
    if routeContext == nil or routeContext.routeGeneration == nil then
        return nil
    end
    if instance.routeFeedbackGeneration ~= routeContext:routeGeneration(instance.routeKey) then
        return nil
    end
    return instance.routeFeedback
end

function feedback.history(instance, rowIndex, controlAlias)
    local applied = appliedFeedback(instance)
    if applied ~= nil then
        local row = applied[rowIndex]
        return row and row.valueStates and row.valueStates[controlAlias] or nil
    end

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

function feedback.rowInactive(instance, rowIndex)
    local applied = appliedFeedback(instance)
    if applied ~= nil then
        return applied.inactiveAfterRowIndex ~= nil
            and rowIndex ~= nil
            and rowIndex > applied.inactiveAfterRowIndex
    end

    local routeContext = instance.routeContext
    if routeContext == nil or routeContext.historyRowInactive == nil then
        return false
    end
    return routeContext:historyRowInactive(instance.routeKey, instance.biomeKey, rowIndex)
end

function feedback.merge(owner, baseStates, overlayStates)
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

return feedback
