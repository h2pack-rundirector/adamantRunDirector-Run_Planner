local deps = ... or {}

local none = deps.none or import("mods/rewards/payloads/none.lua")
local oneOf = deps.oneOf or import("mods/rewards/payloads/one_of.lua")
local distinctPair = deps.distinctPair or import("mods/rewards/payloads/distinct_pair.lua")

local registry = {}

local function identify(declaration, collaborator)
    collaborator.key = declaration.key
    return collaborator
end

local function valueLabels(declaration, primitives)
    local labels = {}
    for _, gameName in ipairs(declaration.values) do
        local primitive = primitives.lookup[gameName]
        if primitive == nil then
            error("payload domain '" .. declaration.key
                .. "' references unknown primitive '" .. gameName .. "'", 0)
        end
        labels[gameName] = primitive.label
    end
    return labels
end

function registry.build(declarations, primitives)
    local result = {
        none = none.create(),
        ordered = {},
        lookup = {},
    }
    for _, declaration in ipairs(declarations.ordered) do
        if declaration.kind == "oneOf" then
            result.lookup[declaration.key] = identify(
                declaration,
                oneOf.create(declaration, valueLabels(declaration, primitives))
            )
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
