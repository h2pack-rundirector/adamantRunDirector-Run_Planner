local deps = ...
local common = deps.common
local readCache = deps.readCache
local roomTopology = deps.roomTopology
local roomStructure = deps.roomStructure

local adapter = {}

local validStatus = common.validStatus
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
    if field == "rewardExitCount" then
        return math.floor(tonumber(roomStructure.rewardExitCount(slot, role, option)) or 0)
    end
    return 0
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

    local function rowRoomKey(instance, rows, rowIndex)
        return data.rowRoomKey(instance, rows, rowIndex)
    end

    local function siblingCandidateRoomKey(instance, rows, rowIndex, siblingIndex)
        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        return roomTopology.roomKey(sibling)
    end

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
            rowContext = data.rowContext(instance, rows, rowIndex),
            selectedRoomKey = rowRoomKey(instance, rows, rowIndex),
            structuralCountAt = function(index, field)
                return structuralCountForRow(data, slots, instance, rows, index, field)
            end,
            roomKeyAt = function(index)
                return rowRoomKey(instance, rows, index)
            end,
            siblingAt = function(currentSiblingIndex)
                return data.resolveSiblingStructure(instance, rows, rowIndex, currentSiblingIndex)
            end,
            siblingCountAt = function(index)
                return data.activeSiblingStructureCount(instance, rows, index)
            end,
            siblingRoomKeyAt = function(index, currentSiblingIndex)
                return siblingCandidateRoomKey(instance, rows, index, currentSiblingIndex)
            end,
            extraRuleStatus = function(sibling, currentSiblingIndex)
                if opts.extraRuleStatus == nil then
                    return validStatus()
                end
                return opts.extraRuleStatus(
                    instance,
                    rows,
                    rowIndex,
                    currentSiblingIndex or siblingIndex,
                    sibling
                )
            end,
        }
    end

    function api.siblingStructureStatus(instance, rows, rowIndex)
        local policy = instance.siblingStructurePolicy
        if policy == nil then
            return validStatus()
        end
        local cache = activeReadCache(instance)
        if cache == nil then
            return roomTopology.siblingWindowStatus(policy, data.rowContext(instance, rows, rowIndex))
        end

        cache.siblingStructureStatus = cache.siblingStructureStatus or {}
        local record = rowRecord(cache.siblingStructureStatus, rowIndex)
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.status = roomTopology.siblingWindowStatus(policy, data.rowContext(instance, rows, rowIndex))
        end
        return record.status
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

    function api.siblingAvailabilityStatus(instance, rows, rowIndex, siblingIndex, sibling)
        return roomTopology.siblingCandidateStatus(
            instance.siblingStructurePolicy,
            api.siblingPolicyContext(instance, rows, rowIndex, siblingIndex),
            sibling
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
        return roomTopology.validateSiblingStructures(
            instance.siblingStructurePolicy,
            api.siblingPolicyContext(instance, rows, rowIndex),
            validateOpts
        )
    end

    return api
end

return adapter
