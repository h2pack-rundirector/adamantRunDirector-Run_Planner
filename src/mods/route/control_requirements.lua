local deps = ... or {}
local valueStates = deps.valueStates

local controlRequirements = {}

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

function controlRequirements.selectedTarget(opts)
    opts = opts or {}
    return {
        tabKey = opts.tabKey,
        address = opts.address,
        controlAlias = opts.controlAlias,
        state = opts.state or INVALID_STATE,
        mode = "selected",
    }
end

function controlRequirements.selectedTargets(opts)
    return {
        controlRequirements.selectedTarget(opts),
    }
end

function controlRequirements.invalid(opts)
    opts = opts or {}
    local label = nonEmpty(opts.label) or "Selection"
    return {
        valid = false,
        code = opts.code or "selection_required",
        message = opts.message or (label .. " needs a concrete selection"),
        tabKey = opts.tabKey,
        controlTargets = controlRequirements.selectedTargets(opts),
        valueTargets = opts.valueTargets,
        completion = true,
    }
end

function controlRequirements.isCompletionInvalid(invalid)
    if invalid == nil then
        return false
    end
    if invalid.completion == true or invalid.invalidCompletion == true then
        return true
    end
    return COMPLETION_INVALID_CODES[invalid.code or invalid.invalidCode] == true
end

return controlRequirements
