local countedChoice = {}

local STRING_MAX = 64

local function fail(context, message)
    error(context .. ": " .. message, 0)
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

local function requireOnlyValueKeys(value, context)
    for key in pairs(value) do
        if key ~= "payload" and key ~= "rewardType" and key ~= "storeKey" then
            fail(context, "unexpected field '" .. tostring(key) .. "'")
        end
    end
end

function countedChoice.prepare(view, fieldPrefix)
    if view.kind ~= "countedChoice" then
        error("counted-choice component requires a compiled countedChoice view", 0)
    end
    local descriptor = {
        view = view,
        fields = {},
        defaultStoreKey = view.defaultStoreKey,
        defaultPrimitive = view.defaultPrimitive,
    }
    if view.fixedStoreKey == nil then
        descriptor.fields.storeKey = fieldPrefix .. "StoreKey"
    end
    if view.fixedRewardType == nil then
        descriptor.fields.rewardType = fieldPrefix .. "Type"
    end
    for index = 1, view.maxPayloadArity do
        descriptor.fields["source" .. tostring(index)] = fieldPrefix .. "Payload" .. tostring(index)
    end
    return descriptor
end

function countedChoice.storage(descriptor)
    local storage = {}
    if descriptor.fields.storeKey ~= nil then
        storage[#storage + 1] = {
            key = descriptor.fields.storeKey,
            type = "string",
            default = descriptor.defaultStoreKey,
            maxLen = STRING_MAX,
        }
    end
    if descriptor.fields.rewardType ~= nil then
        storage[#storage + 1] = {
            key = descriptor.fields.rewardType,
            type = "string",
            default = descriptor.defaultPrimitive.gameName,
            maxLen = STRING_MAX,
        }
    end
    for index = 1, descriptor.view.maxPayloadArity do
        storage[#storage + 1] = {
            key = descriptor.fields["source" .. tostring(index)],
            type = "string",
            default = descriptor.defaultPrimitive["defaultSource" .. tostring(index)] or "",
            maxLen = STRING_MAX,
        }
    end
    return storage
end

local function validateValue(descriptor, value, context)
    if type(value) ~= "table" then
        fail(context, "reward must be a table")
    end
    requireOnlyValueKeys(value, context)
    local view = descriptor.view
    local requestedStoreKey = optionalString(value.storeKey, "storeKey", context)
    if view.fixedStoreKey ~= nil
        and requestedStoreKey ~= nil
        and requestedStoreKey ~= view.fixedStoreKey
    then
        fail(context, "cannot replace fixed store '" .. view.fixedStoreKey .. "'")
    end
    local storeKey = view.fixedStoreKey or requestedStoreKey
    if storeKey == nil then
        fail(context, "storeKey is required")
    end
    local store = view.stores.lookup[storeKey]
    if store == nil then
        fail(context, "unknown store '" .. storeKey .. "'")
    end

    local requestedRewardType = optionalString(value.rewardType, "rewardType", context)
    if view.fixedRewardType ~= nil
        and requestedRewardType ~= nil
        and requestedRewardType ~= view.fixedRewardType
    then
        fail(context, "cannot replace fixed reward type '" .. view.fixedRewardType .. "'")
    end
    local rewardType = view.fixedRewardType or requestedRewardType
    if rewardType == nil then
        fail(context, "rewardType is required")
    end
    local primitive = view.primitives.lookup[rewardType]
    if primitive == nil then
        fail(context, "rewardType '" .. rewardType .. "' is not available from this binding")
    end
    if store ~= nil
        and primitive ~= nil
        and store.primitiveLookup[primitive.gameName] == nil
    then
        fail(context, "rewardType '" .. primitive.gameName
            .. "' is not available from store '" .. store.key .. "'")
    end
    local normalized = {
        rewardType = primitive.gameName,
        payload = value.payload,
    }
    local source1, source2 = primitive.encode(normalized, context)
    if not primitive.isComplete(normalized) then
        fail(context, "reward must be complete")
    end
    return storeKey, primitive.gameName, source1, source2
end

local function readRequiredField(fields, fieldKey, context)
    local value = fields[fieldKey]:read()
    if type(value) ~= "string" or value == "" then
        fail(context, "persisted field '" .. fieldKey .. "' must be a non-empty string")
    end
    return value
end

local function readPayloadField(fields, fieldKey, context)
    if fieldKey == nil then
        return nil
    end
    return readRequiredField(fields, fieldKey, context)
end

function countedChoice.read(fields, descriptor, context)
    local view = descriptor.view
    local storeKey = view.fixedStoreKey
        or readRequiredField(fields, descriptor.fields.storeKey, context)
    local rewardType = view.fixedRewardType
        or readRequiredField(fields, descriptor.fields.rewardType, context)
    local primitive = view.primitives.lookup[rewardType]
    if primitive == nil then
        fail(context, "rewardType '" .. rewardType .. "' is not available from this binding")
    end
    local source1 = primitive.payloadArity >= 1
        and readPayloadField(fields, descriptor.fields.source1, context)
        or nil
    local source2 = primitive.payloadArity >= 2
        and readPayloadField(fields, descriptor.fields.source2, context)
        or nil
    local value = primitive.decode(source1, source2, context)
    value.storeKey = storeKey
    validateValue(descriptor, value, context)
    return value
end

function countedChoice.write(fields, descriptor, value, context)
    local storeKey, rewardType, source1, source2 = validateValue(descriptor, value, context)
    if descriptor.fields.storeKey ~= nil then
        fields[descriptor.fields.storeKey]:write(storeKey)
    end
    if descriptor.fields.rewardType ~= nil then
        fields[descriptor.fields.rewardType]:write(rewardType)
    end
    local primitive = descriptor.view.primitives.lookup[rewardType]
    for index = 1, primitive.payloadArity do
        local source = index == 1 and source1 or source2
        fields[descriptor.fields["source" .. tostring(index)]]:write(source)
    end
end

local function defaultValue(storeKey, primitive)
    local value = primitive.decode(
        primitive.defaultSource1,
        primitive.defaultSource2,
        "reward default"
    )
    value.storeKey = storeKey
    return value
end

function countedChoice.replaceStore(fields, descriptor, storeKey, context)
    local store = descriptor.view.stores.lookup[storeKey]
    if store == nil then
        fail(context, "unknown store '" .. tostring(storeKey) .. "'")
    end
    countedChoice.write(fields, descriptor, defaultValue(storeKey, store.defaultPrimitive), context)
end

function countedChoice.replaceReward(fields, descriptor, rewardType, context)
    local storeKey = descriptor.view.fixedStoreKey
        or readRequiredField(fields, descriptor.fields.storeKey, context)
    local store = descriptor.view.stores.lookup[storeKey]
    local primitive = store and store.primitiveLookup[rewardType] or nil
    if primitive == nil then
        fail(
            context,
            "rewardType '" .. tostring(rewardType)
                .. "' is not available from store '" .. tostring(storeKey) .. "'"
        )
    end
    countedChoice.write(fields, descriptor, defaultValue(storeKey, primitive), context)
end

function countedChoice.isComplete(descriptor, value)
    if type(value) ~= "table" then
        return false
    end
    local view = descriptor.view
    local store = type(value.storeKey) == "string" and view.stores.lookup[value.storeKey] or nil
    local primitive = type(value.rewardType) == "string"
        and view.primitives.lookup[value.rewardType]
        or nil
    return store ~= nil
        and primitive ~= nil
        and store.primitiveLookup[primitive.gameName] ~= nil
        and primitive.isComplete(value)
end

return countedChoice
