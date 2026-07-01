local deps = ... or {}

local biomeStructure = deps.biomeStructure
local candidateValidator = deps.candidates
local npcValidator = deps.npcs
local rewardValidator = deps.rewards
local selectedLegalityRules = deps.selectedLegalityRules

local validator = {}

local EMPTY_LIST = {}

local function mergeFindings(result, findings)
    result.findings = result.findings or {}
    for _, finding in ipairs(findings or {}) do
        result.findings[#result.findings + 1] = finding
    end
    return result
end

local function positionValue(record)
    local routeBiomeIndex = math.floor(tonumber(record and record.routeBiomeIndex) or 0)
    local routeOrdinal = math.floor(tonumber(record and record.routeOrdinal) or record and record.rowIndex or 0)
    local rowIndex = math.floor(tonumber(record and record.rowIndex) or 0)
    return routeBiomeIndex * 1000000 + routeOrdinal * 1000 + rowIndex
end

local function earlierInvalid(left, right)
    if left == nil then
        return right
    elseif right == nil then
        return left
    end
    if positionValue(left) <= positionValue(right) then
        return left
    end
    return right
end

local function resultWithCandidate(candidateResult, result)
    local candidateInvalid = candidateResult
        and candidateResult.invalids
        and candidateResult.invalids[1]
        or nil
    local resultInvalid = result
        and result.invalids
        and result.invalids[1]
        or nil
    local invalid = earlierInvalid(candidateInvalid, resultInvalid)
    if invalid == nil then
        return mergeFindings(result, candidateResult and candidateResult.findings or EMPTY_LIST)
    end
    return {
        valid = false,
        invalids = { invalid },
        findings = mergeFindings(result or {}, candidateResult and candidateResult.findings or EMPTY_LIST).findings,
    }
end

function validator.validate(args)
    local candidateResult = candidateValidator.validate(args)
    local biomeResult = biomeStructure.validate(args)
    if not biomeResult.valid then
        return resultWithCandidate(candidateResult, biomeResult)
    end

    local rewardResult = rewardValidator.validate({
        history = args and args.history or nil,
        selectedLegalityRules = selectedLegalityRules,
    })
    if not rewardResult.valid then
        return resultWithCandidate(candidateResult, rewardResult)
    end

    local npcResult = npcValidator.validate({
        npcSnapshot = args and args.npcSnapshot or nil,
        npcTargets = args and args.npcTargets or nil,
        npcs = args and args.npcs or nil,
    })
    if not npcResult.valid then
        return resultWithCandidate(candidateResult, npcResult)
    end

    if not candidateResult.valid then
        return resultWithCandidate(candidateResult, biomeResult)
    end

    return mergeFindings(biomeResult, candidateResult.findings)
end

return validator
