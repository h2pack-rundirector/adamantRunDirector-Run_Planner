local counted = {}

local function copyList(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = value
    end
    return result
end

local function listLookup(values)
    local result = {}
    for _, value in ipairs(values) do
        result[value] = true
    end
    return result
end

local function included(binding, primitiveKey, eligible, ineligible)
    return (#binding.eligibleRewardTypes == 0 or eligible[primitiveKey] == true)
        and ineligible[primitiveKey] ~= true
end

function counted.create(bags)
    local compiler = {}

    function compiler.compile(binding)
        if binding.kind ~= "countedChoice" then
            error("counted binding compiler requires a countedChoice binding", 0)
        end
        local eligible = listLookup(binding.eligibleRewardTypes)
        local ineligible = listLookup(binding.ineligibleRewardTypes)
        local defaultStoreKey = #binding.storeKeys == 1
            and binding.storeKeys[1]
            or binding.defaultStoreKey
        local view = {
            kind = "countedChoice",
            storeKeys = copyList(binding.storeKeys),
            stores = { ordered = {}, lookup = {} },
            primitives = { ordered = {}, lookup = {} },
            rewardTypes = {},
            maxPayloadArity = 0,
            batchConstraint = binding.batchConstraint,
        }
        for _, storeKey in ipairs(binding.storeKeys) do
            local bag = bags.lookup[storeKey]
            local store = {
                key = storeKey,
                bag = bag,
                defaultPrimitive = storeKey == defaultStoreKey
                    and binding.defaultRewardType ~= nil
                    and bags.lookup[storeKey].optionLookup[binding.defaultRewardType]
                    or bag.defaultPrimitive,
                primitives = {},
                primitiveLookup = {},
            }
            for _, primitive in ipairs(bag.options) do
                if included(binding, primitive.gameName, eligible, ineligible) then
                    store.primitives[#store.primitives + 1] = primitive
                    store.primitiveLookup[primitive.gameName] = primitive
                    if view.primitives.lookup[primitive.gameName] == nil then
                        view.primitives.ordered[#view.primitives.ordered + 1] = primitive
                        view.primitives.lookup[primitive.gameName] = primitive
                        view.rewardTypes[#view.rewardTypes + 1] = primitive.gameName
                        if primitive.payloadArity > view.maxPayloadArity then
                            view.maxPayloadArity = primitive.payloadArity
                        end
                    end
                end
            end
            view.stores.ordered[#view.stores.ordered + 1] = store
            view.stores.lookup[store.key] = store
        end
        if #view.storeKeys == 1 then
            view.fixedStoreKey = view.storeKeys[1]
        end
        view.defaultStoreKey = defaultStoreKey
        view.defaultPrimitive = view.stores.lookup[view.defaultStoreKey].defaultPrimitive
        if #view.rewardTypes == 1 then
            view.fixedRewardType = view.rewardTypes[1]
        end
        return view
    end

    return compiler
end

return counted
