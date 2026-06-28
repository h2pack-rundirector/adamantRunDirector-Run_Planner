local deps = ... or {}
local valueStates = deps.valueStates

local controlRequirements = {}

local INVALID_STATE = valueStates and valueStates.INVALID or 2

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
    }
end

return controlRequirements
