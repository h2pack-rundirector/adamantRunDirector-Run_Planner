local primitiveChoice = {}

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
        if key ~= "payload" and key ~= "rewardType" then
            fail(context, "unexpected field '" .. tostring(key) .. "'")
        end
    end
end

function primitiveChoice.prepare(optionSet, fieldPrefix)
    local descriptor = {
        optionSet = optionSet,
        fields = {},
    }
    if optionSet.fixedRewardType == nil then
        descriptor.fields.rewardType = fieldPrefix .. "Type"
    end
    for index = 1, optionSet.maxPayloadArity do
        descriptor.fields["source" .. tostring(index)] = fieldPrefix .. "Payload" .. tostring(index)
    end
    return descriptor
end

function primitiveChoice.storage(descriptor)
    local storage = {}
    if descriptor.fields.rewardType ~= nil then
        storage[#storage + 1] = {
            key = descriptor.fields.rewardType,
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        }
    end
    for index = 1, descriptor.optionSet.maxPayloadArity do
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
    local optionSet = descriptor.optionSet
    local requestedRewardType = optionalString(value.rewardType, "rewardType", context)
    if optionSet.fixedRewardType ~= nil
        and requestedRewardType ~= nil
        and requestedRewardType ~= optionSet.fixedRewardType
    then
        fail(context, "cannot replace fixed reward type '" .. optionSet.fixedRewardType .. "'")
    end
    local rewardType = optionSet.fixedRewardType or requestedRewardType
    local primitive = rewardType ~= nil and optionSet.primitiveLookup[rewardType] or nil
    if rewardType ~= nil and primitive == nil then
        fail(context, "rewardType '" .. rewardType .. "' is not available from option set '"
            .. optionSet.key .. "'")
    end
    if primitive == nil then
        if value.payload ~= nil then
            fail(context, "payload requires a rewardType")
        end
        return nil, nil, nil
    end
    local source1, source2 = primitive.encode({
        rewardType = primitive.key,
        payload = value.payload,
    }, context)
    return primitive.key, source1, source2
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

function primitiveChoice.read(fields, descriptor, context)
    local optionSet = descriptor.optionSet
    local rewardType = optionSet.fixedRewardType
        or readOptionalField(fields, descriptor.fields.rewardType, context)
    local source1 = readOptionalField(fields, descriptor.fields.source1, context)
    local source2 = readOptionalField(fields, descriptor.fields.source2, context)
    if rewardType == nil then
        if source1 ~= nil or source2 ~= nil then
            fail(context, "persisted payload requires a rewardType")
        end
        return {}
    end
    local primitive = optionSet.primitiveLookup[rewardType]
    if primitive == nil then
        fail(context, "rewardType '" .. rewardType .. "' is not available from option set '"
            .. optionSet.key .. "'")
    end
    local value = primitive.decode(source1, source2, context)
    validateValue(descriptor, value, context)
    return value
end

function primitiveChoice.write(fields, descriptor, value, context)
    local rewardType, source1, source2 = validateValue(descriptor, value, context)
    if descriptor.fields.rewardType ~= nil then
        fields[descriptor.fields.rewardType]:write(rewardType or "")
    end
    for index = 1, descriptor.optionSet.maxPayloadArity do
        local source = index == 1 and source1 or source2
        fields[descriptor.fields["source" .. tostring(index)]]:write(source or "")
    end
end

function primitiveChoice.isComplete(descriptor, value)
    if type(value) ~= "table" or type(value.rewardType) ~= "string" then
        return false
    end
    local primitive = descriptor.optionSet.primitiveLookup[value.rewardType]
    return primitive ~= nil and primitive.isComplete(value)
end

return primitiveChoice
