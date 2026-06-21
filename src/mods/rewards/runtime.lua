local deps = ... or {}
local catalog = deps.catalog

local runtime = {}
local VALID = { valid = true }
local INVALID_VALUE_COLOR = { 1.0, 0.22, 0.16, 1.0 }

local function conditionMatches(condition, fields)
    return fields:read(condition.alias) == condition.value
end

local function sourceActive(sourceIndex, opts)
    if sourceIndex == nil then
        return true
    end
    local sourceCount = opts and opts.sourceCount or nil
    if sourceCount == nil then
        return true
    end
    return sourceIndex <= sourceCount
end

local function conditionActive(condition, fields)
    if condition == nil then
        return true
    end
    for _, item in ipairs(condition.any or {}) do
        if conditionMatches(item, fields) then
            return true
        end
    end
    if condition.any ~= nil then
        return false
    end
    for _, item in ipairs(condition.all or {}) do
        if not conditionMatches(item, fields) then
            return false
        end
    end
    if condition.all ~= nil then
        return true
    end
    return conditionMatches(condition, fields)
end

local function isControlVisible(control, fields, opts)
    return sourceActive(control and control.sourceIndex or nil, opts)
        and conditionActive(control and control.visibleWhen or nil, fields)
end

function runtime.snapshot(surface, fields, opts)
    local picks = {}
    if surface == nil or fields == nil then
        return picks
    end

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields, opts) then
            local value = fields:read(control.alias) or ""
            if value ~= "" then
                local pick = {
                    key = control.key,
                    kind = control.kind,
                    alias = control.alias,
                    value = value,
                }
                if control.rewardStore ~= nil then
                    pick.rewardStore = control.rewardStore
                end
                picks[#picks + 1] = pick
            end
        end
    end
    return picks
end

local function groupMembers(group)
    if group.members ~= nil then
        return group.members
    end
    return group.aliases or {}
end

local function memberAlias(member)
    if type(member) == "table" then
        return member.alias
    end
    return member
end

local function isMemberActive(group, member, fields, opts)
    if not sourceActive(type(member) == "table" and member.sourceIndex or nil, opts) then
        return false
    end
    if type(member) == "table" and not conditionActive(member.visibleWhen, fields) then
        return false
    end
    return conditionActive(group and group.visibleWhen or nil, fields)
end

local function duplicateAliasesInGroup(group, fields, opts)
    local aliases = {}
    local values = {}
    local allowDuplicateValues = group.allowDuplicateValues or {}
    for _, member in ipairs(groupMembers(group)) do
        local alias = memberAlias(member)
        if alias ~= nil and isMemberActive(group, member, fields, opts) then
            aliases[#aliases + 1] = alias
            values[#values + 1] = fields:read(alias) or ""
        end
    end
    for index, value in ipairs(values) do
        if value ~= "" and not allowDuplicateValues[value] then
            for previousIndex = 1, index - 1 do
                local previousValue = values[previousIndex]
                if previousValue == value then
                    return aliases
                end
            end
        end
    end
    return nil
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function appendPriorDuplicateValues(out, group, fields, controlAlias, opts)
    local aliases = {}
    local values = {}
    local allowDuplicateValues = group.allowDuplicateValues or {}
    for _, member in ipairs(groupMembers(group)) do
        local alias = memberAlias(member)
        if alias ~= nil and isMemberActive(group, member, fields, opts) then
            aliases[#aliases + 1] = alias
            values[#values + 1] = fields:read(alias) or ""
        end
    end
    for index, alias in ipairs(aliases) do
        if alias == controlAlias then
            local hasColors = false
            for previousIndex = 1, index - 1 do
                local previousValue = values[previousIndex]
                if previousValue ~= "" and not allowDuplicateValues[previousValue] then
                    out[previousValue] = INVALID_VALUE_COLOR
                    hasColors = true
                end
            end
            return hasColors
        end
    end
    return false
end

local function hasActiveGroupForAlias(groups, fields, controlAlias, opts)
    for _, group in ipairs(groups) do
        for _, member in ipairs(groupMembers(group)) do
            if memberAlias(member) == controlAlias and isMemberActive(group, member, fields, opts) then
                return true
            end
        end
    end
    return false
end

function runtime.validate(surface, fields, opts)
    if surface == nil or fields == nil then
        return VALID
    end

    for _, group in ipairs(surface.uniqueValueGroups or {}) do
        local aliases = duplicateAliasesInGroup(group, fields, opts)
        if aliases ~= nil then
            return {
                valid = false,
                code = group.code or "duplicate_reward_value",
                message = group.message or "Linked reward fields cannot duplicate the same value",
                aliases = aliases,
            }
        end
    end

    return VALID
end

function runtime.valueColors(surface, fields, control, out, opts)
    if surface == nil or fields == nil or control == nil or control.alias == nil then
        return nil
    end
    local uniqueValueGroups = surface.uniqueValueGroups
    if uniqueValueGroups == nil or uniqueValueGroups[1] == nil then
        return nil
    end
    if not hasActiveGroupForAlias(uniqueValueGroups, fields, control.alias, opts) then
        return nil
    end

    out = out or {}
    clearMap(out)

    local hasColors = false
    for _, group in ipairs(uniqueValueGroups) do
        hasColors = appendPriorDuplicateValues(out, group, fields, control.alias, opts) or hasColors
    end
    if hasColors then
        return out
    end
    return nil
end

function runtime.surfaceFor(context)
    if catalog == nil then
        return {
            kind = "none",
            controls = {},
        }
    end
    return catalog:surfaceFor(context)
end

function runtime.hasControls(surface)
    return surface ~= nil and surface.controls ~= nil and surface.controls[1] ~= nil
end

return runtime
