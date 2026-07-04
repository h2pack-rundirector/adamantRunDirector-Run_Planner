local deps = ... or {}

local common = deps.common

local forcePressure = {}

local EMPTY_LIST = common.EMPTY_LIST

local function topologyOptionsByRoomKey(topology)
    local lookup = {}
    local control = topology and (topology.generatedDoorControl or topology.otherDoorControl) or nil
    local options = control and control.options or EMPTY_LIST
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

local function groupedCandidates(topology)
    local lookup = {}
    for _, group in ipairs(topology and topology.forcedGroups or EMPTY_LIST) do
        for _, candidate in ipairs(group.candidates or EMPTY_LIST) do
            lookup[candidate] = group
        end
    end
    return lookup
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

local function forceContext(step)
    return step and step.phases and step.phases.offer or stepEntry(step)
end

local function generatedCandidateAt(step, candidate)
    for _, exit in ipairs(stepExits(step)) do
        if common.generatedRoomKey(exit) == candidate then
            return true
        end
    end
    return false
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

local function forceCandidateAvailable(option, step)
    return option ~= nil and common.availabilityFailure(option, forceContext(step)) == nil
end

local function groupClosedBefore(steps, index, group)
    return group ~= nil
        and group.pickedCandidateBeforeDeadlineClosesGroup
        and pickedCandidateBefore(steps, index, group.candidates)
end

local function activeForceCandidates(steps, index, optionsByRoomKey, groupsByCandidate)
    local step = steps[index]
    local context = forceContext(step)
    local active = {}
    for roomKey, option in pairs(optionsByRoomKey) do
        local group = groupsByCandidate[roomKey]
        if option.force ~= nil
            and not groupClosedBefore(steps, index, group)
            and forceCandidateAvailable(option, step)
            and forceWindowActive(option.force, context and context.biomeDepthCache)
        then
            active[roomKey] = option
        end
    end
    return active
end

local function generatedCandidatesThrough(steps, index, candidates, optionsByRoomKey, groupsByCandidate)
    local generated = {}
    for currentIndex = 1, index do
        local active = activeForceCandidates(steps, currentIndex, optionsByRoomKey, groupsByCandidate)
        for _, candidate in ipairs(candidates or EMPTY_LIST) do
            if generated[candidate] == nil
                and active[candidate] ~= nil
                and generatedCandidateAt(steps[currentIndex], candidate)
            then
                generated[candidate] = true
            end
        end
    end
    return generated
end

local function generatedCandidateCountThrough(steps, index, candidates, optionsByRoomKey, groupsByCandidate)
    local generated = generatedCandidatesThrough(steps, index, candidates, optionsByRoomKey, groupsByCandidate)
    local count = 0
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        if generated[candidate] then
            count = count + 1
        end
    end
    return count
end

local function generatedActiveForceCandidateCount(step, active)
    local count = 0
    local seen = {}
    for _, exit in ipairs(stepExits(step)) do
        local roomKey = common.generatedRoomKey(exit)
        if roomKey ~= nil
            and active[roomKey] ~= nil
            and not seen[roomKey]
        then
            seen[roomKey] = true
            count = count + 1
        end
    end
    return count
end

local function forceSaturated(step, active)
    local capacity = stepGeneratedExitCount(step)
    return capacity > 0 and generatedActiveForceCandidateCount(step, active) >= capacity
end

local function forcePressurePayload(option, step, active)
    return {
        topologyForceLabel = option.label,
        deadlineBiomeDepthCache = forceDeadlineDepth(option.force),
        generatedCount = generatedActiveForceCandidateCount(step, active),
        requiredGeneratedCount = stepGeneratedExitCount(step),
    }
end

local function validateUngroupedForce(step, optionsByRoomKey, groupsByCandidate, active)
    if stepGeneratedExitCount(step) <= 0 then
        return nil
    end

    local context = forceContext(step)
    for candidate, option in pairs(optionsByRoomKey) do
        if groupsByCandidate[candidate] == nil
            and active[candidate] ~= nil
            and forceDeadlineActive(option.force, context and context.biomeDepthCache)
            and not generatedCandidateAt(step, candidate)
        then
            if forceSaturated(step, active) then
                return nil
            end
            return common.invalidAt(
                stepEntry(step),
                "forced_topology_pressure_unresolved",
                forcePressurePayload(option, step, active)
            )
        end
    end
    return nil
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

local function validateForcedGroup(steps, index, group, optionsByRoomKey, groupsByCandidate)
    local step = steps[index]
    local entry = stepEntry(step)
    local deadline = group.forceAtBiomeDepthMax
    local context = forceContext(step)
    if deadline == nil or (context and context.biomeDepthCache or 0) < deadline then
        return nil
    end
    if group.pickedCandidateBeforeDeadlineClosesGroup
        and pickedCandidateBefore(steps, index, group.candidates)
    then
        return nil
    end
    local required = requiredGeneratedCount(group, step)
    local generatedCount = generatedCandidateCountThrough(
        steps,
        index,
        group.candidates,
        optionsByRoomKey,
        groupsByCandidate
    )
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

local function validateForcedGroupWithActive(steps, index, group, active, optionsByRoomKey, groupsByCandidate)
    local invalid = validateForcedGroup(steps, index, group, optionsByRoomKey, groupsByCandidate)
    if invalid == nil or forceSaturated(steps[index], active) then
        return nil
    end
    return invalid
end

function forcePressure.validate(steps, biome)
    local topology = common.routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    local optionsByRoomKey = topologyOptionsByRoomKey(topology)
    local groupsByCandidate = groupedCandidates(topology)
    for index = 1, #(steps or EMPTY_LIST) do
        local active = activeForceCandidates(steps, index, optionsByRoomKey, groupsByCandidate)
        local invalid = validateUngroupedForce(steps[index], optionsByRoomKey, groupsByCandidate, active)
        if invalid ~= nil then
            return invalid
        end
        for _, group in ipairs(topology.forcedGroups or EMPTY_LIST) do
            invalid = validateForcedGroupWithActive(steps, index, group, active, optionsByRoomKey, groupsByCandidate)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

return forcePressure
