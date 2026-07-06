local guard = import("mods/declarations/guard.lua")

local roomTemplatesValidator = {}

local function toSet(values)
    local set = {}
    for _, value in ipairs(values) do
        set[value] = true
    end
    return set
end

function roomTemplatesValidator.validate(roomTemplates)
    guard.expectTable(roomTemplates, "roomTemplates")

    local normalized = {}
    for key, template in pairs(roomTemplates) do
        local context = "roomTemplates." .. key
        guard.expectTable(template, context)
        guard.expectString(template.key, context .. ".key")
        if template.key ~= key then
            guard.fail(context .. ".key", "room template key must match map key")
        end
        guard.expectString(template.label, context .. ".label")
        guard.expectNonEmptyArray(template.roomKinds, context .. ".roomKinds")
        for index, kind in ipairs(template.roomKinds) do
            guard.expectString(kind, context .. ".roomKinds[" .. tostring(index) .. "]")
        end
        guard.expectOptionalString(template.stateKind, context .. ".stateKind")
        normalized[key] = {
            key = template.key,
            label = template.label,
            roomKinds = template.roomKinds,
            stateKind = template.stateKind,
            roomKindSet = toSet(template.roomKinds),
        }
    end

    return normalized
end

return roomTemplatesValidator
