local deps = ... or {}

local routeHistory = deps.history
local findings = deps.findings
local rewardValidator = deps.rewards
local selectedLegalityRules = deps.selectedLegalityRules

local candidates = {}

local EMPTY_LIST = {}
local REWARD_CANDIDATE_OPTS = {
    skipRequirementKinds = {
        CurrentLootSourcesSeen = true,
    },
}

local function validResult(candidateFindings)
    return {
        valid = true,
        invalids = {},
        findings = candidateFindings or {},
    }
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

local function availabilityFailure(availability, entry)
    if availability == nil then
        return nil
    end
    if not rangeContains(availability.biomeDepthCache, entry and entry.biomeDepthCache) then
        return "biome_depth_unavailable", "biomeDepthCache", availability.biomeDepthCache, entry.biomeDepthCache
    end
    if not rangeContains(availability.biomeEncounterDepth, entry and entry.biomeEncounterDepth) then
        return "encounter_depth_unavailable", "biomeEncounterDepth", availability.biomeEncounterDepth, entry.biomeEncounterDepth
    end
    return nil
end

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

local function appendAvailabilityFinding(target, createFinding, entry, candidate, availability)
    local failure, axis, expected, actual = availabilityFailure(availability, entry)
    if failure == nil then
        return
    end
    target[#target + 1] = createFinding(entry, candidate, failure, {
        axis = axis,
        expected = expected,
        actual = actual,
    })
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

local function appendRoomCandidateFindings(target, history, entry)
    for _, candidate in ipairs(entry.roomCandidates or EMPTY_LIST) do
        appendAvailabilityFinding(
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

local function appendSiblingCandidateFindings(target, entry)
    for _, candidate in ipairs(entry.siblingCandidates or EMPTY_LIST) do
        appendAvailabilityFinding(
            target,
            findings.siblingCandidateInvalid,
            entry,
            candidate,
            candidate.availability
        )
        local selected = entry and entry.topology and entry.topology.selected or nil
        if string.match(tostring(selected and selected.structure or ""), "^CombatCage%d+$") ~= nil
            and string.match(tostring(candidate and candidate.structure or ""), "^CombatCage%d+$") ~= nil
            and math.floor(tonumber(selected.offerCount) or 0)
                ~= math.floor(tonumber(candidate.offerCount) or 0)
        then
            target[#target + 1] = findings.siblingCandidateInvalid(
                entry,
                candidate,
                "fields_sibling_combat_cage_count_mismatch",
                {
                    message = "Sibling combat reward count must match selected combat reward count",
                }
            )
        end
    end
end

local function appendVariantCandidateFindings(target, entry)
    for _, candidate in ipairs(entry.variantCandidates or EMPTY_LIST) do
        if not rangeContains(candidate.availableAtBiomeEncounterDepth, entry and entry.biomeEncounterDepth) then
            target[#target + 1] = findings.variantCandidateInvalid(
                entry,
                candidate,
                "encounter_depth_unavailable",
                {
                    controlAlias = candidate.controlAlias or "VariantKey",
                    expected = candidate.availableAtBiomeEncounterDepth,
                    actual = entry and entry.biomeEncounterDepth or nil,
                }
            )
        end
    end
end

local function lootCandidateEntry(entry, candidate, rewardType)
    local loot = {}
    for key, value in pairs(entry or {}) do
        loot[key] = value
    end
    loot.kind = "lootCandidate"
    loot.eventKey = rewardType
    loot.lootType = rewardType
    loot.parentEntry = entry
    loot.parentRoomKey = entry and entry.roomKey or nil
    loot.address = candidate and candidate.address or "row"
    loot.rewardClass = candidate and candidate.rewardClass or nil
    loot.rewardStore = candidate and candidate.rewardStore or nil
    return loot
end

local function appendRewardTypeCandidateFinding(target, history, entry, candidate, rewardType, rulesByTarget)
    local invalid = rewardValidator.invalidForLootType(
        history,
        lootCandidateEntry(entry, candidate, rewardType),
        rewardType,
        rulesByTarget,
        REWARD_CANDIDATE_OPTS
    )
    if invalid == nil then
        return
    end
    target[#target + 1] = findings.rewardCandidateInvalid(
        entry,
        candidate,
        rewardType,
        invalid.code,
        {
            message = invalid.message,
            requirement = invalid.requirement,
            relatedEvents = invalid.relatedEvents,
        }
    )
end

local function appendRewardCandidateFindings(target, history, entry, rulesByTarget)
    for _, candidate in ipairs(entry.rewardCandidates or EMPTY_LIST) do
        if candidate.kind == "rewardType" or candidate.kind == "fixedReward" then
            for _, rewardType in ipairs(candidate.rewardTypes or EMPTY_LIST) do
                appendRewardTypeCandidateFinding(target, history, entry, candidate, rewardType, rulesByTarget)
            end
        end
    end
end

function candidates.validate(args)
    local history = args and args.history or nil
    local rulesByTarget = rewardValidator.rulesByTarget(selectedLegalityRules)
    local candidateFindings = {}
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        appendRoomCandidateFindings(candidateFindings, history, entry)
        appendSiblingCandidateFindings(candidateFindings, entry)
        appendVariantCandidateFindings(candidateFindings, entry)
        appendRewardCandidateFindings(candidateFindings, history, entry, rulesByTarget)
    end
    return validResult(candidateFindings)
end

return candidates
