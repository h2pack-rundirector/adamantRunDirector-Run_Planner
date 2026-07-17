local oneOf = {}

local function fail(context, message)
    error(context .. ": " .. message, 0)
end

local function onlySource(value, context)
    for key in pairs(value) do
        if key ~= "source" then
            fail(context, "unexpected field '" .. tostring(key) .. "'")
        end
    end
end

local function optionalSource(value, collaborator, context)
    if value == nil then
        return nil
    end
    if type(value) ~= "string" or value == "" then
        fail(context, "source must be a non-empty string")
    end
    if collaborator.valueLookup[value] ~= true then
        fail(context, "unknown source '" .. value .. "'")
    end
    return value
end

function oneOf.create(declaration, valueLabels)
    local values = {}
    local valueLookup = {}
    local labels = {}
    for index, value in ipairs(declaration.values) do
        values[index] = value
        valueLookup[value] = true
        labels[value] = valueLabels[value]
    end
    local payload = {
        kind = "oneOf",
        arity = 1,
        values = values,
        valueLookup = valueLookup,
        valueLabels = labels,
    }

    function payload.encode(value, context)
        if value == nil then
            return nil, nil
        end
        if type(value) ~= "table" then
            fail(context, "payload must be a table")
        end
        onlySource(value, context)
        return optionalSource(value.source, payload, context), nil
    end

    function payload.decode(source1, source2, context)
        if source2 ~= nil then
            fail(context, "one-of payload cannot contain source 2")
        end
        local source = optionalSource(source1, payload, context)
        if source == nil then
            return nil
        end
        return { source = source }
    end

    function payload.isComplete(value)
        return type(value) == "table"
            and type(value.source) == "string"
            and payload.valueLookup[value.source] == true
    end

    return payload
end

return oneOf
