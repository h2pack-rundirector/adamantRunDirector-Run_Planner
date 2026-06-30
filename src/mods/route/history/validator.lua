local deps = ... or {}

local biomeStructure = deps.biomeStructure
local candidateValidator = deps.candidates
local npcValidator = deps.npcs
local rewardValidator = deps.rewards
local selectedLegalityRules = deps.selectedLegalityRules

local validator = {}

local function mergeFindings(result, findings)
    result.findings = result.findings or {}
    for _, finding in ipairs(findings or {}) do
        result.findings[#result.findings + 1] = finding
    end
    return result
end

function validator.validate(args)
    local candidateResult = candidateValidator.validate(args)
    local biomeResult = biomeStructure.validate(args)
    if not biomeResult.valid then
        return mergeFindings(biomeResult, candidateResult.findings)
    end

    local rewardResult = rewardValidator.validate({
        history = args and args.history or nil,
        selectedLegalityRules = selectedLegalityRules,
    })
    if not rewardResult.valid then
        return mergeFindings(rewardResult, candidateResult.findings)
    end

    local npcResult = npcValidator.validate({
        npcSnapshot = args and args.npcSnapshot or nil,
        npcTargets = args and args.npcTargets or nil,
        npcs = args and args.npcs or nil,
    })
    if not npcResult.valid then
        return mergeFindings(npcResult, candidateResult.findings)
    end

    return mergeFindings(biomeResult, candidateResult.findings)
end

return validator
