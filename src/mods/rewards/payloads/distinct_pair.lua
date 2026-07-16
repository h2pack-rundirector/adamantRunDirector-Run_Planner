local distinctPair = {}

local function fail(context, message)
    error(context .. ": " .. message, 0)
end

local function source(value, collaborator, label, context)
    if value == nil then
        return nil
    end
    if type(value) ~= "string" or value == "" then
        fail(context, label .. " must be a non-empty string")
    end
    if collaborator.valueLookup[value] ~= true then
        fail(context, "unknown source '" .. value .. "'")
    end
    return value
end

local function encodedSources(value, collaborator, context)
    if value == nil then
        return nil, nil
    end
    if type(value) ~= "table" then
        fail(context, "payload must be a table")
    end
    for key in pairs(value) do
        if key ~= "sources" then
            fail(context, "unexpected field '" .. tostring(key) .. "'")
        end
    end
    if value.sources == nil then
        return nil, nil
    end
    if type(value.sources) ~= "table" then
        fail(context, "sources must be a table")
    end
    for key in pairs(value.sources) do
        if key ~= 1 and key ~= 2 then
            fail(context, "unexpected source index '" .. tostring(key) .. "'")
        end
    end
    local source1 = source(value.sources[1], collaborator, "source 1", context)
    local source2 = source(value.sources[2], collaborator, "source 2", context)
    if source2 ~= nil and source1 == nil then
        fail(context, "source 2 requires source 1")
    end
    if source1 ~= nil and source1 == source2 then
        fail(context, "sources must be distinct")
    end
    return source1, source2
end

function distinctPair.create(valueDomain)
    if valueDomain.kind ~= "oneOf" then
        error("distinct-pair payload requires a oneOf value domain", 0)
    end
    local payload = {
        kind = "distinctPair",
        arity = 2,
        values = valueDomain.values,
        valueLookup = valueDomain.valueLookup,
        valueDomain = valueDomain,
    }

    function payload.encode(value, context)
        return encodedSources(value, payload, context)
    end

    function payload.decode(source1, source2, context)
        if source1 == nil and source2 == nil then
            return nil
        end
        local value = { sources = {} }
        if source1 ~= nil then
            value.sources[1] = source1
        end
        if source2 ~= nil then
            value.sources[2] = source2
        end
        encodedSources(value, payload, context)
        return value
    end

    function payload.isComplete(value)
        return type(value) == "table"
            and type(value.sources) == "table"
            and type(value.sources[1]) == "string"
            and type(value.sources[2]) == "string"
            and payload.valueLookup[value.sources[1]] == true
            and payload.valueLookup[value.sources[2]] == true
            and value.sources[1] ~= value.sources[2]
    end

    return payload
end

return distinctPair
