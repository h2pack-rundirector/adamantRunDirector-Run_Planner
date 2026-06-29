local deps = ... or {}

local biomeStructure = deps.biomeStructure
local rewardValidator = deps.rewards
local selectedLegalityRules = deps.selectedLegalityRules

local validator = {}

function validator.validate(args)
    local biomeResult = biomeStructure.validate(args)
    if not biomeResult.valid then
        return biomeResult
    end

    local rewardResult = rewardValidator.validate({
        history = args and args.history or nil,
        selectedLegalityRules = selectedLegalityRules,
    })
    if not rewardResult.valid then
        return rewardResult
    end

    return biomeResult
end

return validator
