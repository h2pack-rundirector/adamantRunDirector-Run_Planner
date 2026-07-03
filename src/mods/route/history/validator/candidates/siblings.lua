local deps = ... or {}

local common = deps.common
local findings = deps.findings
local routeHistory = deps.history

local siblings = {}

local EMPTY_LIST = common.EMPTY_LIST

local function entryBefore(entry, candidate)
    local entryRoomHistory = entry and entry.roomHistoryOrdinal or nil
    local candidateRoomHistory = candidate and candidate.roomHistoryOrdinal or nil
    if entryRoomHistory ~= nil and candidateRoomHistory ~= nil then
        return candidateRoomHistory < entryRoomHistory
    end
    local entryOrdinal = entry and entry.routeOrdinal or nil
    local candidateOrdinal = candidate and candidate.routeOrdinal or nil
    if entryOrdinal ~= nil and candidateOrdinal ~= nil then
        return candidateOrdinal < entryOrdinal
    end
    return false
end

local function topologyForBiome(biome)
    return biome and (
        biome.roomTopology
            or biome.fields and biome.fields.roomTopology
    ) or nil
end

local function forEachSiblingExit(entry, callback)
    local topology = entry and entry.topology or nil
    if topology == nil then
        return nil
    end
    if topology.exits == nil then
        local otherDoors = topology.otherDoors or topology.siblings
        if otherDoors ~= nil then
            for _, door in ipairs(otherDoors) do
                local result = callback(door)
                if result ~= nil then
                    return result
                end
            end
            return nil
        end
        if topology.sibling ~= nil then
            return callback(topology.sibling)
        end
        return nil
    end

    for _, exit in ipairs(topology.exits) do
        if exit.branch == "sibling" or exit.siblingIndex ~= nil then
            local result = callback(exit)
            if result ~= nil then
                return result
            end
        end
    end
    return nil
end

local function generatedRoomKey(exit)
    return exit and (exit.roomKey or exit.optionKey) or nil
end

local function candidateRoomKey(candidate)
    return candidate and (candidate.roomKey or candidate.optionKey) or nil
end

local function siblingIndex(value)
    local index = math.floor(tonumber(value) or 1)
    if index < 1 then
        return 1
    end
    return index
end

local function selectedSiblingRoomAlreadySelected(entry, candidate)
    local roomKey = candidateRoomKey(candidate)
    if roomKey == nil then
        return false
    end
    local candidateSiblingIndex = siblingIndex(candidate and candidate.siblingIndex)
    return forEachSiblingExit(entry, function(exit)
        local exitSiblingIndex = siblingIndex(exit.siblingIndex)
        if exitSiblingIndex ~= candidateSiblingIndex and generatedRoomKey(exit) == roomKey then
            return true
        end
        return nil
    end) == true
end

local function siblingRoomGeneratedBefore(history, entry, roomKey)
    if roomKey == nil then
        return false
    end
    for _, priorEntry in ipairs(routeHistory.byKind(history, "room")) do
        if priorEntry.biomeKey == entry.biomeKey and entryBefore(entry, priorEntry) then
            local found = forEachSiblingExit(priorEntry, function(exit)
                if generatedRoomKey(exit) == roomKey then
                    return true
                end
                return nil
            end)
            if found then
                return true
            end
        end
    end
    return false
end

local function plannedRoomRowIndex(history, entry, roomKey)
    if roomKey == nil then
        return nil
    end
    for _, room in ipairs(routeHistory.byKind(history, "room")) do
        if room.biomeKey == entry.biomeKey
            and room.rowIndex ~= entry.rowIndex
            and room.roomKey == roomKey
        then
            return room.rowIndex
        end
    end
    return nil
end

local function candidateInList(candidates, roomKey)
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        if candidate == roomKey then
            return true
        end
    end
    return false
end

local function pickedCandidateBefore(history, entry, group)
    for _, room in ipairs(routeHistory.byKind(history, "room")) do
        if room.biomeKey == entry.biomeKey
            and entryBefore(entry, room)
            and candidateInList(group.candidates, room.roomKey)
        then
            return true
        end
    end
    return false
end

local function pickedCandidateClosesGroup(history, entry, topology, roomKey)
    for _, group in ipairs(topology and topology.forcedGroups or EMPTY_LIST) do
        if group.pickedCandidateBeforeDeadlineClosesGroup
            and candidateInList(group.candidates, roomKey)
            and pickedCandidateBefore(history, entry, group)
        then
            return true
        end
    end
    return false
end

local function appendFinding(target, entry, candidate, reason)
    target[#target + 1] = findings.siblingCandidateInvalid(entry, candidate, reason)
end

local function appendStructuralFindings(target, history, entry, biome, candidate)
    local roomKey = candidateRoomKey(candidate)
    if roomKey ~= nil and roomKey == entry.roomKey then
        appendFinding(target, entry, candidate, "sibling_same_room")
    end
    if selectedSiblingRoomAlreadySelected(entry, candidate) then
        appendFinding(target, entry, candidate, "sibling_same_sibling_room")
    end
    if siblingRoomGeneratedBefore(history, entry, roomKey) then
        appendFinding(target, entry, candidate, "sibling_room_generated")
    end
    if pickedCandidateClosesGroup(history, entry, topologyForBiome(biome), roomKey) then
        appendFinding(target, entry, candidate, "sibling_miniboss_after_selected")
    end
    if plannedRoomRowIndex(history, entry, roomKey) ~= nil then
        appendFinding(target, entry, candidate, "sibling_room_planned")
    end
end

function siblings.appendFindings(target, history, step)
    local entry = step and step.entry or nil
    local biome = step and step.biome or nil
    for _, candidate in ipairs(step and step.candidates and step.candidates.siblings or EMPTY_LIST) do
        common.appendAvailabilityFinding(
            target,
            findings.siblingCandidateInvalid,
            entry,
            candidate,
            candidate.availability
        )
        appendStructuralFindings(target, history, entry, biome, candidate)
    end
end

return siblings
