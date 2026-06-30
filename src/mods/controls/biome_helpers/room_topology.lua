local deps = ...
local common = deps.common
local roomStructure = deps.roomStructure
local valueStates = deps.valueStates
local form = deps.form

local buildKeyLookup = common.buildKeyLookup
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus

local roomTopology = {}

local EMPTY_VALUES = {}

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function shallowCopyMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function statusCode(policy, suffix)
    return tostring(policy.namespace or "topology") .. "_" .. suffix
end

function roomTopology.roomKey(candidate)
    if candidate == nil then
        return nil
    end
    return candidate.roomKey or (candidate.structure == "Miniboss" and candidate.key or nil)
end

local function prepareForcedGroups(groups)
    local preparedGroups = {}
    for _, group in ipairs(groups or EMPTY_VALUES) do
        local prepared = shallowCopyMap(group)
        local generatedExitCount = group.generatedExitCount
            and math.floor(tonumber(group.generatedExitCount) or 0)
            or nil
        local requiredGeneratedCount = group.requiredGeneratedCount
        if requiredGeneratedCount == nil and generatedExitCount ~= nil then
            requiredGeneratedCount = math.min(#(group.candidates or EMPTY_VALUES), generatedExitCount)
        end
        prepared.candidatesByKey = buildKeyLookup(group.candidates or EMPTY_VALUES)
        prepared.generatedExitCount = generatedExitCount
        prepared.requiredGeneratedCount = requiredGeneratedCount
        preparedGroups[#preparedGroups + 1] = prepared
    end
    return preparedGroups
end

local function candidateInPreparedGroups(groups, roomKey)
    for _, group in ipairs(groups or EMPTY_VALUES) do
        if roomKey ~= nil and group.candidatesByKey ~= nil and group.candidatesByKey[roomKey] == true then
            return true
        end
    end
    return false
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
        topologyAvailability = topology.topologyWindow or topology.siblingStructureWindow,
        controlAvailability = topology.siblingControlWindow
            or topology.siblingStructureWindow
            or topology.topologyWindow,
        rules = topology.rules or EMPTY_VALUES,
        forcedGroups = prepareForcedGroups(topology.forcedGroups),
        values = {},
        labels = {},
        optionsByKey = {},
        optionsByRoomKey = {},
        ungroupedForceCandidates = {},
    }

    for _, option in ipairs(control.options or EMPTY_VALUES) do
        local key = option.key or ""
        policy.values[#policy.values + 1] = key
        policy.labels[key] = option.label or key
        policy.optionsByKey[key] = option
        local roomKey = roomTopology.roomKey(option)
        if roomKey ~= nil then
            policy.optionsByRoomKey[roomKey] = option
        end
    end
    for _, key in ipairs(policy.values) do
        local option = policy.optionsByKey[key]
        local roomKey = roomTopology.roomKey(option)
        if roomKey ~= nil
            and option.force ~= nil
            and not candidateInPreparedGroups(policy.forcedGroups, roomKey)
        then
            policy.ungroupedForceCandidates[#policy.ungroupedForceCandidates + 1] = roomKey
        end
    end
    return policy
end

function roomTopology.generationSourceRowIndex(rowIndex)
    local sourceIndex = math.floor(tonumber(rowIndex) or 0) - 1
    if sourceIndex < 1 then
        return nil
    end
    return sourceIndex
end

function roomTopology.generatedStructuralCount(ctx, field)
    local sourceIndex = roomTopology.generationSourceRowIndex(ctx.rowIndex)
    if sourceIndex == nil or ctx.structuralCountAt == nil then
        return 0
    end
    return math.floor(tonumber(ctx.structuralCountAt(sourceIndex, field)) or 0)
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

local function candidateInGroup(group, roomKey)
    return roomKey ~= nil and group.candidatesByKey ~= nil and group.candidatesByKey[roomKey] == true
end

local function pickedCandidateBeforeRow(ctx, group)
    for priorIndex = 1, ctx.rowIndex - 1 do
        if candidateInGroup(group, ctx.roomKeyAt(priorIndex)) then
            return true
        end
    end
    return false
end

local function pickedCandidateClosesGroup(policy, ctx, candidateRoomKey)
    for _, group in ipairs(policy.forcedGroups or EMPTY_VALUES) do
        if group.pickedCandidateBeforeDeadlineClosesGroup
            and candidateInGroup(group, candidateRoomKey)
            and pickedCandidateBeforeRow(ctx, group)
        then
            return true
        end
    end
    return false
end

local function siblingCountAt(ctx, index)
    if ctx.siblingCountAt == nil then
        return 1
    end
    return math.floor(tonumber(ctx.siblingCountAt(index)) or 0)
end

function roomTopology.forcedGroupsStatus()
    return validStatus()
end

local function plannedRoomRowIndex(ctx, roomKey)
    if roomKey == nil then
        return nil
    end
    for plannedIndex = 1, ctx.routeRowCount or 0 do
        if plannedIndex ~= ctx.rowIndex and ctx.roomKeyAt(plannedIndex) == roomKey then
            return plannedIndex
        end
    end
    return nil
end

local function siblingRoomAlreadySelected(ctx, roomKey)
    if roomKey == nil or ctx.siblingRoomKeyAt == nil then
        return false
    end
    local candidateSiblingIndex = ctx.candidateSiblingIndex or 1
    for siblingIndex = 1, siblingCountAt(ctx, ctx.rowIndex) do
        if siblingIndex ~= candidateSiblingIndex
            and ctx.siblingRoomKeyAt(ctx.rowIndex, siblingIndex) == roomKey
        then
            return true
        end
    end
    return false
end

local function siblingRoomGeneratedBeforeRow(ctx, roomKey)
    if roomKey == nil or ctx.siblingRoomKeyAt == nil then
        return false
    end
    for priorIndex = 1, ctx.rowIndex - 1 do
        for siblingIndex = 1, siblingCountAt(ctx, priorIndex) do
            if ctx.siblingRoomKeyAt(priorIndex, siblingIndex) == roomKey then
                return true
            end
        end
    end
    return false
end

function roomTopology.siblingCandidateStatus(policy, ctx, candidate)
    if candidate == nil or candidate.key == nil or candidate.key == "" then
        return validStatus()
    end

    local roomKey = roomTopology.roomKey(candidate)
    if roomKey ~= nil and roomKey == ctx.selectedRoomKey then
        return invalidStatus(statusCode(policy, "sibling_same_room"), "Sibling cannot use the selected room")
    end
    if siblingRoomAlreadySelected(ctx, roomKey) then
        return invalidStatus(statusCode(policy, "sibling_same_sibling_room"), "Sibling cannot duplicate another sibling")
    end
    if siblingRoomGeneratedBeforeRow(ctx, roomKey) then
        return invalidStatus(statusCode(policy, "sibling_room_generated"), "Sibling room was already generated")
    end
    if pickedCandidateClosesGroup(policy, ctx, roomKey) then
        return invalidStatus(
            statusCode(policy, "sibling_miniboss_after_selected"),
            "Sibling miniboss cannot appear after a picked miniboss"
        )
    end
    if plannedRoomRowIndex(ctx, roomKey) ~= nil then
        return invalidStatus(statusCode(policy, "sibling_room_planned"), "Sibling room is already planned on this route")
    end
    if ctx.extraRuleStatus ~= nil then
        local status = ctx.extraRuleStatus(candidate, ctx.candidateSiblingIndex)
        if not status.valid then
            return status
        end
    end
    return roomTopology.forcedGroupsStatus(policy, ctx, candidate)
end

local function siblingUnavailableMessage(opts, sibling, siblingKey)
    local message = opts.unavailableMessage
    if type(message) == "function" then
        return message(sibling, siblingKey)
    end
    return message or ("Sibling " .. tostring(sibling and sibling.label or siblingKey) .. " is not valid")
end

function roomTopology.validateSiblingStructures(policy, ctx, opts)
    opts = opts or {}
    local count = roomTopology.activeSiblingCount(policy, ctx)
    for siblingIndex = 1, count do
        local siblingKey, sibling = ctx.siblingAt(siblingIndex)
        if sibling == nil or siblingKey == "" then
            return invalidStatus(opts.requiredCode, opts.requiredMessage), siblingIndex
        end

        local previousSiblingIndex = ctx.candidateSiblingIndex
        ctx.candidateSiblingIndex = siblingIndex
        local siblingStatus = roomTopology.siblingCandidateStatus(policy, ctx, sibling)
        ctx.candidateSiblingIndex = previousSiblingIndex
        if not siblingStatus.valid then
            if roomTopology.isSiblingTopologyStatus(policy, siblingStatus) then
                return siblingStatus, siblingIndex
            end
            return invalidStatus(
                opts.unavailableCode,
                siblingUnavailableMessage(opts, sibling, siblingKey)
            ), siblingIndex
        end
    end
    return nil
end

function roomTopology.isSiblingTopologyStatus(policy, status)
    local code = tostring(status and status.code or "")
    local namespace = tostring(policy and policy.namespace or "topology")
    return string.match(code, "^" .. namespace .. "_sibling_") ~= nil
        or string.match(code, "^" .. namespace .. "_forced_topology_") ~= nil
end

function roomTopology.valueStateForSiblingStatus(policy, status)
    return valueStates.forTopologySiblingStatus(policy and policy.namespace, status)
end

function roomTopology.fillSiblingValueStates(policy, ctx, states)
    clearMap(states)
    if policy == nil then
        return states
    end
    for _, key in ipairs(policy.values or EMPTY_VALUES) do
        local candidate = policy.optionsByKey[key]
        valueStates.set(states, key, roomTopology.valueStateForSiblingStatus(
            policy,
            roomTopology.siblingCandidateStatus(policy, ctx, candidate)
        ))
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
