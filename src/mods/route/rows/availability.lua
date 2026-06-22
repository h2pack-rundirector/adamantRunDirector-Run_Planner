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

function availability.boundsInRange(minValue, maxValue, range)
    if range == nil then
        return true
    end
    if minValue == nil or maxValue == nil then
        return false
    end
    if range.exact ~= nil and (minValue ~= range.exact or maxValue ~= range.exact) then
        return false
    end
    if range.min ~= nil and minValue < range.min then
        return false
    end
    if range.max ~= nil and maxValue > range.max then
        return false
    end
    if range.minExclusive ~= nil and minValue <= range.minExclusive then
        return false
    end
    if range.maxExclusive ~= nil and maxValue >= range.maxExclusive then
        return false
    end
    return true
end

local function biomeEncounterDepthBounds(context)
    if context == nil then
        return nil, nil
    end
    if context.biomeEncounterDepthMin ~= nil and context.biomeEncounterDepthMax ~= nil then
        return context.biomeEncounterDepthMin, context.biomeEncounterDepthMax
    end
    return context.biomeEncounterDepth, context.biomeEncounterDepth
end

function availability.status(option, context)
    local code = availability.failureCode(option, context)
    if code == nil then
        return VALID_STATUS
    end
    if code == "biome_depth_unavailable" then
        return invalidStatus(code, "Room is not valid at this biome depth")
    elseif code == "encounter_depth_unknown" then
        return invalidStatus(code, "Choose concrete prior rooms to prove encounter depth")
    elseif code == "encounter_depth_unavailable" then
        return invalidStatus(code, "Room is not valid at this encounter depth")
    end
    return invalidStatus(code, "Room is not valid here")
end

function availability.failureCode(option, context)
    local optionAvailability = option and option.availability
    if optionAvailability == nil then
        return nil
    end

    if not availability.isInRange(context and context.biomeDepthCache, optionAvailability.biomeDepthCache) then
        return "biome_depth_unavailable"
    end

    if optionAvailability.biomeEncounterDepth ~= nil then
        local minDepth, maxDepth = biomeEncounterDepthBounds(context)
        if minDepth == nil or maxDepth == nil then
            return "encounter_depth_unknown"
        end
        if not availability.boundsInRange(minDepth, maxDepth, optionAvailability.biomeEncounterDepth) then
            return "encounter_depth_unavailable"
        end
    end

    return nil
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
    local minDepth, maxDepth = biomeEncounterDepthBounds(context)
    if minDepth == nil or maxDepth == nil then
        return false
    end
    return availability.boundsInRange(minDepth, maxDepth, optionAvailability.biomeEncounterDepth)
end

function availability.optionCap(option)
    if option == nil then
        return nil
    end
    return option.maxAppearancesThisBiome or option.maxCreationsThisRun
end

return availability
