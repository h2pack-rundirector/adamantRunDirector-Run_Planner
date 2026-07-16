local fixed = {}

local STRING_MAX = 64

local function fail(context, message)
    error(context .. ": " .. message, 0)
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

function fixed.prepare(primitive, fieldPrefix)
    local descriptor = {
        primitive = primitive,
        fields = {},
    }
    for index = 1, primitive.payloadArity do
        descriptor.fields["source" .. tostring(index)] = fieldPrefix .. "Payload" .. tostring(index)
    end
    return descriptor
end

function fixed.storage(descriptor)
    local storage = {}
    for index = 1, descriptor.primitive.payloadArity do
        storage[#storage + 1] = {
            key = descriptor.fields["source" .. tostring(index)],
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        }
    end
    return storage
end

function fixed.read(fields, descriptor, context)
    local source1 = readOptionalField(fields, descriptor.fields.source1, context)
    local source2 = readOptionalField(fields, descriptor.fields.source2, context)
    return descriptor.primitive.decode(source1, source2, context)
end

function fixed.write(fields, descriptor, value, context)
    local source1, source2 = descriptor.primitive.encode(value, context)
    for index = 1, descriptor.primitive.payloadArity do
        local source = index == 1 and source1 or source2
        fields[descriptor.fields["source" .. tostring(index)]]:write(source or "")
    end
end

function fixed.isComplete(descriptor, value)
    return descriptor.primitive.isComplete(value)
end

return fixed
