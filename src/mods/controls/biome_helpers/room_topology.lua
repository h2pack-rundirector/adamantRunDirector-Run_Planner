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

local function generatedDoorControl(topology)
    return topology and (topology.generatedDoorControl or topology.otherDoorControl) or nil
end

function roomTopology.roomKey(candidate)
    if candidate == nil then
        return nil
    end
    return candidate.roomKey or (candidate.structure == "Miniboss" and candidate.key or nil)
end

function roomTopology.prepareOtherDoorPolicy(topology, opts)
    local control = generatedDoorControl(topology)
    if control == nil then
        return nil
    end

    local policy = {
        namespace = opts and opts.namespace or "topology",
        key = control.key,
        label = control.label or control.key,
        alias = control.alias or "OtherDoorKey",
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

function roomTopology.otherDoorCountForExitCount(exitCount)
    return roomStructure.otherDoorCountForExitCount(exitCount)
end

function roomTopology.activeOtherDoorCount(policy, ctx)
    if policy == nil or ctx.isFixedIdentityRow then
        return 0
    end
    if not ctx.hasSelectableOtherDoor then
        return 0
    end

    return roomTopology.otherDoorCountForExitCount(roomTopology.generatedStructuralCount(ctx, "exitCount"))
end

function roomTopology.shouldDrawActiveOtherDoor(activeOtherDoorCount, status, otherDoorIndex)
    if not form.shouldDrawIndex(activeOtherDoorCount, otherDoorIndex or 1) then
        return false
    end
    return status ~= nil and status.valid == true
end

function roomTopology.validateRequiredOtherDoors(policy, ctx, opts)
    opts = opts or {}
    local count = roomTopology.activeOtherDoorCount(policy, ctx)
    for otherDoorIndex = 1, count do
        local otherDoorKey, otherDoor = ctx.otherDoorAt(otherDoorIndex)
        if otherDoor == nil or otherDoorKey == "" then
            return invalidStatus(opts.requiredCode, opts.requiredMessage), otherDoorIndex
        end
    end
    return nil
end

function roomTopology.fillOtherDoorValueStates(policy, ctx, states)
    clearMap(states)
    if policy == nil then
        return states
    end
    if roomTopology.activeOtherDoorCount(policy, ctx) >= (ctx.candidateOtherDoorIndex or 1) then
        local otherDoorKey = ctx.otherDoorAt(ctx.candidateOtherDoorIndex or 1)
        if otherDoorKey == nil or otherDoorKey == "" then
            valueStates.set(states, "", valueStates.INVALID)
        end
    end
    return states
end

return roomTopology
