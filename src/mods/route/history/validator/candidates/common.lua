local common = {}

common.EMPTY_LIST = {}

function common.validResult(candidateFindings)
    return {
        valid = true,
        invalids = {},
        findings = candidateFindings or {},
    }
end

function common.rangeContains(range, value)
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

function common.availabilityFailure(availability, entry)
    if availability == nil then
        return nil
    end
    if not common.rangeContains(availability.biomeDepthCache, entry and entry.biomeDepthCache) then
        return "biome_depth_unavailable", "biomeDepthCache", availability.biomeDepthCache, entry.biomeDepthCache
    end
    if not common.rangeContains(availability.biomeEncounterDepth, entry and entry.biomeEncounterDepth) then
        return "encounter_depth_unavailable", "biomeEncounterDepth", availability.biomeEncounterDepth, entry.biomeEncounterDepth
    end
    return nil
end

function common.appendAvailabilityFinding(target, createFinding, entry, candidate, availability, availabilityEntry)
    local failure, axis, expected, actual = common.availabilityFailure(
        availability,
        availabilityEntry or candidate and candidate.availabilityContext or entry
    )
    if failure == nil then
        return
    end
    target[#target + 1] = createFinding(entry, candidate, failure, {
        rowIndex = candidate and candidate.targetRowIndex or nil,
        axis = axis,
        expected = expected,
        actual = actual,
    })
end

return common
