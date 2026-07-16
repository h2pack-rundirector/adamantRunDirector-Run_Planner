local deps = ... or {}

local none = deps.none or import("mods/rewards/payloads/none.lua")
local oneOf = deps.oneOf or import("mods/rewards/payloads/one_of.lua")
local distinctPair = deps.distinctPair or import("mods/rewards/payloads/distinct_pair.lua")

local registry = {}

local function identify(declaration, collaborator)
    collaborator.key = declaration.key
    return collaborator
end

function registry.build(declarations)
    local result = {
        none = none.create(),
        ordered = {},
        lookup = {},
    }
    for _, declaration in ipairs(declarations.ordered) do
        if declaration.kind == "oneOf" then
            result.lookup[declaration.key] = identify(declaration, oneOf.create(declaration))
        end
    end
    for _, declaration in ipairs(declarations.ordered) do
        if declaration.kind == "distinctPair" then
            result.lookup[declaration.key] = identify(
                declaration,
                distinctPair.create(result.lookup[declaration.valueDomain])
            )
        end
    end
    for index, declaration in ipairs(declarations.ordered) do
        local collaborator = result.lookup[declaration.key]
        if collaborator == nil then
            error("payload registry did not construct validated declaration '"
                .. declaration.key .. "'", 0)
        end
        result.ordered[index] = collaborator
    end
    return result
end

return registry
