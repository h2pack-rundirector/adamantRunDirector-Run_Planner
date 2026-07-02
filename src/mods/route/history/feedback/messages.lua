local deps = ... or {}

local messages = {}
local catalog = deps.catalog
local EMPTY_LIST = {}

local function nonEmpty(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function targetRecord(record)
    return record and (record.targetFinding or record) or nil
end

local function optionList(role)
    return role and (role.roomOptions or role.mapOptions) or EMPTY_LIST
end

local function roleForRecord(args, record)
    local target = targetRecord(record)
    local candidate = target and target.candidate or nil
    local roleKey = nonEmpty(target and target.roleKey)
        or nonEmpty(candidate and candidate.roleKey)
    local biomeKey = target and target.biomeKey or record and record.biomeKey or nil
    local biome = args and args.biomeLookup and args.biomeLookup[biomeKey] or nil
    return biome and biome.rolesByKey and biome.rolesByKey[roleKey] or nil
end

local function optionForRecord(record, role)
    local target = targetRecord(record)
    local candidate = target and target.candidate or nil
    local optionKey = nonEmpty(target and target.optionKey)
        or nonEmpty(candidate and candidate.optionKey)
        or nonEmpty(target and target.roomKey)
        or nonEmpty(candidate and candidate.roomKey)
    if role == nil or optionKey == nil then
        return nil
    end
    if role.optionsByKey ~= nil and role.optionsByKey[optionKey] ~= nil then
        return role.optionsByKey[optionKey]
    end
    for _, option in ipairs(optionList(role)) do
        if option.key == optionKey or option.roomKey == optionKey then
            return option
        end
    end
    return nil
end

local function roleDisplayLabel(args, record)
    local target = targetRecord(record)
    local candidate = target and target.candidate or nil
    local role = roleForRecord(args, record)
    return nonEmpty(candidate and candidate.roleLabel)
        or nonEmpty(target and target.roleLabel)
        or nonEmpty(role and role.label)
end

local function optionDisplayLabel(args, record)
    local target = targetRecord(record)
    local candidate = target and target.candidate or nil
    local role = roleForRecord(args, record)
    local option = optionForRecord(record, role)
    return nonEmpty(candidate and (candidate.optionLabel or candidate.label))
        or nonEmpty(target and (target.optionLabel or target.label))
        or nonEmpty(option and option.label)
end

local PAYLOAD_RESOLVERS = {
    roleLabel = roleDisplayLabel,
    optionLabel = optionDisplayLabel,
}

function messages.code(record, extras)
    local target = targetRecord(record)
    return nonEmpty(extras and extras.code)
        or nonEmpty(record and record.code)
        or nonEmpty(record and record.reason)
        or nonEmpty(target and target.code)
        or nonEmpty(target and target.reason)
end

function messages.explicit(record, extras)
    local target = targetRecord(record)
    return nonEmpty(extras and extras.message)
        or nonEmpty(record and record.message)
        or nonEmpty(target and target.message)
end

local function payloadValue(args, record, payloadKey, payloadSpec)
    local resolver = PAYLOAD_RESOLVERS[payloadKey]
    local value = resolver and resolver(args, record) or nil
    return nonEmpty(value) or nonEmpty(payloadSpec and payloadSpec.fallback)
end

local function buildPayload(args, record, definition)
    local payload = {}
    for payloadKey, payloadSpec in pairs(definition and definition.payload or {}) do
        payload[payloadKey] = payloadValue(args, record, payloadKey, payloadSpec)
    end
    return payload
end

local function renderTemplate(template, payload)
    return string.gsub(template, "{([%w_]+)}", function(payloadKey)
        return payload[payloadKey] or ""
    end)
end

function messages.forRecord(args, record, extras, code)
    local message = messages.explicit(record, extras)
    if message ~= nil then
        return message
    end
    if code == nil then
        return nil
    end
    local definition = catalog[code] or catalog.unknown
    return renderTemplate(definition.template, buildPayload(args, record, definition))
end

return messages
