local deps = ... or {}

local biomeStructure = deps.biomeStructure

local validator = {}

function validator.validate(args)
    return biomeStructure.validate(args)
end

return validator
