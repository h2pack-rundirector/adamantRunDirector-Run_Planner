local structuralValidator = import("mods/validation/structural.lua")
local rewardValidator = import("mods/validation/rewards.lua")

local routeValidation = {}

function routeValidation.validate(history, context)
    local result = structuralValidator.validate(history, context)
    rewardValidator.append(result, history, context)
    return result
end

return routeValidation
