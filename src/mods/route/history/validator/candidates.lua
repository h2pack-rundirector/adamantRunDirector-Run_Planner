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

local function appendRoomCandidateFindings(target, entry)
    for _, candidate in ipairs(entry.roomCandidates or EMPTY_LIST) do
        appendAvailabilityFinding(
            target,
            findings.roomCandidateInvalid,
            entry,
            candidate,
            candidate.optionAvailability or candidate.roleAvailability
        )
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
        appendRoomCandidateFindings(candidateFindings, entry)
        appendSiblingCandidateFindings(candidateFindings, entry)
        appendRewardCandidateFindings(candidateFindings, history, entry, rulesByTarget)
    end
    return validResult(candidateFindings)
end

return candidates
