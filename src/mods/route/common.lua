local common = {}

local VALID_STATUS = {
    valid = true,
}

common.REWARD_SLOT_COUNT = 6
common.VANILLA_ROLE_KEY = "Vanilla"

function common.shallowCopyList(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

function common.clearList(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

function common.buildLookup(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        if item.key ~= nil then
            lookup[item.key] = item
        end
    end
    return lookup
end

function common.buildKeyLookup(items)
    local lookup = {}
    for _, key in ipairs(items or {}) do
        lookup[key] = true
    end
    return lookup
end

function common.addChoice(values, labels, key, label)
    values[#values + 1] = key
    labels[key] = label or key
end

function common.optionListForRole(role)
    if type(role) ~= "table" then
        return {}
    end
    return role.roomOptions or role.mapOptions or {}
end

function common.shouldOfferAutoOption(role, options)
    if #options == 0 then
        return false
    end
    if #options == 1 and role.roomOptions ~= nil then
        return false
    end
    return true
end

function common.buildOptionChoices(role)
    local optionValues = {}
    local optionLabels = {}
    local options = common.optionListForRole(role)
    if common.shouldOfferAutoOption(role, options) then
        optionValues[#optionValues + 1] = ""
        optionLabels[""] = "Auto"
    end
    for _, option in ipairs(options) do
        common.addChoice(optionValues, optionLabels, option.key, option.label)
    end
    role.defaultOptionKey = optionValues[1] or ""
    role.optionValues = optionValues
    role.optionLabels = optionLabels
end

function common.buildRoleChoices(instance)
    instance.roleValues = {}
    instance.roleLabels = {}
    instance.optionValuesByRole = {}
    instance.optionLabelsByRole = {}

    for _, role in ipairs(instance.roles or {}) do
        common.addChoice(instance.roleValues, instance.roleLabels, role.key, role.label)

        local optionValues = {}
        local optionLabels = {}
        local options = common.optionListForRole(role)
        if common.shouldOfferAutoOption(role, options) then
            optionValues[#optionValues + 1] = ""
            optionLabels[""] = "Auto"
        end
        for _, option in ipairs(options) do
            common.addChoice(optionValues, optionLabels, option.key, option.label)
        end
        role.defaultOptionKey = optionValues[1] or ""
        instance.optionValuesByRole[role.key] = optionValues
        instance.optionLabelsByRole[role.key] = optionLabels
    end
end

function common.rewardContext(role, option)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

function common.isOnlyEligible(values, expected)
    if values == nil or values[1] == nil then
        return false
    end
    return values[1] == expected and values[2] == nil
end

function common.validStatus()
    return VALID_STATUS
end

function common.invalidStatus(code, message)
    return {
        valid = false,
        code = code,
        message = message,
    }
end

function common.layerConfigured(routeContext, routeKey, layer)
    if routeContext ~= nil and routeContext.isLayerConfigured ~= nil then
        return routeContext:isLayerConfigured(routeKey, layer) ~= false
    end
    return true
end

function common.rewardsConfigured(instance)
    return common.layerConfigured(instance and instance.routeContext, instance and instance.routeKey, "rewards")
end

return common
