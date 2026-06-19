local availability = {}

local VALID_STATUS = {
    valid = true,
}

local function invalidStatus(code, message)
    return {
        valid = false,
        code = code,
        message = message,
    }
end

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

function availability.status(option, context)
    local optionAvailability = option and option.availability
    if optionAvailability == nil then
        return VALID_STATUS
    end

    if not availability.isInRange(context and context.biomeDepthCache, optionAvailability.biomeDepthCache) then
        return invalidStatus("biome_depth_unavailable", "Room is not valid at this biome depth")
    end

    if optionAvailability.biomeEncounterDepth ~= nil then
        if context == nil or context.biomeEncounterDepthKnown == false or context.biomeEncounterDepth == nil then
            return invalidStatus("encounter_depth_unknown", "Choose concrete prior rooms to prove encounter depth")
        end
        if not availability.isInRange(context.biomeEncounterDepth, optionAvailability.biomeEncounterDepth) then
            return invalidStatus("encounter_depth_unavailable", "Room is not valid at this encounter depth")
        end
    end

    return VALID_STATUS
end

function availability.isAvailable(option, context)
    local optionAvailability = option and option.availability
    if optionAvailability == nil then
        return true
    end
    if not availability.isInRange(context and context.biomeDepthCache, optionAvailability.biomeDepthCache) then
        return false
    end
    if optionAvailability.biomeEncounterDepth == nil then
        return true
    end
    if context == nil or context.biomeEncounterDepthKnown == false or context.biomeEncounterDepth == nil then
        return false
    end
    return availability.isInRange(context.biomeEncounterDepth, optionAvailability.biomeEncounterDepth)
end

function availability.optionCap(option)
    if option == nil then
        return nil
    end
    return option.maxAppearancesThisBiome or option.maxCreationsThisRun
end

return availability
