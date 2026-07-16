local registry = {}

local function fail(context, message)
    error(context .. ": " .. message, 0)
end

local function requireOnlyFragmentKeys(value, context)
    for key in pairs(value) do
        if key ~= "payload" and key ~= "rewardType" then
            fail(context, "unexpected field '" .. tostring(key) .. "'")
        end
    end
end

local function createPrimitive(declaration, payload)
    local primitive = {
        key = declaration.key,
        label = declaration.label,
        acquiredAs = declaration.acquiredAs or declaration.key,
        payload = payload,
        payloadArity = payload.arity,
    }

    function primitive.encode(value, context)
        if type(value) ~= "table" then
            fail(context, "reward must be a table")
        end
        requireOnlyFragmentKeys(value, context)
        if value.rewardType ~= nil and value.rewardType ~= primitive.key then
            fail(context, "cannot replace fixed reward type '" .. primitive.key .. "'")
        end
        return primitive.payload.encode(value.payload, context .. ".payload")
    end

    function primitive.decode(source1, source2, context)
        local value = { rewardType = primitive.key }
        local decoded = primitive.payload.decode(source1, source2, context .. ".payload")
        if decoded ~= nil then
            value.payload = decoded
        end
        return value
    end

    function primitive.isComplete(value)
        return type(value) == "table"
            and value.rewardType == primitive.key
            and primitive.payload.isComplete(value.payload)
    end

    return primitive
end

function registry.build(declarations, payloadDomains)
    local result = { ordered = {}, lookup = {} }
    for _, declaration in ipairs(declarations.ordered) do
        local payload = payloadDomains.none
        if declaration.payloadDomain ~= nil then
            payload = payloadDomains.lookup[declaration.payloadDomain]
        end
        local primitive = createPrimitive(declaration, payload)
        result.ordered[#result.ordered + 1] = primitive
        result.lookup[primitive.key] = primitive
    end
    return result
end

return registry
