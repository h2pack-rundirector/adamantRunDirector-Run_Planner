local deps = ... or {}

local routeHistory = deps.history

local common = {}

common.EMPTY_LIST = {}

function common.validResult(resultFindings)
    return {
        valid = true,
        invalids = {},
        findings = resultFindings,
    }
end

function common.invalidAt(entry, code, message, fields)
    local invalid = {
        code = code,
        message = message,
        routeKey = entry and entry.routeKey or nil,
        biomeKey = entry and entry.biomeKey or nil,
        routeBiomeIndex = entry and entry.routeBiomeIndex or nil,
        rowIndex = entry and entry.rowIndex or nil,
        routeOrdinal = entry and entry.routeOrdinal or nil,
        roomHistoryOrdinal = entry and entry.roomHistoryOrdinal or nil,
        roomKey = entry and (entry.roomKey or entry.eventKey) or nil,
        entry = entry,
    }
    for key, value in pairs(fields or {}) do
        invalid[key] = value
    end
    return invalid
end

function common.invalidWithFindings(entry, code, message, findingList, fields)
    if findingList ~= nil
        and findingList[1] ~= nil
        and (fields == nil or fields.targetFinding == nil)
    then
        fields = fields or {}
        fields.targetFinding = findingList[1]
    end
    local invalid = common.invalidAt(entry, code, message, fields)
    return invalid, findingList
end

function common.appendFindings(target, source)
    for _, finding in ipairs(source or common.EMPTY_LIST) do
        target[#target + 1] = finding
    end
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

function common.availabilityFailure(option, entry)
    local availability = option and option.availability or nil
    if availability == nil then
        return nil
    end
    if not common.rangeContains(availability.biomeDepthCache, entry and entry.biomeDepthCache) then
        return "biome_depth_unavailable"
    end
    if not common.rangeContains(availability.biomeEncounterDepth, entry and entry.biomeEncounterDepth) then
        return "encounter_depth_unavailable"
    end
    return nil
end

function common.routeStructureForBiome(biome)
    return biome and (
        biome.roomTopology
            or biome.fields and biome.fields.roomTopology
    ) or nil
end

function common.topologyExits(entry)
    local topology = entry and entry.topology or nil
    if topology == nil then
        return common.EMPTY_LIST
    end
    if topology.exits ~= nil then
        return topology.exits
    end
    local exits = {}
    if topology.selected ~= nil then
        exits[#exits + 1] = topology.selected
    end
    if topology.sibling ~= nil then
        exits[#exits + 1] = topology.sibling
    end
    return exits
end

function common.selectedExit(entry)
    local topology = entry and entry.topology or nil
    if topology ~= nil and topology.selected ~= nil then
        return topology.selected
    end
    return {
        structure = entry and entry.roleKey or nil,
        roomKey = entry and entry.roomKey or nil,
    }
end

function common.selectedAndGeneratedExits(entry)
    local topology = entry and entry.topology or nil
    if topology == nil then
        return { common.selectedExit(entry) }
    end
    return common.topologyExits(entry)
end

function common.generatedRoomKey(exit)
    return exit and (exit.roomKey or exit.optionKey) or nil
end

function common.generatedExitCount(entry)
    return #common.topologyExits(entry)
end

function common.biomeRoomEntries(history, biomeKey)
    local entries = {}
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        if entry.biomeKey == biomeKey and entry.eventSourceKind ~= "afterBiome" then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

return common
