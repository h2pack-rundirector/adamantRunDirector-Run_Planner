local deps = ...
local common = deps.common
local readCache = deps.readCache
local roomTopology = deps.roomTopology
local roomStructure = deps.roomStructure
local slots = deps.slots

local topology = {}

local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
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

local function rewardStoreForMajorMinorChoice(rows, rowIndex)
    local rewardClass = rows and rows:read(rowIndex, "Reward1Key") or nil
    if rewardClass == "Major" then
        return "RunProgress", "Major"
    elseif rewardClass == "Minor" then
        return "MetaProgress", "Minor"
    end
    return nil, nil
end

local function selectedRoomTopology(roleKey, option, rows, rowIndex)
    if roleKey == "Combat" or roleKey == "Fountain" then
        local rewardStore, rewardClass = rewardStoreForMajorMinorChoice(rows, rowIndex)
        return {
            structure = roleKey,
            roomKey = option and option.key or nil,
            rewardStore = rewardStore,
            rewardClass = rewardClass,
            offerCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Miniboss" then
        if option == nil then
            return nil
        end
        return {
            structure = "Miniboss",
            roomKey = option.key,
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Story" then
        return {
            structure = "Story",
            roomKey = option and option.key or nil,
            offerCount = 0,
        }
    elseif roleKey == "Midshop" then
        return {
            structure = "Midshop",
            roomKey = option and option.key or nil,
            offerCount = 0,
        }
    end
    return nil
end

local function selectedRoomTopologyForRow(data, instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return selectedRoomTopology(roleKey, option, rows, rowIndex)
end

local function hasSelectableSiblingStructure(roleKey, option)
    return roleKey == "Combat"
        or roleKey == "Fountain"
        or roleKey == "Story"
        or roleKey == "Midshop"
        or (roleKey == "Miniboss" and option ~= nil)
end

local function siblingRoomTopology(option)
    if option == nil or option.key == nil or option.key == "" then
        return nil
    end
    return {
        structure = option.structure,
        roomKey = roomTopology.roomKey(option),
        rewardStore = option.rewardStore,
        rewardClass = option.rewardClass,
        eligibleRewardTypes = option.eligibleRewardTypes,
        offerCount = option.offerCount,
    }
end

local function rowRoomKey(data, instance, rows, rowIndex)
    return data.rowRoomKey(instance, rows, rowIndex)
end

local function selectedRewardStoreForRow(data, instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    if roleKey == "Combat" or roleKey == "Fountain" then
        return rewardStoreForMajorMinorChoice(rows, rowIndex)
    elseif roleKey == "Miniboss" then
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        return option and "RunProgress" or nil
    end
    return nil
end

function topology.create(data)
    local function siblingCandidateRoomKey(instance, rows, rowIndex, siblingIndex)
        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        return roomTopology.roomKey(sibling)
    end

    local function siblingRewardStoreForRow(instance, rows, rowIndex, siblingIndex)
        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        return sibling and sibling.rewardStore or nil
    end

    local function structuralCountForRow(instance, rows, rowIndex, field)
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

    local function matchingSiblingRewardStoreStatus(instance, rows, rowIndex, siblingIndex, sibling)
        local candidateStore = sibling and sibling.rewardStore or nil
        if candidateStore == nil then
            return validStatus()
        end

        local selectedStore = selectedRewardStoreForRow(data, instance, rows, rowIndex)
        if selectedStore ~= nil and selectedStore ~= candidateStore then
            return invalidStatus(
                "fixed_sibling_reward_store_mismatch",
                "Sibling reward store must match selected reward store"
            )
        end

        for otherSiblingIndex = 1, data.activeSiblingStructureCount(instance, rows, rowIndex) do
            if otherSiblingIndex ~= siblingIndex then
                local otherStore = siblingRewardStoreForRow(instance, rows, rowIndex, otherSiblingIndex)
                if otherStore ~= nil and otherStore ~= candidateStore then
                    return invalidStatus(
                        "fixed_sibling_reward_store_mismatch",
                        "Sibling reward stores must match"
                    )
                end
            end
        end
        return validStatus()
    end

    local function topologyRuleStatus(instance, rows, rowIndex, siblingIndex, sibling, rule)
        if rule.key == "matchingSiblingRewardStore" then
            return matchingSiblingRewardStoreStatus(instance, rows, rowIndex, siblingIndex, sibling)
        end
        return validStatus()
    end

    local function topologyRulesStatus(instance, rows, rowIndex, siblingIndex, sibling)
        local policy = instance.siblingStructurePolicy
        for _, rule in ipairs(policy and policy.rules or EMPTY_VALUES) do
            local status = topologyRuleStatus(instance, rows, rowIndex, siblingIndex, sibling, rule)
            if not status.valid then
                return status
            end
        end
        return validStatus()
    end

    local function siblingPolicyContext(instance, rows, rowIndex, siblingIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        return {
            rowIndex = rowIndex,
            routeRowCount = instance.routeRowCount,
            candidateSiblingIndex = siblingIndex,
            isFixedIdentityRow = data.isFixedIdentityRow(instance, rowIndex),
            hasSelectableSiblingStructure = hasSelectableSiblingStructure(roleKey, option),
            rowContext = data.rowContext(instance, rows, rowIndex),
            selectedRoomKey = rowRoomKey(data, instance, rows, rowIndex),
            structuralCountAt = function(index, field)
                return structuralCountForRow(instance, rows, index, field)
            end,
            roomKeyAt = function(index)
                return rowRoomKey(data, instance, rows, index)
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
                return topologyRulesStatus(instance, rows, rowIndex, currentSiblingIndex or siblingIndex, sibling)
            end,
        }
    end

    local function maxExitCountForRole(role)
        local maxCount = math.floor(tonumber(roomStructure.exitCount(nil, role)) or 0)
        for _, option in ipairs(data.optionListForRole(role)) do
            local count = math.floor(tonumber(roomStructure.exitCount(nil, role, option)) or 0)
            if count > maxCount then
                maxCount = count
            end
        end
        return maxCount
    end

    local function siblingAvailabilityStatus(instance, rows, rowIndex, siblingIndex, sibling)
        return roomTopology.siblingCandidateStatus(
            instance.siblingStructurePolicy,
            siblingPolicyContext(instance, rows, rowIndex, siblingIndex),
            sibling
        )
    end

    local function fillSiblingStructureValueStates(instance, rows, rowIndex, siblingIndex, states)
        return roomTopology.fillSiblingValueStates(
            instance.siblingStructurePolicy,
            siblingPolicyContext(instance, rows, rowIndex, siblingIndex),
            states
        )
    end

    local function siblingTopologies(instance, rows, rowIndex)
        local siblings = {}
        local count = data.activeSiblingStructureCount(instance, rows, rowIndex)
        for siblingIndex = 1, count do
            local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
            if siblingAvailabilityStatus(instance, rows, rowIndex, siblingIndex, sibling).valid ~= true then
                return nil
            end

            local siblingTopology = siblingRoomTopology(sibling)
            if siblingTopology == nil then
                return nil
            end
            siblings[#siblings + 1] = siblingTopology
        end
        if siblings[1] == nil then
            return nil
        end
        return siblings
    end

    local api = {}

    function api.prepareSiblingStructurePolicy(instance)
        instance.siblingStructurePolicy = roomTopology.prepareSiblingPolicy(instance.biome.roomTopology, {
            namespace = "fixed",
        })
    end

    function api.prepareSiblingStructureCount(instance)
        if instance.siblingStructurePolicy == nil then
            instance.maxSiblingStructureCount = 0
            return
        end

        local maxExitCount = 0
        for _, role in ipairs(instance.roles or EMPTY_VALUES) do
            local roleMax = maxExitCountForRole(role)
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
        return indexedSiblingStructureAlias(policy and policy.alias or "SiblingStructureKey", siblingIndex)
    end

    function api.siblingStructureLabels(instance)
        local policy = instance.siblingStructurePolicy
        return policy and policy.labels or EMPTY_LABELS
    end

    function api.siblingStructureValues(instance)
        local policy = instance.siblingStructurePolicy
        return policy and policy.values or EMPTY_VALUES
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
                siblingPolicyContext(instance, rows, rowIndex)
            )
        end

        cache.activeSiblingStructureCounts = cache.activeSiblingStructureCounts or {}
        local record = rowRecord(cache.activeSiblingStructureCounts, rowIndex)
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.value = roomTopology.activeSiblingCount(
                instance.siblingStructurePolicy,
                siblingPolicyContext(instance, rows, rowIndex)
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

    function api.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        local policy = instance.siblingStructurePolicy
        if policy == nil then
            return "", nil
        end

        local key = rows and rows:read(rowIndex, data.siblingStructureAlias(instance, siblingIndex)) or ""
        key = key or ""
        return key, policy.optionsByKey[key]
    end

    function api.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
        local cache = activeReadCache(instance)
        if cache == nil then
            return fillSiblingStructureValueStates(instance, rows, rowIndex, siblingIndex, {})
        end

        cache.siblingStructureValueStates = cache.siblingStructureValueStates or {}
        local record = nestedRecord(cache.siblingStructureValueStates, rowIndex, siblingIndex or 1)
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.states = record.states or {}
            fillSiblingStructureValueStates(instance, rows, rowIndex, siblingIndex, record.states)
        end
        return record.states
    end

    function api.validateRoomTopology(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        if not hasSelectableSiblingStructure(roleKey, option) then
            return nil
        end

        local ctx = siblingPolicyContext(instance, rows, rowIndex)
        local siblingInvalid = roomTopology.validateSiblingStructures(instance.siblingStructurePolicy, ctx, {
            requiredCode = "fixed_sibling_structure_required",
            requiredMessage = "Topology needs sibling door structure",
            unavailableCode = "fixed_sibling_structure_unavailable",
            unavailableMessage = function(sibling, siblingKey)
                return "Sibling " .. tostring(sibling.label or siblingKey) .. " is not valid at this depth"
            end,
        })
        if siblingInvalid ~= nil then
            return siblingInvalid
        end

        local forcedStatus = roomTopology.forcedGroupsStatus(
            instance.siblingStructurePolicy,
            ctx
        )
        if not forcedStatus.valid then
            return forcedStatus
        end
        return nil
    end

    function api.roomTopology(instance, rows, rowIndex)
        if instance.siblingStructurePolicy == nil
            or data.isFixedIdentityRow(instance, rowIndex)
            or not data.siblingStructureStatus(instance, rows, rowIndex).valid
        then
            return nil
        end

        local selected = selectedRoomTopologyForRow(data, instance, rows, rowIndex)
        local siblings = siblingTopologies(instance, rows, rowIndex)
        if selected == nil or siblings == nil then
            return nil
        end

        return {
            kind = "fixedLinearSiblingChoice",
            selected = selected,
            sibling = siblings[1],
            siblings = siblings,
        }
    end

    return api
end

return topology
