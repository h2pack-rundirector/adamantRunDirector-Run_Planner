local deps = ... or {}

local common = deps.common

local forcePressure = {}

local EMPTY_LIST = common.EMPTY_LIST

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

local function generatedCandidateAt(entry, candidate)
    for _, exit in ipairs(common.topologyExits(entry)) do
        if common.generatedRoomKey(exit) == candidate then
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
    return option ~= nil and common.availabilityFailure(option, entry) == nil
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
    local capacity = common.generatedExitCount(entry)
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
    return common.invalidAt(
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
    return math.min(#(group.candidates or EMPTY_LIST), common.generatedExitCount(entry))
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
    return common.invalidAt(
        entry,
        "forced_topology_group_unresolved",
        "Forced " .. tostring(group.key or "topology") .. " deadline needs generated forced doors",
        {
            topologyGroupKey = group.key,
        }
    )
end

function forcePressure.validate(history, biome)
    local topology = common.routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    local entries = common.biomeRoomEntries(history, biome.key)
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

return forcePressure
