local schema = {}

function schema.fail(path, message)
    error("catalog invariant at " .. path .. ": " .. message, 0)
end

function schema.copy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] ~= nil then
        return seen[value]
    end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[schema.copy(key, seen)] = schema.copy(child, seen)
    end
    return result
end

function schema.table(value, path)
    if type(value) ~= "table" then
        schema.fail(path, "expected a table")
    end
    return value
end

function schema.boolean(value, path)
    if type(value) ~= "boolean" then
        schema.fail(path, "expected a boolean")
    end
    return value
end

function schema.string(value, path)
    if type(value) ~= "string" or value == "" then
        schema.fail(path, "expected a non-empty string")
    end
    return value
end

function schema.number(value, path)
    if type(value) ~= "number" then
        schema.fail(path, "expected a number")
    end
    return value
end

function schema.integer(value, path, minimum)
    minimum = minimum or 0
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum then
        schema.fail(path, "expected an integer >= " .. tostring(minimum))
    end
    return value
end

function schema.enum(value, allowed, path)
    schema.string(value, path)
    for _, candidate in ipairs(allowed) do
        if value == candidate then
            return value
        end
    end
    schema.fail(path, "unknown value '" .. value .. "'")
end

function schema.list(value, path, nonEmpty)
    schema.table(value, path)
    local count = 0
    local maximum = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 then
            schema.fail(path, "expected a dense array")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        schema.fail(path, "expected a dense array")
    end
    if nonEmpty and maximum == 0 then
        schema.fail(path, "must not be empty")
    end
    return maximum
end

function schema.stringList(value, path, nonEmpty)
    local length = schema.list(value, path, nonEmpty)
    local seen = {}
    for index = 1, length do
        schema.string(value[index], path .. "[" .. tostring(index) .. "]")
        if seen[value[index]] then
            schema.fail(path .. "[" .. tostring(index) .. "]", "duplicate value '" .. value[index] .. "'")
        end
        seen[value[index]] = true
    end
    return length
end

function schema.contains(values, expected)
    for _, value in ipairs(values) do
        if value == expected then
            return true
        end
    end
    return false
end

function schema.onlyKeys(value, allowed, path)
    local lookup = {}
    for _, key in ipairs(allowed) do
        lookup[key] = true
    end
    for key in pairs(value) do
        if not lookup[key] then
            schema.fail(path .. "." .. tostring(key), "unexpected field")
        end
    end
end

function schema.comparison(value, path)
    return schema.enum(value, { "==", "~=", "<", "<=", ">", ">=" }, path)
end

function schema.range(value, path)
    schema.table(value, path)
    schema.onlyKeys(value, { "exact", "min", "minExclusive", "max", "maxExclusive" }, path)
    local hasBound = false
    for _, key in ipairs({ "exact", "min", "minExclusive", "max", "maxExclusive" }) do
        if value[key] ~= nil then
            schema.number(value[key], path .. "." .. key)
            hasBound = true
        end
    end
    if not hasBound then
        schema.fail(path, "at least one bound is required")
    end
    if value.exact ~= nil and (
        value.min ~= nil or value.minExclusive ~= nil or value.max ~= nil or value.maxExclusive ~= nil
    ) then
        schema.fail(path, "exact cannot be combined with another bound")
    end
    if value.min ~= nil and value.minExclusive ~= nil then
        schema.fail(path, "min and minExclusive are mutually exclusive")
    end
    if value.max ~= nil and value.maxExclusive ~= nil then
        schema.fail(path, "max and maxExclusive are mutually exclusive")
    end
    local lower = value.min or value.minExclusive
    local upper = value.max or value.maxExclusive
    if lower ~= nil and upper ~= nil and lower > upper then
        schema.fail(path, "lower bound must not exceed upper bound")
    end
end

function schema.orderedCatalog(values, path, nonEmpty)
    local length = schema.list(values, path, nonEmpty)
    local ordered = {}
    local lookup = {}
    for index = 1, length do
        local value = schema.copy(values[index])
        local valuePath = path .. "[" .. tostring(index) .. "]"
        schema.table(value, valuePath)
        schema.string(value.key, valuePath .. ".key")
        if lookup[value.key] ~= nil then
            schema.fail(valuePath .. ".key", "duplicate key '" .. value.key .. "'")
        end
        ordered[index] = value
        lookup[value.key] = value
    end
    return { ordered = ordered, lookup = lookup }
end

function schema.keyedCatalog(values, path, nonEmpty)
    schema.table(values, path)
    local keys = {}
    for key in pairs(values) do
        schema.string(key, path .. ".<key>")
        keys[#keys + 1] = key
    end
    table.sort(keys)
    if nonEmpty and #keys == 0 then
        schema.fail(path, "must not be empty")
    end
    local ordered = {}
    local lookup = {}
    for _, key in ipairs(keys) do
        local value = schema.copy(values[key])
        local valuePath = path .. "." .. key
        schema.table(value, valuePath)
        if value.key ~= nil then
            schema.fail(valuePath .. ".key", "keyed catalog identity is derived from the map key")
        end
        value.key = key
        ordered[#ordered + 1] = value
        lookup[key] = value
    end
    return { ordered = ordered, lookup = lookup }
end

return schema
