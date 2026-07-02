local deps = ... or {}

local rewardValidator = deps.rewards
local findings = deps.findings

local rewards = {}

local EMPTY_LIST = {}
local REWARD_CANDIDATE_OPTS = {
    skipRequirementKinds = {
        CurrentLootSourcesSeen = true,
    },
}

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
            requirement = invalid.requirement,
            relatedEvents = invalid.relatedEvents,
        }
    )
end

function rewards.appendFindings(target, history, entry, rulesByTarget)
    for _, candidate in ipairs(entry.rewardCandidates or EMPTY_LIST) do
        if candidate.kind == "rewardType" or candidate.kind == "fixedReward" then
            for _, rewardType in ipairs(candidate.rewardTypes or EMPTY_LIST) do
                appendRewardTypeCandidateFinding(target, history, entry, candidate, rewardType, rulesByTarget)
            end
        end
    end
end

return rewards
