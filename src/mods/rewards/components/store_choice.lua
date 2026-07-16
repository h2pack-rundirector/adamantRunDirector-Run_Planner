local storeChoice = {}

local STRING_MAX = 64

local function fail(context, message)
    error(context .. ": " .. message, 0)
end

local function copyList(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

local function listLookup(values)
    local lookup = {}
    for _, value in ipairs(values or {}) do
        lookup[value] = true
    end
    return lookup
end

local function payloadDescriptor(catalog, rewardType)
    local primitive = catalog.rewards.primitives.lookup[rewardType]
    if primitive.payloadDomain == nil then
        return { kind = "none", arity = 0 }
    end
    local domain = catalog.rewards.payloadDomains.lookup[primitive.payloadDomain]
    if domain.kind == "oneOf" then
        local values = copyList(domain.values)
        return {
            kind = "oneOf",
            arity = 1,
            values = values,
            valueLookup = listLookup(values),
        }
    end
    if domain.kind == "distinctPair" then
        local valueDomain = catalog.rewards.payloadDomains.lookup[domain.valueDomain]
        local values = copyList(valueDomain.values)
        return {
            kind = "distinctPair",
            arity = 2,
            values = values,
            valueLookup = listLookup(values),
        }
    end
    error("unsupported payload domain kind '" .. tostring(domain.kind) .. "'", 0)
end

local function included(binding, rewardType, eligibleLookup, ineligibleLookup)
    return (#binding.eligibleRewardTypes == 0 or eligibleLookup[rewardType] == true)
        and ineligibleLookup[rewardType] ~= true
end

function storeChoice.prepare(catalog, binding, fieldPrefix)
    if binding.kind ~= "countedChoice" then
        error("store-choice component requires a countedChoice binding", 0)
    end
    local descriptor = {
        storeKeys = copyList(binding.storeKeys),
        storeLookup = listLookup(binding.storeKeys),
        rewardsByStore = {},
        rewardLookup = {},
        rewardTypes = {},
        payloads = {},
        maxPayloadArity = 0,
        fields = {
            rewardType = fieldPrefix .. "Type",
        },
    }
    if #descriptor.storeKeys == 1 then
        descriptor.fixedStoreKey = descriptor.storeKeys[1]
    else
        descriptor.fields.storeKey = fieldPrefix .. "StoreKey"
    end

    local eligibleLookup = listLookup(binding.eligibleRewardTypes)
    local ineligibleLookup = listLookup(binding.ineligibleRewardTypes)
    for _, storeKey in ipairs(descriptor.storeKeys) do
        local rewardLookup = {}
        descriptor.rewardsByStore[storeKey] = rewardLookup
        local bag = catalog.rewards.bags.lookup[storeKey]
        for _, entry in ipairs(bag.entries) do
            local rewardType = entry.rewardType
            if included(binding, rewardType, eligibleLookup, ineligibleLookup) then
                rewardLookup[rewardType] = true
                if descriptor.rewardLookup[rewardType] ~= true then
                    descriptor.rewardLookup[rewardType] = true
                    descriptor.rewardTypes[#descriptor.rewardTypes + 1] = rewardType
                    local payload = payloadDescriptor(catalog, rewardType)
                    descriptor.payloads[rewardType] = payload
                    if payload.arity > descriptor.maxPayloadArity then
                        descriptor.maxPayloadArity = payload.arity
                    end
                end
            end
        end
    end
    for index = 1, descriptor.maxPayloadArity do
        descriptor.fields["source" .. tostring(index)] = fieldPrefix .. "Payload" .. tostring(index)
    end
    return descriptor
end

function storeChoice.storage(descriptor)
    local storage = {}
    if descriptor.fields.storeKey ~= nil then
        storage[#storage + 1] = {
            key = descriptor.fields.storeKey,
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        }
    end
    storage[#storage + 1] = {
        key = descriptor.fields.rewardType,
        type = "string",
        default = "",
        maxLen = STRING_MAX,
    }
    for index = 1, descriptor.maxPayloadArity do
        storage[#storage + 1] = {
            key = descriptor.fields["source" .. tostring(index)],
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        }
    end
    return storage
end

local function requireOnlyKeys(value, allowed, context)
    for key in pairs(value) do
        if allowed[key] ~= true then
            fail(context, "unexpected field '" .. tostring(key) .. "'")
        end
    end
end

local function optionalString(value, label, context)
    if value == nil then
        return nil
    end
    if type(value) ~= "string" or value == "" then
        fail(context, label .. " must be a non-empty string")
    end
    return value
end

local function validatePayload(descriptor, rewardType, payload, context)
    if rewardType == nil then
        if payload ~= nil then
            fail(context, "payload requires a rewardType")
        end
        return nil, nil
    end
    local payloadSpec = descriptor.payloads[rewardType]
    if payloadSpec.kind == "none" then
        if payload ~= nil then
            fail(context, "rewardType '" .. rewardType .. "' does not accept a payload")
        end
        return nil, nil
    end
    if payload == nil then
        return nil, nil
    end
    if type(payload) ~= "table" then
        fail(context, "payload must be a table")
    end
    if payloadSpec.kind == "oneOf" then
        requireOnlyKeys(payload, { source = true }, context .. ".payload")
        local source = optionalString(payload.source, "source", context .. ".payload")
        if source ~= nil and payloadSpec.valueLookup[source] ~= true then
            fail(context .. ".payload", "unknown source '" .. source .. "'")
        end
        return source, nil
    end

    requireOnlyKeys(payload, { sources = true }, context .. ".payload")
    if payload.sources == nil then
        return nil, nil
    end
    if type(payload.sources) ~= "table" then
        fail(context .. ".payload", "sources must be a table")
    end
    for key in pairs(payload.sources) do
        if key ~= 1 and key ~= 2 then
            fail(context .. ".payload.sources", "unexpected index '" .. tostring(key) .. "'")
        end
    end
    local source1 = optionalString(payload.sources[1], "source 1", context .. ".payload")
    local source2 = optionalString(payload.sources[2], "source 2", context .. ".payload")
    if source2 ~= nil and source1 == nil then
        fail(context .. ".payload", "source 2 requires source 1")
    end
    if source1 ~= nil and payloadSpec.valueLookup[source1] ~= true then
        fail(context .. ".payload", "unknown source '" .. source1 .. "'")
    end
    if source2 ~= nil and payloadSpec.valueLookup[source2] ~= true then
        fail(context .. ".payload", "unknown source '" .. source2 .. "'")
    end
    if source1 ~= nil and source1 == source2 then
        fail(context .. ".payload", "sources must be distinct")
    end
    return source1, source2
end

local function validateValue(descriptor, value, context)
    if type(value) ~= "table" then
        fail(context, "reward must be a table")
    end
    requireOnlyKeys(value, { payload = true, rewardType = true, storeKey = true }, context)
    local requestedStoreKey = optionalString(value.storeKey, "storeKey", context)
    if descriptor.fixedStoreKey ~= nil
        and requestedStoreKey ~= nil
        and requestedStoreKey ~= descriptor.fixedStoreKey
    then
        fail(context, "cannot replace fixed store '" .. descriptor.fixedStoreKey .. "'")
    end
    local storeKey = descriptor.fixedStoreKey or requestedStoreKey
    if storeKey ~= nil and descriptor.storeLookup[storeKey] ~= true then
        fail(context, "unknown store '" .. storeKey .. "'")
    end

    local rewardType = optionalString(value.rewardType, "rewardType", context)
    if rewardType ~= nil and descriptor.rewardLookup[rewardType] ~= true then
        fail(context, "rewardType '" .. rewardType .. "' is not available from this binding")
    end
    if storeKey ~= nil
        and rewardType ~= nil
        and descriptor.rewardsByStore[storeKey][rewardType] ~= true
    then
        fail(context, "rewardType '" .. rewardType .. "' is not available from store '" .. storeKey .. "'")
    end
    local source1, source2 = validatePayload(descriptor, rewardType, value.payload, context)
    return storeKey, rewardType, source1, source2
end

local function readOptionalField(fields, fieldKey, context)
    if fieldKey == nil then
        return nil
    end
    local value = fields[fieldKey]:read()
    if type(value) ~= "string" then
        fail(context, "persisted field '" .. fieldKey .. "' must be a string")
    end
    if value == "" then
        return nil
    end
    return value
end

function storeChoice.read(fields, descriptor, context)
    local storeKey = descriptor.fixedStoreKey
        or readOptionalField(fields, descriptor.fields.storeKey, context)
    local rewardType = readOptionalField(fields, descriptor.fields.rewardType, context)
    local source1 = readOptionalField(fields, descriptor.fields.source1, context)
    local source2 = readOptionalField(fields, descriptor.fields.source2, context)
    local value = {
        storeKey = storeKey,
        rewardType = rewardType,
    }
    local payloadSpec = rewardType ~= nil and descriptor.payloads[rewardType] or nil
    if payloadSpec ~= nil and payloadSpec.kind == "oneOf" and source1 ~= nil then
        value.payload = { source = source1 }
    elseif payloadSpec ~= nil and payloadSpec.kind == "distinctPair" and source1 ~= nil then
        value.payload = { sources = { source1 } }
        if source2 ~= nil then
            value.payload.sources[2] = source2
        end
    elseif payloadSpec ~= nil and payloadSpec.kind == "distinctPair" and source2 ~= nil then
        value.payload = { sources = { [2] = source2 } }
    end
    validateValue(descriptor, value, context)
    return value
end

function storeChoice.write(fields, descriptor, value, context)
    local storeKey, rewardType, source1, source2 = validateValue(descriptor, value, context)
    if descriptor.fields.storeKey ~= nil then
        fields[descriptor.fields.storeKey]:write(storeKey or "")
    end
    fields[descriptor.fields.rewardType]:write(rewardType or "")
    for index = 1, descriptor.maxPayloadArity do
        local source = index == 1 and source1 or source2
        fields[descriptor.fields["source" .. tostring(index)]]:write(source or "")
    end
end

return storeChoice
