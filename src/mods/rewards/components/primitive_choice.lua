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

function primitiveChoice.prepare(optionSet, defaultPrimitive, fieldPrefix)
    local descriptor = {
        optionSet = optionSet,
        defaultPrimitive = defaultPrimitive,
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
            default = descriptor.defaultPrimitive.gameName,
            maxLen = STRING_MAX,
        }
    end
    for index = 1, descriptor.optionSet.maxPayloadArity do
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
    local optionSet = descriptor.optionSet
    local requestedRewardType = optionalString(value.rewardType, "rewardType", context)
    if optionSet.fixedRewardType ~= nil
        and requestedRewardType ~= nil
        and requestedRewardType ~= optionSet.fixedRewardType
    then
        fail(context, "cannot replace fixed reward type '" .. optionSet.fixedRewardType .. "'")
    end
    local rewardType = optionSet.fixedRewardType or requestedRewardType
    if rewardType == nil then
        fail(context, "rewardType is required")
    end
    local primitive = optionSet.primitiveLookup[rewardType]
    if primitive == nil then
        fail(context, "rewardType '" .. rewardType .. "' is not available from option set '"
            .. optionSet.key .. "'")
    end
    local normalized = {
        rewardType = primitive.gameName,
        payload = value.payload,
    }
    local source1, source2 = primitive.encode(normalized, context)
    if not primitive.isComplete(normalized) then
        fail(context, "reward must be complete")
    end
    return primitive.gameName, source1, source2
end

local function readRequiredField(fields, fieldKey, context)
    local value = fields[fieldKey]:read()
    if type(value) ~= "string" or value == "" then
        fail(context, "persisted field '" .. fieldKey .. "' must be a non-empty string")
    end
    return value
end

function primitiveChoice.read(fields, descriptor, context)
    local optionSet = descriptor.optionSet
    local rewardType = optionSet.fixedRewardType
        or readRequiredField(fields, descriptor.fields.rewardType, context)
    local primitive = optionSet.primitiveLookup[rewardType]
    if primitive == nil then
        fail(context, "rewardType '" .. rewardType .. "' is not available from option set '"
            .. optionSet.key .. "'")
    end
    local source1 = primitive.payloadArity >= 1
        and readRequiredField(fields, descriptor.fields.source1, context)
        or nil
    local source2 = primitive.payloadArity >= 2
        and readRequiredField(fields, descriptor.fields.source2, context)
        or nil
    local value = primitive.decode(source1, source2, context)
    validateValue(descriptor, value, context)
    return value
end

function primitiveChoice.write(fields, descriptor, value, context)
    local rewardType, source1, source2 = validateValue(descriptor, value, context)
    if descriptor.fields.rewardType ~= nil then
        fields[descriptor.fields.rewardType]:write(rewardType)
    end
    local primitive = descriptor.optionSet.primitiveLookup[rewardType]
    for index = 1, primitive.payloadArity do
        local source = index == 1 and source1 or source2
        fields[descriptor.fields["source" .. tostring(index)]]:write(source)
    end
end

function primitiveChoice.replaceReward(fields, descriptor, rewardType, context)
    local primitive = descriptor.optionSet.primitiveLookup[rewardType]
    if primitive == nil then
        fail(context, "rewardType '" .. tostring(rewardType) .. "' is not available")
    end
    local value = primitive.decode(
        primitive.defaultSource1,
        primitive.defaultSource2,
        "reward default"
    )
    primitiveChoice.write(fields, descriptor, value, context)
end

function primitiveChoice.isComplete(descriptor, value)
    if type(value) ~= "table" or type(value.rewardType) ~= "string" then
        return false
    end
    local primitive = descriptor.optionSet.primitiveLookup[value.rewardType]
    return primitive ~= nil and primitive.isComplete(value)
end

return primitiveChoice
