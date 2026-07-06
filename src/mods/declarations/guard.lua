local guard = {}

local PREFIX = "Run Planner declaration invariant"

local function typeName(value)
    if value == nil then
        return "nil"
    end
    return type(value)
end

local function fail(context, message)
    error(PREFIX .. " (" .. context .. "): " .. message, 3)
end

function guard.fail(context, message)
    fail(context, message)
end

function guard.expectType(value, expectedType, context)
    if type(value) ~= expectedType then
        fail(context, "expected " .. expectedType .. ", got " .. typeName(value))
    end
    return value
end

function guard.expectTable(value, context)
    return guard.expectType(value, "table", context)
end

function guard.expectString(value, context)
    return guard.expectType(value, "string", context)
end

function guard.expectBoolean(value, context)
    return guard.expectType(value, "boolean", context)
end

function guard.expectNumber(value, context)
    return guard.expectType(value, "number", context)
end

function guard.expectFunction(value, context)
    return guard.expectType(value, "function", context)
end

function guard.expectOptionalTable(value, context)
    if value ~= nil then
        guard.expectTable(value, context)
    end
    return value
end

function guard.expectOptionalString(value, context)
    if value ~= nil then
        guard.expectString(value, context)
    end
    return value
end

function guard.expectOptionalBoolean(value, context)
    if value ~= nil then
        guard.expectBoolean(value, context)
    end
    return value
end

function guard.expectOptionalNumber(value, context)
    if value ~= nil then
        guard.expectNumber(value, context)
    end
    return value
end

function guard.expectArray(value, context)
    guard.expectTable(value, context)
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            fail(context, "expected array entry, got key " .. tostring(key))
        end
    end
    return value
end

function guard.expectNonEmptyArray(value, context)
    guard.expectArray(value, context)
    if #value == 0 then
        fail(context, "expected at least one entry")
    end
    return value
end

function guard.indexByKey(items, context)
    guard.expectArray(items, context)

    local lookup = {}
    for index, item in ipairs(items) do
        local itemContext = context .. "[" .. tostring(index) .. "]"
        guard.expectTable(item, itemContext)
        local key = guard.expectString(item.key, itemContext .. ".key")
        if lookup[key] ~= nil then
            fail(itemContext, "duplicate key '" .. key .. "'")
        end
        lookup[key] = item
    end

    return lookup
end

function guard.sortedKeys(map)
    guard.expectTable(map, "sortedKeys.map")

    local keys = {}
    for key, _ in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

return guard
