local deps = ... or {}

local declarations = deps.declarations or import("mods/catalog/declarations.lua")
local schema = deps.schema or import("mods/catalog/schema.lua")
local kindRegistry = deps.kindRegistry or import("mods/catalog/requirement_kinds.lua", nil, {
    schema = schema,
})
local requirements = deps.requirements or import("mods/catalog/requirements.lua", nil, {
    schema = schema,
    kindRegistry = kindRegistry,
})
local validator = deps.validator or import("mods/catalog/validator.lua", nil, {
    schema = schema,
    requirements = requirements,
})

local assembly = {}

local function mergedDeclarations(overrides)
    local raw = {}
    for key, value in pairs(declarations) do
        raw[key] = value
    end
    for key, value in pairs(overrides or {}) do
        raw[key] = value
    end
    return raw
end

function assembly.create(overrides)
    return validator.validate(mergedDeclarations(overrides))
end

return assembly
