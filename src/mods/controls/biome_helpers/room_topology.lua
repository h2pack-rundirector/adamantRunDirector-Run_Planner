local deps = ...
local roomStructure = deps.roomStructure
local valueStates = deps.valueStates
local form = deps.form

local invalidStatus = deps.common.invalidStatus

local roomTopology = {}

local EMPTY_VALUES = {}

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

function roomTopology.roomKey(candidate)
    if candidate == nil then
        return nil
    end
    return candidate.roomKey or (candidate.structure == "Miniboss" and candidate.key or nil)
end

function roomTopology.prepareSiblingPolicy(topology, opts)
    local control = topology and topology.siblingStructureControl or nil
    if control == nil then
        return nil
    end

    local policy = {
        namespace = opts and opts.namespace or "topology",
        key = control.key,
        label = control.label or control.key,
        alias = control.alias or "SiblingStructureKey",
        values = {},
        labels = {},
        optionsByKey = {},
    }

    for _, option in ipairs(control.options or EMPTY_VALUES) do
        local key = option.key or ""
        policy.values[#policy.values + 1] = key
        policy.labels[key] = option.label or key
        policy.optionsByKey[key] = option
    end
    return policy
end

function roomTopology.generatedStructuralCount(ctx, field)
    if ctx.structuralCountAt == nil then
        return 0
    end
    return math.floor(tonumber(ctx.structuralCountAt(ctx.rowIndex, field)) or 0)
end

function roomTopology.siblingCountForExitCount(exitCount)
    return roomStructure.siblingCountForExitCount(exitCount)
end

function roomTopology.activeSiblingCount(policy, ctx)
    if policy == nil or ctx.isFixedIdentityRow then
        return 0
    end
    if not ctx.hasSelectableSiblingStructure then
        return 0
    end

    return roomTopology.siblingCountForExitCount(roomTopology.generatedStructuralCount(ctx, "exitCount"))
end

function roomTopology.shouldDrawActiveSibling(activeSiblingCount, status, siblingIndex)
    if not form.shouldDrawIndex(activeSiblingCount, siblingIndex or 1) then
        return false
    end
    return status ~= nil and status.valid == true
end

function roomTopology.validateRequiredSiblingStructures(policy, ctx, opts)
    opts = opts or {}
    local count = roomTopology.activeSiblingCount(policy, ctx)
    for siblingIndex = 1, count do
        local siblingKey, sibling = ctx.siblingAt(siblingIndex)
        if sibling == nil or siblingKey == "" then
            return invalidStatus(opts.requiredCode, opts.requiredMessage), siblingIndex
        end
    end
    return nil
end

function roomTopology.fillSiblingValueStates(policy, ctx, states)
    clearMap(states)
    if policy == nil then
        return states
    end
    if roomTopology.activeSiblingCount(policy, ctx) >= (ctx.candidateSiblingIndex or 1) then
        local siblingKey = ctx.siblingAt(ctx.candidateSiblingIndex or 1)
        if siblingKey == nil or siblingKey == "" then
            valueStates.set(states, "", valueStates.INVALID)
        end
    end
    return states
end

return roomTopology
