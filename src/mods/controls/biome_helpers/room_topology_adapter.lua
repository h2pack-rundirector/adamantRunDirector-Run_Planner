local deps = ...
local common = deps.common
local readCache = deps.readCache
local roomTopology = deps.roomTopology
local roomStructure = deps.roomStructure
local valueStates = deps.valueStates
local form = deps.form

local adapter = {}

local validStatus = common.validStatus
local WARNING_STATE = valueStates and valueStates.WARNING or 3
local activeReadCache = readCache.active
local rowRecord = readCache.rowRecord
local nestedRecord = readCache.nestedRecord

local EMPTY_VALUES = {}
local EMPTY_LABELS = {}

local function indexedSiblingStructureAlias(baseAlias, siblingIndex)
    siblingIndex = math.floor(tonumber(siblingIndex) or 1)
    if siblingIndex <= 1 then
        return baseAlias
    end
    local prefix = string.match(baseAlias or "", "^(.*)Key$")
    return (prefix or tostring(baseAlias or "SiblingStructure")) .. tostring(siblingIndex) .. "Key"
end

local function structuralCountForRow(data, slots, instance, rows, rowIndex, field)
    local slot = slots.slotForRow(instance, rowIndex)
    local roleKey, role = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    if field == "exitCount" then
        return math.floor(tonumber(roomStructure.exitCount(slot, role, option)) or 0)
    end
    if field == "rewardBearingExitCount" then
        return math.floor(tonumber(roomStructure.rewardBearingExitCount(slot, role, option)) or 0)
    end
    return 0
end

local function appliedFeedback(instance)
    local routeContext = instance.routeContext
    if routeContext == nil or routeContext.routeGeneration == nil then
        return nil
    end
    if instance.routeFeedbackGeneration ~= routeContext:routeGeneration(instance.routeKey) then
        return nil
    end
    return instance.routeFeedback
end

local function topologyFeedback(instance, rowIndex)
    local feedback = appliedFeedback(instance)
    local row = feedback and feedback[rowIndex] or nil
    return row and row.topology or nil
end

local function maxExitCountForRole(data, role)
    local maxCount = math.floor(tonumber(roomStructure.exitCount(nil, role)) or 0)
    for _, option in ipairs(data.optionListForRole(role)) do
        local count = math.floor(tonumber(roomStructure.exitCount(nil, role, option)) or 0)
        if count > maxCount then
            maxCount = count
        end
    end
    return maxCount
end

function adapter.create(data, opts)
    local api = {}
    local slots = opts.slots

    function api.prepareSiblingStructurePolicy(instance)
        instance.siblingStructurePolicy = roomTopology.prepareSiblingPolicy(opts.topologyForInstance(instance), {
            namespace = opts.namespace,
        })
    end

    function api.prepareSiblingStructureCount(instance)
        if instance.siblingStructurePolicy == nil then
            instance.maxSiblingStructureCount = 0
            return
        end

        local maxExitCount = 0
        for _, role in ipairs(instance.roles or EMPTY_VALUES) do
            local roleMax = maxExitCountForRole(data, role)
            if roleMax > maxExitCount then
                maxExitCount = roleMax
            end
        end
        instance.maxSiblingStructureCount = roomTopology.siblingCountForExitCount(maxExitCount)
    end

    function api.maxSiblingStructureCount(instance)
        return instance.maxSiblingStructureCount or 0
    end

    function api.siblingStructureAlias(instance, siblingIndex)
        local policy = instance.siblingStructurePolicy
        local baseAlias = policy and policy.alias or "SiblingStructureKey"
        if opts.indexedAliases then
            return indexedSiblingStructureAlias(baseAlias, siblingIndex)
        end
        return baseAlias
    end

    function api.siblingStructureControlTargets(instance, siblingIndex)
        return form.selectedTargets({
            tabKey = "rooms",
            controlAlias = api.siblingStructureAlias(instance, siblingIndex),
            state = WARNING_STATE,
        })
    end

    function api.siblingStructureLabels(instance)
        local policy = instance.siblingStructurePolicy
        return policy and policy.labels or EMPTY_LABELS
    end

    function api.siblingStructureValues(instance)
        local policy = instance.siblingStructurePolicy
        return policy and policy.values or EMPTY_VALUES
    end

    function api.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        local policy = instance.siblingStructurePolicy
        if policy == nil then
            return "", nil
        end

        local key = rows and rows:read(rowIndex, api.siblingStructureAlias(instance, siblingIndex)) or ""
        key = key or ""
        return key, policy.optionsByKey[key]
    end

    function api.siblingPolicyContext(instance, rows, rowIndex, siblingIndex)
        local roleKey, role = data.resolveRole(instance, rows, rowIndex)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        return {
            rowIndex = rowIndex,
            routeRowCount = instance.routeRowCount,
            candidateSiblingIndex = siblingIndex,
            isFixedIdentityRow = data.isFixedIdentityRow(instance, rowIndex),
            hasSelectableSiblingStructure = opts.hasSelectableSiblingStructure(
                instance,
                rows,
                rowIndex,
                roleKey,
                role,
                option
            ),
            structuralCountAt = function(index, field)
                return structuralCountForRow(data, slots, instance, rows, index, field)
            end,
            siblingAt = function(currentSiblingIndex)
                return data.resolveSiblingStructure(instance, rows, rowIndex, currentSiblingIndex)
            end,
        }
    end

    function api.siblingTopologyStatus(instance, _rows, rowIndex)
        local policy = instance.siblingStructurePolicy
        if policy == nil then
            return validStatus()
        end
        local feedback = topologyFeedback(instance, rowIndex)
        if feedback ~= nil and feedback.active == false then
            return common.invalidStatus("biome_depth_unavailable", "Topology controls are not active at this biome depth")
        end
        return validStatus()
    end

    function api.siblingStructureStatus(instance, _rows, rowIndex)
        local policy = instance.siblingStructurePolicy
        if policy == nil then
            return validStatus()
        end
        local feedback = topologyFeedback(instance, rowIndex)
        if feedback ~= nil and feedback.controlsActive == false then
            return common.invalidStatus("biome_depth_unavailable", "Topology controls are not active at this biome depth")
        end
        return validStatus()
    end

    function api.activeSiblingStructureCount(instance, rows, rowIndex)
        local cache = activeReadCache(instance)
        if cache == nil then
            return roomTopology.activeSiblingCount(
                instance.siblingStructurePolicy,
                api.siblingPolicyContext(instance, rows, rowIndex)
            )
        end

        cache.activeSiblingStructureCounts = cache.activeSiblingStructureCounts or {}
        local record = rowRecord(cache.activeSiblingStructureCounts, rowIndex)
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.value = roomTopology.activeSiblingCount(
                instance.siblingStructurePolicy,
                api.siblingPolicyContext(instance, rows, rowIndex)
            )
        end
        return record.value
    end

    function api.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
        return roomTopology.shouldDrawActiveSibling(
            data.activeSiblingStructureCount(instance, rows, rowIndex),
            data.siblingStructureStatus(instance, rows, rowIndex),
            siblingIndex
        )
    end

    function api.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
        local cache = activeReadCache(instance)
        if cache == nil then
            return roomTopology.fillSiblingValueStates(
                instance.siblingStructurePolicy,
                api.siblingPolicyContext(instance, rows, rowIndex, siblingIndex),
                {}
            )
        end

        cache.siblingStructureValueStates = cache.siblingStructureValueStates or {}
        local record
        if opts.indexedAliases then
            record = nestedRecord(cache.siblingStructureValueStates, rowIndex, siblingIndex or 1)
        else
            record = rowRecord(cache.siblingStructureValueStates, rowIndex)
        end
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.states = record.states or {}
            roomTopology.fillSiblingValueStates(
                instance.siblingStructurePolicy,
                api.siblingPolicyContext(instance, rows, rowIndex, siblingIndex),
                record.states
            )
        end
        return record.states
    end

    function api.validateSiblingStructures(instance, rows, rowIndex, validateOpts)
        local invalid, siblingIndex = roomTopology.validateRequiredSiblingStructures(
            instance.siblingStructurePolicy,
            api.siblingPolicyContext(instance, rows, rowIndex),
            validateOpts
        )
        if invalid ~= nil and invalid.controlTargets == nil then
            invalid.tabKey = "rooms"
            invalid.controlTargets = api.siblingStructureControlTargets(instance, siblingIndex)
        end
        return invalid
    end

    return api
end

return adapter
