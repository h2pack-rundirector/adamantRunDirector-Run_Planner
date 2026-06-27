local deps = ...
local common = deps.common
local availability = deps.availability
local valueStates = deps.valueStates

local buildKeyLookup = common.buildKeyLookup
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
local availabilityStatus = availability.status

local roomTopology = {}

local EMPTY_VALUES = {}
local MAX_NORMAL_SIBLING_COUNT = 2

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
        availability = topology.siblingStructureWindow,
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

function roomTopology.siblingWindowStatus(policy, rowContext)
    if policy == nil then
        return validStatus()
    end
    return availabilityStatus({
        availability = policy.availability,
    }, rowContext)
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
    local count = math.max(math.floor(tonumber(exitCount) or 0) - 1, 0)
    if count > MAX_NORMAL_SIBLING_COUNT then
        return MAX_NORMAL_SIBLING_COUNT
    end
    return count
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

function roomTopology.shouldDrawActiveSibling(activeSiblingCount, windowStatus, siblingIndex)
    if (activeSiblingCount or 0) < (siblingIndex or 1) then
        return false
    end
    return windowStatus ~= nil and windowStatus.valid == true
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

local function siblingRoomKeyForSlot(ctx, index, siblingIndex, candidateOverride)
    if index == ctx.rowIndex
        and candidateOverride ~= nil
        and siblingIndex == (ctx.candidateSiblingIndex or 1)
    then
        return roomTopology.roomKey(candidateOverride)
    end
    if ctx.siblingRoomKeyAt == nil then
        return nil
    end
    return ctx.siblingRoomKeyAt(index, siblingIndex)
end

local function generatedSiblingCandidateAt(ctx, index, candidate, candidateOverride)
    local count = siblingCountAt(ctx, index)
    for siblingIndex = 1, count do
        if siblingRoomKeyForSlot(ctx, index, siblingIndex, candidateOverride) == candidate then
            return true
        end
    end
    return false
end

local function generatedCandidateAtRow(ctx, index, candidate, candidateOverride)
    if ctx.roomKeyAt(index) == candidate then
        return true
    end
    return generatedSiblingCandidateAt(ctx, index, candidate, candidateOverride)
end

local function generatedCandidateBeforeRow(ctx, candidate)
    for currentRowIndex = 1, ctx.rowIndex - 1 do
        if generatedCandidateAtRow(ctx, currentRowIndex, candidate) then
            return true
        end
    end
    return false
end

local function generatedCandidateThroughRow(ctx, candidate, candidateOverride)
    for currentRowIndex = 1, ctx.rowIndex do
        if generatedCandidateAtRow(ctx, currentRowIndex, candidate, candidateOverride) then
            return true
        end
    end
    return false
end

local function generatedCandidateCountThroughRow(ctx, group, candidateOverride)
    local count = 0
    for _, candidate in ipairs(group.candidates or EMPTY_VALUES) do
        if generatedCandidateThroughRow(ctx, candidate, candidateOverride) then
            count = count + 1
        end
    end
    return count
end

local function generatedCapacityForGroup(ctx, group)
    if group.generatedExitCount ~= nil then
        return group.generatedExitCount
    end
    if group.generatedCapacityKind == "sourceSiblingCount" then
        return roomTopology.siblingCountForExitCount(roomTopology.generatedStructuralCount(ctx, "exitCount"))
    end
    if group.generatedCapacityKind == "sourceExitCount" then
        return roomTopology.generatedStructuralCount(ctx, "exitCount")
    end
    if group.generatedExitCountField ~= nil and ctx.structuralCountAt ~= nil then
        return roomTopology.generatedStructuralCount(ctx, group.generatedExitCountField)
    end
    return 0
end

local function requiredGeneratedCountForGroup(ctx, group)
    if group.requiredGeneratedCount ~= nil then
        return group.requiredGeneratedCount
    end
    return math.min(#(group.candidates or EMPTY_VALUES), generatedCapacityForGroup(ctx, group))
end

local function forcedCandidateOption(policy, candidate)
    return policy and (
        policy.optionsByKey[candidate]
        or policy.optionsByRoomKey[candidate]
    ) or nil
end

local function forceRangeWindowActive(force, rowContext)
    local range = force and force.biomeDepthCache or nil
    local depth = rowContext and rowContext.biomeDepthCache or nil
    if range == nil or depth == nil then
        return false
    end

    if range.exact ~= nil then
        return depth == range.exact
    end
    if range.min ~= nil and depth < range.min then
        return false
    end
    return range.min ~= nil or range.max ~= nil
end

local function forceRangeDeadlineActive(force, rowContext)
    local range = force and force.biomeDepthCache or nil
    local depth = rowContext and rowContext.biomeDepthCache or nil
    if range == nil or depth == nil then
        return false
    end

    if range.exact ~= nil then
        return depth == range.exact
    end
    if range.min ~= nil and depth < range.min then
        return false
    end
    return range.max ~= nil and depth >= range.max
end

local function forceCandidateClosedByPickedGroup(policy, ctx, candidate)
    for _, group in ipairs(policy and policy.forcedGroups or EMPTY_VALUES) do
        if group.pickedCandidateBeforeDeadlineClosesGroup
            and candidateInGroup(group, candidate)
            and pickedCandidateBeforeRow(ctx, group)
        then
            return true
        end
    end
    return false
end

local function forceCandidateAvailable(policy, ctx, candidate)
    if generatedCandidateBeforeRow(ctx, candidate) then
        return nil
    end
    if forceCandidateClosedByPickedGroup(policy, ctx, candidate) then
        return nil
    end

    local option = forcedCandidateOption(policy, candidate)
    if not availabilityStatus(option, ctx.rowContext).valid then
        return nil
    end
    return option
end

local function forceWindowCandidateActive(policy, ctx, candidate)
    local option = forceCandidateAvailable(policy, ctx, candidate)
    return option ~= nil and forceRangeWindowActive(option.force, ctx.rowContext)
end

local function forceDeadlineCandidateActive(policy, ctx, candidate)
    local option = forceCandidateAvailable(policy, ctx, candidate)
    return option ~= nil and forceRangeDeadlineActive(option.force, ctx.rowContext)
end

local function forceCandidateKeys(policy)
    local index = 0
    return function()
        while true do
            index = index + 1
            local key = policy and policy.values and policy.values[index] or nil
            if key == nil then
                return nil
            end

            local candidate = roomTopology.roomKey(policy.optionsByKey[key])
            if candidate ~= nil then
                return candidate
            end
        end
    end
end

local function generatedForceWindowCandidateCount(policy, ctx, candidateOverride)
    local count = 0
    for candidate in forceCandidateKeys(policy) do
        if forceWindowCandidateActive(policy, ctx, candidate)
            and generatedCandidateAtRow(ctx, ctx.rowIndex, candidate, candidateOverride)
        then
            count = count + 1
        end
    end
    return count
end

local function hardForcePressureStatus(policy, ctx, candidateOverride)
    if policy == nil or #(policy.ungroupedForceCandidates or EMPTY_VALUES) <= 0 then
        return validStatus()
    end

    local capacity = roomTopology.generatedStructuralCount(ctx, "exitCount")
    if capacity <= 0 then
        return validStatus()
    end

    local hasMissingHardForce = false
    for _, candidate in ipairs(policy.ungroupedForceCandidates) do
        if forceDeadlineCandidateActive(policy, ctx, candidate)
            and not generatedCandidateAtRow(ctx, ctx.rowIndex, candidate, candidateOverride)
        then
            hasMissingHardForce = true
            break
        end
    end
    if not hasMissingHardForce then
        return validStatus()
    end

    if generatedForceWindowCandidateCount(policy, ctx, candidateOverride) >= capacity then
        return validStatus()
    end
    return invalidStatus(
        statusCode(policy, "forced_topology_pressure_unresolved"),
        "Hard-forced topology needs generated force-window doors"
    )
end

local function forcedGroupStatus(policy, ctx, group, candidateOverride)
    local deadline = group.forceAtBiomeDepthMax
    if deadline == nil then
        return validStatus()
    end

    if (ctx.rowContext.biomeDepthCache or 0) < deadline then
        return validStatus()
    end
    if group.pickedCandidateBeforeDeadlineClosesGroup and pickedCandidateBeforeRow(ctx, group) then
        return validStatus()
    end

    local generatedCount = generatedCandidateCountThroughRow(ctx, group, candidateOverride)
    local requiredGeneratedCount = requiredGeneratedCountForGroup(ctx, group)
    if generatedCount >= requiredGeneratedCount then
        return validStatus()
    end
    return invalidStatus(
        statusCode(policy, "forced_topology_group_unresolved"),
        "Forced " .. tostring(group.key or "topology") .. " deadline needs generated forced doors"
    )
end

function roomTopology.forcedGroupsStatus(policy, ctx, candidateOverride)
    local hardForceStatus = hardForcePressureStatus(policy, ctx, candidateOverride)
    if not hardForceStatus.valid then
        return hardForceStatus
    end

    for _, group in ipairs(policy and policy.forcedGroups or EMPTY_VALUES) do
        local status = forcedGroupStatus(policy, ctx, group, candidateOverride)
        if not status.valid then
            return status
        end
    end
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

    local status = availabilityStatus(candidate, ctx.rowContext)
    if not status.valid then
        return status
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
        status = ctx.extraRuleStatus(candidate, ctx.candidateSiblingIndex)
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
    if roomTopology.siblingWindowStatus(policy, ctx.rowContext).valid ~= true then
        return nil
    end

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
    if status == nil or status.valid then
        return valueStates.NORMAL
    end
    if status.code == statusCode(policy, "sibling_same_room")
        or status.code == statusCode(policy, "sibling_room_planned")
        or status.code == statusCode(policy, "sibling_miniboss_after_selected")
        or status.code == statusCode(policy, "sibling_same_sibling_room")
        or status.code == statusCode(policy, "sibling_room_generated")
    then
        return valueStates.HIDDEN
    end
    return valueStates.forStatus(status)
end

function roomTopology.fillSiblingValueStates(policy, ctx, states)
    clearMap(states)
    if policy == nil then
        return states
    end
    if not roomTopology.siblingWindowStatus(policy, ctx.rowContext).valid then
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
