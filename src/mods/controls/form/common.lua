local common = {}

local VALID_STATUS = {
    valid = true,
}

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

function common.buildOptionChoices(role)
    local optionValues = {}
    local optionLabels = {}
    local options = common.optionListForRole(role)
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

function common.rewardOfferCount(reward)
    local count = #(reward and reward.offers or {})
    if count > 0 then
        return count
    end
    return nil
end

function common.fixedRoomKey(entry)
    local room = entry and entry.room or nil
    return entry and entry.roomKey or room and room.key or nil
end

function common.fixedRoomField(entry, field)
    if entry == nil then
        return nil
    end
    if entry[field] ~= nil then
        return entry[field]
    end
    if entry.room ~= nil then
        return entry.room[field]
    end
    return nil
end

function common.fixedRoomFeatures(entry)
    if entry == nil then
        return nil
    end
    if entry.features ~= nil then
        return entry.features
    end
    local room = entry.room
    return room and room.features or nil
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

function common.numericCost(value, fallback)
    local cost = math.floor(tonumber(value) or fallback or 0)
    if cost < 0 then
        return 0
    end
    return cost
end

function common.fixedBiomeDepthCacheCost(slotLayout, source)
    if source ~= nil and source.biomeDepthCacheCost ~= nil then
        return source.biomeDepthCacheCost
    end
    if slotLayout ~= nil and slotLayout.defaultFixedBiomeDepthCacheCost ~= nil then
        return slotLayout.defaultFixedBiomeDepthCacheCost
    end
    return 0
end

function common.routeBiomeDepthCacheCost(slotLayout)
    if slotLayout ~= nil and slotLayout.routeBiomeDepthCacheCost ~= nil then
        return slotLayout.routeBiomeDepthCacheCost
    end
    return 1
end

function common.routeStartOrdinal(slotLayout, fallback)
    fallback = fallback or 1
    return math.floor(tonumber(slotLayout and slotLayout.routeStartOrdinal or fallback) or fallback)
end

function common.routeEndOrdinal(slotLayout, startOrdinal)
    startOrdinal = startOrdinal or 1
    local ordinal = math.floor(tonumber(slotLayout and slotLayout.routeEndOrdinal or startOrdinal) or startOrdinal)
    if ordinal < startOrdinal then
        return startOrdinal
    end
    return ordinal
end

function common.routeRowLabel(slotLayout, ordinal, fallbackPrefix)
    local prefix = slotLayout and slotLayout.routeRowLabelPrefix or fallbackPrefix or "Depth"
    return tostring(prefix) .. " " .. tostring(ordinal)
end

function common.applySlotDepthContext(slot, source)
    if slot == nil then
        return slot
    end
    source = source or {}
    slot.biomeDepthCache = source.biomeDepthCache
    slot.biomeDepthCacheCost = source.biomeDepthCacheCost
    slot.biomeEncounterDepthCost = source.biomeEncounterDepthCost
    return slot
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
