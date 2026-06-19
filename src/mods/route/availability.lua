local availability = {}

function availability.slotDepth(slot)
    return slot and slot.coordinate or nil
end

function availability.isInRange(value, range)
    if range == nil or value == nil then
        return true
    end
    if range.exact ~= nil and value ~= range.exact then
        return false
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    if range.minExclusive ~= nil and value <= range.minExclusive then
        return false
    end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then
        return false
    end
    return true
end

function availability.isAvailable(option, context)
    local optionAvailability = option and option.availability
    if optionAvailability == nil then
        return true
    end

    return availability.isInRange(context and context.biomeDepthCache, optionAvailability.biomeDepthCache)
        and availability.isInRange(context and context.biomeEncounterDepth, optionAvailability.biomeEncounterDepth)
end

function availability.optionCap(option)
    if option == nil then
        return nil
    end
    return option.maxAppearancesThisBiome or option.maxCreationsThisRun
end

return availability
