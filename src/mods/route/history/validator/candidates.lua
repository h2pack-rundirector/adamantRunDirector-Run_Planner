local deps = ... or {}

local routeHistory = deps.history
local rewardValidator = deps.rewards
local selectedLegalityRules = deps.selectedLegalityRules

local common = import("mods/route/history/validator/candidates/common.lua")
local candidateValidators = {
    import("mods/route/history/validator/candidates/rooms.lua", nil, {
        common = common,
        findings = deps.findings,
        history = routeHistory,
    }),
    import("mods/route/history/validator/candidates/siblings.lua", nil, {
        common = common,
        findings = deps.findings,
    }),
    import("mods/route/history/validator/candidates/variants.lua", nil, {
        common = common,
        findings = deps.findings,
    }),
    import("mods/route/history/validator/candidates/rewards.lua", nil, {
        findings = deps.findings,
        rewards = rewardValidator,
    }),
}

local candidates = {}

local function appendRuleFindings(target, history, entry, ruleValidators)
    for _, ruleValidator in ipairs(ruleValidators or common.EMPTY_LIST) do
        if ruleValidator.appendCandidateFindings ~= nil then
            ruleValidator.appendCandidateFindings(target, history, entry)
        end
    end
end

function candidates.validate(args)
    local history = args and args.history or nil
    local rulesByTarget = rewardValidator.rulesByTarget(selectedLegalityRules)
    local candidateFindings = {}
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        candidateValidators[1].appendFindings(candidateFindings, history, entry)
        candidateValidators[2].appendFindings(candidateFindings, entry)
        candidateValidators[3].appendFindings(candidateFindings, entry)
        candidateValidators[4].appendFindings(candidateFindings, history, entry, rulesByTarget)
        appendRuleFindings(candidateFindings, history, entry, deps.ruleValidators)
    end
    return common.validResult(candidateFindings)
end

return candidates
