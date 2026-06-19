local deps = ...
local common = deps.common

local biomeRules = {}

local EMPTY_LIST = {}

local validStatus = common.validStatus
local invalidStatus = common.invalidStatus

local function listHasValue(values, expected)
    for _, value in ipairs(values or EMPTY_LIST) do
        if value == expected then
            return true
        end
    end
    return false
end

local function counterValue(context, rule)
    if context == nil or rule.counter == nil then
        return nil
    end
    return context[rule.counter]
end

local function counterMatchesDeadline(context, rule)
    if rule.deadline == nil then
        return false
    end
    return counterValue(context, rule) == rule.deadline
end

local function counterAtOrBeforeDeadline(context, rule)
    local value = counterValue(context, rule)
    if rule.deadline == nil or value == nil then
        return false
    end
    return value <= rule.deadline
end

local function rowSatisfiesRoomRequirement(routeApi, instance, rows, rowIndex, rule)
    local context = routeApi.rowContext(instance, rows, rowIndex)
    if not counterAtOrBeforeDeadline(context, rule) then
        return false
    end

    local validation = routeApi.validateBaseRow(instance, rows, rowIndex)
    if not validation.valid then
        return false
    end
    return listHasValue(rule.roomKeys, routeApi.rowRoomKey(instance, rows, rowIndex))
end

local function requireAnyRoomByCounter(routeApi, instance, rows, rowIndex, rule)
    if not counterMatchesDeadline(routeApi.rowContext(instance, rows, rowIndex), rule) then
        return validStatus()
    end

    for priorIndex = 1, rowIndex do
        if rowSatisfiesRoomRequirement(routeApi, instance, rows, priorIndex, rule) then
            return validStatus()
        end
    end

    return invalidStatus(rule.code or "biome_rule_required_room", rule.message or "Required route room missing")
end

local RULE_HANDLERS = {
    requireAnyRoomByCounter = requireAnyRoomByCounter,
}

function biomeRules.status(routeApi, instance, rows, rowIndex)
    for _, rule in ipairs(instance.biome and instance.biome.biomeRules or EMPTY_LIST) do
        local handler = RULE_HANDLERS[rule.type]
        if handler ~= nil then
            local status = handler(routeApi, instance, rows, rowIndex, rule)
            if not status.valid then
                return status
            end
        end
    end
    return validStatus()
end

return biomeRules
