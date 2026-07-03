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

local function roleAvailabilitySummaries(candidates, entry)
    local summaries = {}
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        local roleKey = candidate.roleKey
        if roleKey ~= nil and roleKey ~= "" and candidate.optionKey ~= nil and candidate.optionKey ~= "" then
            local targetRowIndex = candidate.targetRowIndex
            local summaryKey = tostring(roleKey) .. ":" .. tostring(targetRowIndex or entry and entry.rowIndex or "")
            local summary = summaries[summaryKey]
            if summary == nil then
                summary = {
                    roleKey = roleKey,
                    total = 0,
                    invalid = 0,
                    targetRowIndex = targetRowIndex,
                    targetRouteOrdinal = candidate.targetRouteOrdinal,
                    targetFormAddress = candidate.targetFormAddress,
                }
                summaries[summaryKey] = summary
            end
            summary.total = summary.total + 1

            local availability = candidate.optionAvailability or candidate.roleAvailability
            local failure, axis, expected, actual = nil, nil, nil, nil
            if availability ~= nil then
                failure, axis, expected, actual = common.availabilityFailure(
                    availability,
                    common.candidateAvailabilityContext(candidate)
                )
            end
            if failure == nil then
                summary.hasAvailable = true
            else
                summary.invalid = summary.invalid + 1
                if summary.failure == nil then
                    summary.failure = failure
                    summary.axis = axis
                    summary.expected = expected
                    summary.actual = actual
                end
            end
        end
    end
    return summaries
end

local function appendRoleAvailabilityFindings(target, entry, candidates)
    for _, summary in pairs(roleAvailabilitySummaries(candidates, entry)) do
        if summary.total > 0
            and summary.invalid == summary.total
            and not summary.hasAvailable
        then
            target[#target + 1] = findings.roomCandidateInvalid(
                entry,
                { roleKey = summary.roleKey },
                summary.failure,
                {
                    controlAlias = "RoleKey",
                    controlValue = summary.roleKey,
                    rowIndex = summary.targetRowIndex,
                    routeOrdinal = summary.targetRouteOrdinal,
                    formAddress = summary.targetFormAddress,
                    axis = summary.axis,
                    expected = summary.expected,
                    actual = summary.actual,
                }
            )
        end
    end
end

function rooms.appendFindings(target, history, step)
    local entry = step and step.entry or nil
    local candidates = step and step.candidates and step.candidates.rooms or EMPTY_LIST
    for _, candidate in ipairs(candidates) do
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
    appendRoleAvailabilityFindings(target, entry, candidates)
end

return rooms
