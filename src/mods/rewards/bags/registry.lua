local registry = {}

local function createBag(declaration, primitives)
    local bag = {
        key = declaration.key,
        refill = declaration.refill,
        entries = {},
        options = {},
        optionLookup = {},
        defaultPrimitive = primitives.lookup[declaration.defaultRewardType],
    }
    for index, declarationEntry in ipairs(declaration.entries) do
        local primitive = primitives.lookup[declarationEntry.rewardType]
        bag.entries[index] = {
            primitive = primitive,
            requirementKey = declarationEntry.requirementKey,
        }
        if bag.optionLookup[primitive.gameName] == nil then
            bag.options[#bag.options + 1] = primitive
            bag.optionLookup[primitive.gameName] = primitive
        end
    end
    return bag
end

function registry.build(declarations, primitives)
    local result = { ordered = {}, lookup = {} }
    for _, declaration in ipairs(declarations.ordered) do
        local bag = createBag(declaration, primitives)
        result.ordered[#result.ordered + 1] = bag
        result.lookup[bag.key] = bag
    end
    return result
end

return registry
