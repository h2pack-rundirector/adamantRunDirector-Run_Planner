local none = {}

local function fail(context, message)
    error(context .. ": " .. message, 0)
end

function none.create()
    local payload = {
        kind = "none",
        arity = 0,
    }

    function payload.encode(value, context)
        if value ~= nil then
            fail(context, "reward type does not accept a payload")
        end
        return nil, nil
    end

    function payload.decode(source1, source2, context)
        if source1 ~= nil or source2 ~= nil then
            fail(context, "persisted payload requires a payload domain")
        end
        return nil
    end

    function payload.isComplete(value)
        return value == nil
    end

    return payload
end

return none
