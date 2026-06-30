local deps = ... or {}
local rewards = deps.rewards
local valueStates = deps.valueStates

local form = {}
local common = import("mods/controls/form/common.lua")
local feedback = import("mods/controls/form/feedback.lua", nil, {
    valueStates = valueStates,
})
local locations = import("mods/controls/form/locations.lua")
local readCache = import("mods/controls/form/read_cache.lua")
local rowData = import("mods/controls/form/row_data.lua", nil, {
    common = common,
    readCache = readCache,
    rewards = rewards,
    valueStates = valueStates,
})
local slots = import("mods/controls/form/slots.lua")

local VALID_STATUS = {
    valid = true,
}
local INVALID_STATE = valueStates and valueStates.INVALID or 2
local COMPLETION_INVALID_CODES = {
    role_required = true,
    option_required = true,
    selection_required = true,
    fields_cage_count_required = true,
    fields_sibling_structure_required = true,
    fixed_sibling_structure_required = true,
    clockwork_sibling_structure_required = true,
    major_minor_sibling_branch_required = true,
    ship_wheel_offer_count_required = true,
}

local function nonEmpty(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function positiveInteger(value)
    local count = math.floor(tonumber(value) or 0)
    if count < 0 then
        return 0
    end
    return count
end

function form.selectedTarget(opts)
    opts = opts or {}
    return {
        tabKey = opts.tabKey,
        address = opts.address,
        controlAlias = opts.controlAlias,
        state = opts.state or INVALID_STATE,
        mode = "selected",
    }
end

function form.selectedTargets(opts)
    return {
        form.selectedTarget(opts),
    }
end

function form.invalid(opts)
    opts = opts or {}
    local label = nonEmpty(opts.label) or "Selection"
    return {
        valid = false,
        code = opts.code or "selection_required",
        message = opts.message or (label .. " needs a concrete selection"),
        tabKey = opts.tabKey,
        controlTargets = form.selectedTargets(opts),
        valueTargets = opts.valueTargets,
        completion = true,
    }
end

function form.isCompletionInvalid(invalid)
    if invalid == nil then
        return false
    end
    if invalid.completion == true or invalid.invalidCompletion == true then
        return true
    end
    return COMPLETION_INVALID_CODES[invalid.code or invalid.invalidCode] == true
end

function form.validateRoomChoice(opts)
    local data = opts.data
    local instance = opts.instance
    local rows = opts.rows
    local rowIndex = opts.rowIndex
    local roleAlias = opts.roleAlias or "RoleKey"
    local optionAlias = opts.optionAlias or "OptionKey"
    local roleLabel = opts.roleLabel or "Room type"

    local roleKey, role = data.resolveRole(instance, rows, rowIndex)
    if roleKey == nil or roleKey == "" then
        return form.invalid({
            code = "role_required",
            message = opts.roleRequiredMessage or "Choose a room type",
            tabKey = "rooms",
            controlAlias = roleAlias,
            label = roleLabel,
        })
    end
    if role == nil then
        return form.invalid({
            code = "unknown_role",
            message = "Unknown route role: " .. tostring(roleKey),
            tabKey = "rooms",
            controlAlias = roleAlias,
            label = roleLabel,
        })
    end

    local options = data.optionListForRole(role)
    if #options == 0 then
        return VALID_STATUS
    end

    local optionKey = rows and rows:read(rowIndex, optionAlias) or ""
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    if optionKey ~= "" and option == nil then
        return form.invalid({
            code = "unknown_option",
            message = "Unknown route option: " .. tostring(optionKey),
            tabKey = "rooms",
            controlAlias = optionAlias,
            label = tostring(role.label or roleKey),
        })
    end
    if optionKey == "" and (role.requiresConcreteOption or #options > 1) then
        return form.invalid({
            code = "option_required",
            message = "Choose a " .. tostring(role.label or roleKey),
            tabKey = "rooms",
            controlAlias = optionAlias,
            label = tostring(role.label or roleKey),
        })
    end

    return VALID_STATUS
end

function form.clampedCount(value, maxValue)
    local count = positiveInteger(value)
    if maxValue == nil then
        return count
    end
    local maxCount = positiveInteger(maxValue)
    if count > maxCount then
        return maxCount
    end
    return count
end

function form.shouldDrawIndex(activeCount, index)
    return positiveInteger(index or 1) <= positiveInteger(activeCount)
end

function form.singleConcreteValue(values)
    local single = nil
    for _, value in ipairs(values or {}) do
        if value ~= nil and value ~= "" then
            if single ~= nil then
                return nil
            end
            single = value
        end
    end
    return single
end

function form.shouldRenderStaticValue(values, storedValue)
    local value = form.singleConcreteValue(values)
    if value == nil then
        return nil
    end
    if storedValue == nil or storedValue == "" or storedValue == value then
        return value
    end
    return nil
end

function form.labelAddsInformation(parent, option)
    if parent == nil or option == nil then
        return false
    end
    return tostring(option.label or option.key or "") ~= tostring(parent.label or parent.key or "")
end

local function rewardContext(role, option)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function optionForKey(role, optionKey)
    if role == nil or optionKey == nil or optionKey == "" then
        return nil
    end
    return role.optionsByKey and role.optionsByKey[optionKey] or nil
end

form.common = common
form.feedback = feedback
form.locations = locations
form.readCache = readCache
form.rowData = rowData
form.slots = slots
form.valueStates = valueStates

function form.resetRewardsIfRoomContextChanged(control, resetRewardDetails, rowIndex, previousOptionKey)
    local role = control:role(rowIndex)
    local previousContext = rewardContext(role, optionForKey(role, previousOptionKey))
    local currentContext = rewardContext(role, control:option(rowIndex))
    if previousContext ~= currentContext then
        resetRewardDetails(control:fields(), rowIndex)
    end
end

return form
