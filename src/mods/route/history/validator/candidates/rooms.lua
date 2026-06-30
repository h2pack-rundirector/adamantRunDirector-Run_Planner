local deps = ... or {}

local common = deps.common
local routeHistory = deps.history
local findings = deps.findings

local rooms = {}

local EMPTY_LIST = common.EMPTY_LIST

local function hasTag(tags, expected)
    for _, tag in ipairs(tags or EMPTY_LIST) do
        if tag == expected then
            return true
        end
    end
    return false
end

local function nextRoomTagsFailure(requiredTags, tags)
    if requiredTags == nil then
        return nil
    end
    for _, requiredTag in ipairs(requiredTags) do
        if hasTag(tags, requiredTag) then
            return nil
        end
    end
    return "previous_room_next_tags"
end

local function roomEntryBefore(entry, candidate)
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

local function roleCap(candidate)
    return candidate and (
        candidate.roleMaxCreationsThisRun
            or candidate.roleMaxAppearancesThisBiome
            or candidate.maxSelectionsPerBiome
    ) or nil
end

local function optionCap(candidate)
    return candidate and (
        candidate.optionMaxCreationsThisRun
            or candidate.optionMaxAppearancesThisBiome
    ) or nil
end

local function priorRoleCount(history, entry, roleKey)
    if roleKey == nil or roleKey == "" then
        return 0
    end
    local count = 0
    for _, room in ipairs(routeHistory.byKind(history, "room")) do
        if room.biomeKey == entry.biomeKey
            and room.roleKey == roleKey
            and roomEntryBefore(entry, room)
        then
            count = count + 1
        end
    end
    return count
end

local function priorOptionCount(history, entry, optionKey)
    if optionKey == nil or optionKey == "" then
        return 0
    end
    local count = 0
    for _, room in ipairs(routeHistory.byKind(history, "room")) do
        if room.biomeKey == entry.biomeKey
            and room.optionKey == optionKey
            and roomEntryBefore(entry, room)
        then
            count = count + 1
        end
    end
    return count
end

local function previousRoomEntry(history, entry)
    local previous = nil
    for _, room in ipairs(routeHistory.byKind(history, "room")) do
        if room.biomeKey == entry.biomeKey and roomEntryBefore(entry, room) then
            if previous == nil or roomEntryBefore(room, previous) then
                previous = room
            end
        end
    end
    return previous
end

local function appendNextRoomTagsFinding(target, history, entry, candidate)
    local previous = previousRoomEntry(history, entry)
    local requiredTags = previous and previous.nextRoomTags or nil
    if nextRoomTagsFailure(requiredTags, candidate and candidate.tags) == nil then
        return
    end
    target[#target + 1] = findings.roomCandidateInvalid(entry, candidate, "previous_room_next_tags", {
        controlAlias = "OptionKey",
        controlValue = candidate and candidate.optionKey or nil,
        requiredTags = requiredTags,
    })
end

local function appendCapFindings(target, history, entry, candidate)
    local roleLimit = roleCap(candidate)
    if roleLimit ~= nil
        and priorRoleCount(history, entry, candidate.roleKey) >= roleLimit
    then
        target[#target + 1] = findings.roomCandidateInvalid(entry, candidate, "role_limit", {
            controlAlias = "RoleKey",
            controlValue = candidate.roleKey,
        })
    end

    local optionLimit = optionCap(candidate)
    if optionLimit ~= nil
        and priorOptionCount(history, entry, candidate.optionKey) >= optionLimit
    then
        target[#target + 1] = findings.roomCandidateInvalid(entry, candidate, "option_limit", {
            controlAlias = "OptionKey",
            controlValue = candidate.optionKey,
        })
    end
end

function rooms.appendFindings(target, history, entry)
    for _, candidate in ipairs(entry.roomCandidates or EMPTY_LIST) do
        common.appendAvailabilityFinding(
            target,
            findings.roomCandidateInvalid,
            entry,
            candidate,
            candidate.optionAvailability or candidate.roleAvailability
        )
        appendCapFindings(target, history, entry, candidate)
        appendNextRoomTagsFinding(target, history, entry, candidate)
    end
end

return rooms
