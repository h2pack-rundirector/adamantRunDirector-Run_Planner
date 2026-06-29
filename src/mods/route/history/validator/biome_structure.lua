local deps = ... or {}

local routeHistory = deps.history

local biomeStructure = {}

local EMPTY_LIST = {}

local function validResult()
    return {
        valid = true,
        invalids = {},
    }
end

local function invalidAt(entry, code, message, fields)
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

local function rangeContains(range, value)
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

local function availabilityFailure(option, entry)
    local availability = option and option.availability or nil
    if availability == nil then
        return nil
    end
    if not rangeContains(availability.biomeDepthCache, entry and entry.biomeDepthCache) then
        return "biome_depth_unavailable"
    end
    if not rangeContains(availability.biomeEncounterDepth, entry and entry.biomeEncounterDepth) then
        return "encounter_depth_unavailable"
    end
    return nil
end

local function optionList(role)
    return role and (role.roomOptions or role.mapOptions) or EMPTY_LIST
end

local function optionByKey(role, key)
    if role == nil or key == nil or key == "" then
        return nil
    end
    if role.optionsByKey ~= nil then
        return role.optionsByKey[key]
    end
    for _, option in ipairs(optionList(role)) do
        if option.key == key then
            return option
        end
    end
    return nil
end

local function optionByRoomKey(role, roomKey)
    if role == nil or roomKey == nil or roomKey == "" then
        return nil
    end
    for _, option in ipairs(optionList(role)) do
        if option.key == roomKey then
            return option
        end
    end
    return nil
end

local function declarationForEntry(biome, entry)
    local role = biome
        and biome.rolesByKey
        and biome.rolesByKey[entry and entry.roleKey or nil]
        or nil
    local option = optionByKey(role, entry and entry.optionKey)
        or optionByRoomKey(role, entry and entry.roomKey)
    return role, option
end

local function capFor(value)
    return value and (
        value.maxCreationsThisRun
            or value.maxAppearancesThisBiome
            or value.routeRules and value.routeRules.maxSelectionsPerBiome
    ) or nil
end

local function appendCount(counts, key)
    if key == nil or key == "" then
        return 0
    end
    local value = (counts[key] or 0) + 1
    counts[key] = value
    return value
end

local function routeStructureForBiome(biome)
    return biome and (
        biome.roomTopology
            or biome.fields and biome.fields.roomTopology
    ) or nil
end

local function topologyOptionsByRoomKey(topology)
    local lookup = {}
    local options = topology
        and topology.siblingStructureControl
        and topology.siblingStructureControl.options
        or EMPTY_LIST
    for _, option in ipairs(options) do
        local roomKey = option.roomKey or (option.structure == "Miniboss" and option.key or nil)
        if roomKey ~= nil and roomKey ~= "" then
            lookup[roomKey] = option
        end
    end
    return lookup
end

local function candidateInList(candidates, roomKey)
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        if candidate == roomKey then
            return true
        end
    end
    return false
end

local function forceWindowActive(force, depth)
    local range = force and force.biomeDepthCache or nil
    if range == nil or depth == nil then
        return false
    end
    if range.exact ~= nil then
        return depth == range.exact
    end
    if range.min ~= nil and depth < range.min then
        return false
    end
    return range.min ~= nil or range.max ~= nil
end

local function forceDeadlineActive(force, depth)
    local range = force and force.biomeDepthCache or nil
    if range == nil or depth == nil then
        return false
    end
    if range.exact ~= nil then
        return depth == range.exact
    end
    if range.min ~= nil and depth < range.min then
        return false
    end
    return range.max ~= nil and depth >= range.max
end

local function topologyExits(entry)
    local topology = entry and entry.topology or nil
    if topology == nil then
        return EMPTY_LIST
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

local function generatedRoomKey(exit)
    return exit and (exit.roomKey or exit.optionKey) or nil
end

local function generatedExitCount(entry)
    return #topologyExits(entry)
end

local function generatedCandidateAt(entry, candidate)
    for _, exit in ipairs(topologyExits(entry)) do
        if generatedRoomKey(exit) == candidate then
            return true
        end
    end
    return false
end

local function generatedCandidatesThrough(entries, index, candidates)
    local generated = {}
    for currentIndex = 1, index do
        local entry = entries[currentIndex]
        for _, candidate in ipairs(candidates or EMPTY_LIST) do
            if generated[candidate] == nil and generatedCandidateAt(entry, candidate) then
                generated[candidate] = true
            end
        end
    end
    return generated
end

local function generatedCandidateCountThrough(entries, index, candidates)
    local generated = generatedCandidatesThrough(entries, index, candidates)
    local count = 0
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        if generated[candidate] then
            count = count + 1
        end
    end
    return count
end

local function pickedCandidateBefore(entries, index, candidates)
    for currentIndex = 1, index - 1 do
        if candidateInList(candidates, entries[currentIndex] and entries[currentIndex].roomKey) then
            return true
        end
    end
    return false
end

local function preparedForceCandidates(topology)
    local grouped = {}
    for _, group in ipairs(topology and topology.forcedGroups or EMPTY_LIST) do
        for _, candidate in ipairs(group.candidates or EMPTY_LIST) do
            grouped[candidate] = true
        end
    end

    local candidates = {}
    for roomKey, option in pairs(topologyOptionsByRoomKey(topology)) do
        if option.force ~= nil and not grouped[roomKey] then
            candidates[#candidates + 1] = roomKey
        end
    end
    return candidates
end

local function forceCandidateAvailable(option, entry)
    return option ~= nil and availabilityFailure(option, entry) == nil
end

local function generatedForceWindowCandidateCount(entries, index, optionsByRoomKey)
    local entry = entries[index]
    local count = 0
    for roomKey, option in pairs(optionsByRoomKey) do
        if forceCandidateAvailable(option, entry)
            and forceWindowActive(option.force, entry and entry.biomeDepthCache)
            and generatedCandidateAt(entry, roomKey)
        then
            count = count + 1
        end
    end
    return count
end

local function validateUngroupedForce(topology, entries, index, optionsByRoomKey)
    local entry = entries[index]
    local capacity = generatedExitCount(entry)
    if capacity <= 0 then
        return nil
    end

    local hasMissingHardForce = false
    for _, candidate in ipairs(preparedForceCandidates(topology)) do
        local option = optionsByRoomKey[candidate]
        if forceCandidateAvailable(option, entry)
            and forceDeadlineActive(option.force, entry and entry.biomeDepthCache)
            and not generatedCandidateAt(entry, candidate)
        then
            hasMissingHardForce = true
            break
        end
    end
    if not hasMissingHardForce then
        return nil
    end
    if generatedForceWindowCandidateCount(entries, index, optionsByRoomKey) >= capacity then
        return nil
    end
    return invalidAt(
        entry,
        "forced_topology_pressure_unresolved",
        "Hard-forced topology needs generated force-window doors"
    )
end

local function requiredGeneratedCount(group, entry)
    if group.requiredGeneratedCount ~= nil then
        return group.requiredGeneratedCount
    end
    if group.generatedExitCount ~= nil then
        return math.min(#(group.candidates or EMPTY_LIST), group.generatedExitCount)
    end
    return math.min(#(group.candidates or EMPTY_LIST), generatedExitCount(entry))
end

local function validateForcedGroup(entries, index, group)
    local entry = entries[index]
    local deadline = group.forceAtBiomeDepthMax
    if deadline == nil or (entry.biomeDepthCache or 0) < deadline then
        return nil
    end
    if group.pickedCandidateBeforeDeadlineClosesGroup
        and pickedCandidateBefore(entries, index, group.candidates)
    then
        return nil
    end
    local required = requiredGeneratedCount(group, entry)
    if generatedCandidateCountThrough(entries, index, group.candidates) >= required then
        return nil
    end
    return invalidAt(
        entry,
        "forced_topology_group_unresolved",
        "Forced " .. tostring(group.key or "topology") .. " deadline needs generated forced doors",
        {
            topologyGroupKey = group.key,
        }
    )
end

local function biomeRoomEntries(history, biomeKey)
    local entries = {}
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        if entry.biomeKey == biomeKey and entry.sourceKind ~= "afterBiome" then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

local function validatePickedEntries(history, biome)
    local roleCounts = {}
    local optionCounts = {}
    for _, entry in ipairs(biomeRoomEntries(history, biome.key)) do
        local role, option = declarationForEntry(biome, entry)
        if option ~= nil then
            local failure = availabilityFailure(option, entry)
            if failure ~= nil then
                return invalidAt(entry, failure, "Room is not valid at this generated depth")
            end
        end

        local roleCap = capFor(role)
        if roleCap ~= nil and appendCount(roleCounts, role.key) > roleCap then
            return invalidAt(entry, "role_limit", tostring(role.label or role.key) .. " is already planned")
        end

        local optionCap = capFor(option)
        if optionCap ~= nil and appendCount(optionCounts, option.key) > optionCap then
            return invalidAt(
                entry,
                "option_limit",
                tostring(option.label or option.key) .. " is already generated"
            )
        end
    end
    return nil
end

local function validateForcePressure(history, biome)
    local topology = routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    local entries = biomeRoomEntries(history, biome.key)
    local optionsByRoomKey = topologyOptionsByRoomKey(topology)
    for index = 1, #entries do
        local invalid = validateUngroupedForce(topology, entries, index, optionsByRoomKey)
        if invalid ~= nil then
            return invalid
        end
        for _, group in ipairs(topology.forcedGroups or EMPTY_LIST) do
            invalid = validateForcedGroup(entries, index, group)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

function biomeStructure.validate(args)
    local history = args and args.history or nil
    local route = args and args.route or nil
    local biomeLookup = args and args.biomeLookup or nil
    for _, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        local biome = biomeLookup and biomeLookup[biomeKey] or nil
        if biome ~= nil then
            local invalid = validatePickedEntries(history, biome)
                or validateForcePressure(history, biome)
            if invalid ~= nil then
                return {
                    valid = false,
                    invalids = { invalid },
                }
            end
        end
    end
    return validResult()
end

return biomeStructure
