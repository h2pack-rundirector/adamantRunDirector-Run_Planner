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
            default = "",
            maxLen = STRING_MAX,
        }
    end
    if descriptor.fields.rewardType ~= nil then
        storage[#storage + 1] = {
            key = descriptor.fields.rewardType,
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        }
    end
    for index = 1, descriptor.view.maxPayloadArity do
        storage[#storage + 1] = {
            key = descriptor.fields["source" .. tostring(index)],
            type = "string",
            default = "",
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
    local store = storeKey ~= nil and view.stores.lookup[storeKey] or nil
    if storeKey ~= nil and store == nil then
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
    local primitive = rewardType ~= nil and view.primitives.lookup[rewardType] or nil
    if rewardType ~= nil and primitive == nil then
        fail(context, "rewardType '" .. rewardType .. "' is not available from this binding")
    end
    if store ~= nil
        and primitive ~= nil
        and store.primitiveLookup[primitive.gameName] == nil
    then
        fail(context, "rewardType '" .. primitive.gameName
            .. "' is not available from store '" .. store.key .. "'")
    end
    if primitive == nil then
        if value.payload ~= nil then
            fail(context, "payload requires a rewardType")
        end
        return storeKey, nil, nil, nil
    end
    local source1, source2 = primitive.encode({
        rewardType = primitive.gameName,
        payload = value.payload,
    }, context)
    return storeKey, primitive.gameName, source1, source2
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

function countedChoice.read(fields, descriptor, context)
    local view = descriptor.view
    local storeKey = view.fixedStoreKey
        or readOptionalField(fields, descriptor.fields.storeKey, context)
    local rewardType = view.fixedRewardType
        or readOptionalField(fields, descriptor.fields.rewardType, context)
    local source1 = readOptionalField(fields, descriptor.fields.source1, context)
    local source2 = readOptionalField(fields, descriptor.fields.source2, context)
    if rewardType == nil then
        if source1 ~= nil or source2 ~= nil then
            fail(context, "persisted payload requires a rewardType")
        end
        local value = { storeKey = storeKey }
        validateValue(descriptor, value, context)
        return value
    end
    local primitive = view.primitives.lookup[rewardType]
    if primitive == nil then
        fail(context, "rewardType '" .. rewardType .. "' is not available from this binding")
    end
    local value = primitive.decode(source1, source2, context)
    value.storeKey = storeKey
    validateValue(descriptor, value, context)
    return value
end

function countedChoice.write(fields, descriptor, value, context)
    local storeKey, rewardType, source1, source2 = validateValue(descriptor, value, context)
    if descriptor.fields.storeKey ~= nil then
        fields[descriptor.fields.storeKey]:write(storeKey or "")
    end
    if descriptor.fields.rewardType ~= nil then
        fields[descriptor.fields.rewardType]:write(rewardType or "")
    end
    for index = 1, descriptor.view.maxPayloadArity do
        local source = index == 1 and source1 or source2
        fields[descriptor.fields["source" .. tostring(index)]]:write(source or "")
    end
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
