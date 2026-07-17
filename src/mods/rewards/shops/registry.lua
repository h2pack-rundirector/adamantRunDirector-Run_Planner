local registry = {}

local function createOptionSet(declaration, primitives)
    local optionSet = {
        key = declaration.key,
        primitives = {},
        primitiveLookup = {},
        rewardTypes = {},
        maxPayloadArity = 0,
    }
    for _, rewardType in ipairs(declaration) do
        local primitive = primitives.lookup[rewardType]
        optionSet.primitives[#optionSet.primitives + 1] = primitive
        optionSet.primitiveLookup[primitive.gameName] = primitive
        optionSet.rewardTypes[#optionSet.rewardTypes + 1] = primitive.gameName
        if primitive.payloadArity > optionSet.maxPayloadArity then
            optionSet.maxPayloadArity = primitive.payloadArity
        end
    end
    if #optionSet.rewardTypes == 1 then
        optionSet.fixedRewardType = optionSet.rewardTypes[1]
    end
    return optionSet
end

local function createProfile(declaration, optionSets)
    local profile = {
        key = declaration.key,
        constraintKeys = {},
        slots = { ordered = {}, lookup = {} },
    }
    for index, constraintKey in ipairs(declaration.constraintKeys or {}) do
        profile.constraintKeys[index] = constraintKey
    end
    for _, declarationSlot in ipairs(declaration.slots) do
        local slot = {
            key = declarationSlot.key,
            label = declarationSlot.label,
            optionSet = optionSets.lookup[declarationSlot.optionSetKey],
            uniqueGroup = declarationSlot.uniqueGroup,
        }
        profile.slots.ordered[#profile.slots.ordered + 1] = slot
        profile.slots.lookup[slot.key] = slot
    end
    return profile
end

function registry.build(declarations, primitives)
    local optionSets = { ordered = {}, lookup = {} }
    for _, declaration in ipairs(declarations.optionSets.ordered) do
        local optionSet = createOptionSet(declaration, primitives)
        optionSets.ordered[#optionSets.ordered + 1] = optionSet
        optionSets.lookup[optionSet.key] = optionSet
    end
    local profiles = { ordered = {}, lookup = {} }
    for _, declaration in ipairs(declarations.profiles.ordered) do
        local profile = createProfile(declaration, optionSets)
        profiles.ordered[#profiles.ordered + 1] = profile
        profiles.lookup[profile.key] = profile
    end
    return {
        optionSets = optionSets,
        profiles = profiles,
    }
end

return registry
