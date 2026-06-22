local deps = ... or {}
local routeMarkers = deps.markers
local valueStates = deps.valueStates

local targetMarkers = {}
local EMPTY_LIST = {}
local INVALID_VALUE_STATE = valueStates and valueStates.INVALID or 2

local function appendTarget(targets, alias, value)
    if value ~= nil and value ~= "" then
        targets[#targets + 1] = {
            controlAlias = alias,
            value = tostring(value),
        }
    end
end

local function targetValueTargets(row, opts)
    local targets = {}
    appendTarget(targets, "BiomeKey", row.biomeKey)
    appendTarget(targets, "RowIndex", row.targetRowIndex)
    if opts and opts.includeVariant then
        appendTarget(targets, "VariantKey", row.variantKey)
    end
    return targets
end

function targetMarkers.row(ctx, row, invalid, markerKind, opts)
    opts = opts or {}
    return routeMarkers.row(ctx, row, invalid, markerKind, {
        scope = opts.scope,
        locationLabel = opts.locationLabel,
        fields = {
            valueTargets = targetValueTargets(row, opts),
        },
    })
end

function targetMarkers.valueStates(snapshot, rowIndex, controlAlias)
    local states = nil
    for _, invalid in ipairs(snapshot and snapshot.invalidRows or EMPTY_LIST) do
        if invalid.rowIndex == rowIndex then
            for _, target in ipairs(invalid.valueTargets or EMPTY_LIST) do
                if target.controlAlias == controlAlias and target.value ~= nil and target.value ~= "" then
                    states = states or {}
                    valueStates.set(states, target.value, INVALID_VALUE_STATE)
                end
            end
        end
    end
    return states
end

return targetMarkers
