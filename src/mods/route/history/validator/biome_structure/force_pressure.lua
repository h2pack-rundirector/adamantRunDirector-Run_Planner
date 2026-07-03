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

local function forceDeadlineDepth(force)
    local range = force and force.biomeDepthCache or nil
    if range == nil then
        return nil
    end
    return range.exact or range.max
end

local function stepEntry(step)
    return step and step.entry or nil
end

local function stepExits(step)
    return step and step.topology and step.topology.exits or EMPTY_LIST
end

local function stepGeneratedExitCount(step)
    return step and step.topology and step.topology.generatedExitCount or 0
end

local function generatedCandidateAt(step, candidate)
    for _, exit in ipairs(stepExits(step)) do
        if common.generatedRoomKey(exit) == candidate then
            return true
        end
    end
    return false
end

local function generatedCandidatesThrough(steps, index, candidates)
    local generated = {}
    for currentIndex = 1, index do
        for _, candidate in ipairs(candidates or EMPTY_LIST) do
            if generated[candidate] == nil and generatedCandidateAt(steps[currentIndex], candidate) then
                generated[candidate] = true
            end
        end
    end
    return generated
end

local function generatedCandidateCountThrough(steps, index, candidates)
    local generated = generatedCandidatesThrough(steps, index, candidates)
    local count = 0
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        if generated[candidate] then
            count = count + 1
        end
    end
    return count
end

local function pickedCandidateBefore(steps, index, candidates)
    for currentIndex = 1, index - 1 do
        local entry = stepEntry(steps[currentIndex])
        if candidateInList(candidates, entry and entry.roomKey) then
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

local function forceCandidateAvailable(option, step)
    return option ~= nil and common.availabilityFailure(option, stepEntry(step)) == nil
end

local function generatedForceWindowCandidateCount(steps, index, optionsByRoomKey)
    local step = steps[index]
    local entry = stepEntry(step)
    local count = 0
    for roomKey, option in pairs(optionsByRoomKey) do
        if forceCandidateAvailable(option, step)
            and forceWindowActive(option.force, entry and entry.biomeDepthCache)
            and generatedCandidateAt(step, roomKey)
        then
            count = count + 1
        end
    end
    return count
end

local function validateUngroupedForce(topology, steps, index, optionsByRoomKey)
    local step = steps[index]
    local entry = stepEntry(step)
    local capacity = stepGeneratedExitCount(step)
    if capacity <= 0 then
        return nil
    end

    local missingForceOption = nil
    for _, candidate in ipairs(preparedForceCandidates(topology)) do
        local option = optionsByRoomKey[candidate]
        if forceCandidateAvailable(option, step)
            and forceDeadlineActive(option.force, entry and entry.biomeDepthCache)
            and not generatedCandidateAt(step, candidate)
        then
            missingForceOption = option
            break
        end
    end
    if missingForceOption == nil then
        return nil
    end
    local generatedCount = generatedForceWindowCandidateCount(steps, index, optionsByRoomKey)
    if generatedCount >= capacity then
        return nil
    end
    return common.invalidAt(
        entry,
        "forced_topology_pressure_unresolved",
        {
            topologyForceLabel = missingForceOption.label,
            deadlineBiomeDepthCache = forceDeadlineDepth(missingForceOption.force),
            generatedCount = generatedCount,
            requiredGeneratedCount = capacity,
        }
    )
end

local function requiredGeneratedCount(group, step)
    if group.requiredGeneratedCount ~= nil then
        return group.requiredGeneratedCount
    end
    if group.generatedExitCount ~= nil then
        return math.min(#(group.candidates or EMPTY_LIST), group.generatedExitCount)
    end
    return math.min(#(group.candidates or EMPTY_LIST), stepGeneratedExitCount(step))
end

local function validateForcedGroup(steps, index, group)
    local step = steps[index]
    local entry = stepEntry(step)
    local deadline = group.forceAtBiomeDepthMax
    if deadline == nil or (entry.biomeDepthCache or 0) < deadline then
        return nil
    end
    if group.pickedCandidateBeforeDeadlineClosesGroup
        and pickedCandidateBefore(steps, index, group.candidates)
    then
        return nil
    end
    local required = requiredGeneratedCount(group, step)
    local generatedCount = generatedCandidateCountThrough(steps, index, group.candidates)
    if generatedCount >= required then
        return nil
    end
    return common.invalidAt(
        entry,
        "forced_topology_group_unresolved",
        {
            topologyGroupKey = group.key,
            topologyGroupLabel = group.label,
            deadlineBiomeDepthCache = deadline,
            generatedCount = generatedCount,
            requiredGeneratedCount = required,
        }
    )
end

function forcePressure.validate(steps, biome)
    local topology = common.routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    local optionsByRoomKey = topologyOptionsByRoomKey(topology)
    for index = 1, #(steps or EMPTY_LIST) do
        local invalid = validateUngroupedForce(topology, steps, index, optionsByRoomKey)
        if invalid ~= nil then
            return invalid
        end
        for _, group in ipairs(topology.forcedGroups or EMPTY_LIST) do
            invalid = validateForcedGroup(steps, index, group)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

return forcePressure
