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

local EMPTY_VALUES = {}
local EMPTY_LABELS = {}

local function rewardAddresses(count)
    local addresses = {}
    for index = 1, count do
        addresses[index] = "cage:" .. tostring(index)
    end
    return addresses
end

local function selectedRoomTopology(roleKey, option, cageCount)
    if roleKey == "Combat" then
        local count = math.floor(tonumber(cageCount and cageCount.cageRewardCount) or 0)
        if count <= 0 then
            return nil
        end
        return {
            structure = "CombatCage" .. tostring(count),
            rewardStore = "RunProgress",
            offerCount = count,
            rewardAddresses = rewardAddresses(count),
        }
    elseif roleKey == "Miniboss" then
        return {
            structure = "Miniboss",
            roomKey = option and option.key or nil,
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Bridge" then
        return {
            structure = "Bridge",
            offerCount = 0,
        }
    end
    return nil
end

local function siblingRoomTopology(option)
    if option == nil or option.key == nil or option.key == "" then
        return nil
    end
    return {
        structure = option.structure,
        roomKey = roomTopology.roomKey(option),
        rewardStore = option.rewardStore,
        eligibleRewardTypes = option.eligibleRewardTypes,
        offerCount = option.offerCount,
    }
end

local function isCombatCageStructure(structure)
    return string.match(tostring(structure or ""), "^CombatCage%d+$") ~= nil
end

local function hasSelectableSiblingStructure(roleKey)
    return roleKey == "Combat" or roleKey == "Miniboss" or roleKey == "Bridge"
end

function topology.create(data)
    local function rowRoomKey(instance, rows, rowIndex)
        return data.rowRoomKey(instance, rows, rowIndex)
    end

    local function selectedCombatCageRewardCount(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if roleKey ~= "Combat" then
            return nil
        end

        local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
        local count = cageCount and math.floor(tonumber(cageCount.cageRewardCount) or 0) or 0
        if count <= 0 then
            return nil
        end
        return count
    end

    local function matchingCombatCageRewardCountStatus(instance, rows, rowIndex, sibling)
        if not isCombatCageStructure(sibling and sibling.structure) then
            return validStatus()
        end

        local selectedCount = selectedCombatCageRewardCount(instance, rows, rowIndex)
        if selectedCount == nil then
            return validStatus()
        end

        local siblingCount = math.floor(tonumber(sibling.offerCount) or 0)
        if siblingCount == selectedCount then
            return validStatus()
        end
        return invalidStatus(
            "fields_sibling_combat_cage_count_mismatch",
            "Sibling combat reward count must match selected combat reward count"
        )
    end

    local function topologyRuleStatus(instance, rows, rowIndex, sibling, rule)
        if rule.key == "matchingCombatCageRewardCount" then
            return matchingCombatCageRewardCountStatus(instance, rows, rowIndex, sibling)
        end
        return validStatus()
    end

    local function topologyRulesStatus(instance, rows, rowIndex, sibling)
        local policy = instance.siblingStructurePolicy
        for _, rule in ipairs(policy and policy.rules or EMPTY_VALUES) do
            local status = topologyRuleStatus(instance, rows, rowIndex, sibling, rule)
            if not status.valid then
                return status
            end
        end
        return validStatus()
    end

    local function siblingCandidateRoomKey(instance, rows, rowIndex)
        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex)
        return roomTopology.roomKey(sibling)
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

    local function siblingPolicyContext(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        return {
            rowIndex = rowIndex,
            routeRowCount = instance.routeRowCount,
            isFixedIdentityRow = data.isFixedIdentityRow(instance, rowIndex),
            hasSelectableSiblingStructure = hasSelectableSiblingStructure(roleKey),
            rowContext = data.rowContext(instance, rows, rowIndex),
            selectedRoomKey = rowRoomKey(instance, rows, rowIndex),
            structuralCountAt = function(index, field)
                return structuralCountForRow(instance, rows, index, field)
            end,
            roomKeyAt = function(index)
                return rowRoomKey(instance, rows, index)
            end,
            siblingAt = function()
                return data.resolveSiblingStructure(instance, rows, rowIndex)
            end,
            siblingRoomKeyAt = function(index)
                return siblingCandidateRoomKey(instance, rows, index)
            end,
            siblingCountAt = function(index)
                return data.activeSiblingStructureCount(instance, rows, index)
            end,
            extraRuleStatus = function(sibling)
                return topologyRulesStatus(instance, rows, rowIndex, sibling)
            end,
        }
    end

    local function siblingAvailabilityStatus(instance, rows, rowIndex, sibling)
        return roomTopology.siblingCandidateStatus(
            instance.siblingStructurePolicy,
            siblingPolicyContext(instance, rows, rowIndex),
            sibling
        )
    end

    local function fillSiblingStructureValueStates(instance, rows, rowIndex, states)
        return roomTopology.fillSiblingValueStates(
            instance.siblingStructurePolicy,
            siblingPolicyContext(instance, rows, rowIndex),
            states
        )
    end

    local api = {}

    function api.prepareSiblingStructurePolicy(instance)
        local biomeTopology = instance.biome.fields
            and instance.biome.fields.roomTopology
            or nil
        instance.siblingStructurePolicy = roomTopology.prepareSiblingPolicy(biomeTopology, {
            namespace = "fields",
        })
    end

    function api.siblingStructureAlias(instance)
        local policy = instance.siblingStructurePolicy
        return policy and policy.alias or "SiblingStructureKey"
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

    function api.shouldDrawSiblingStructure(instance, rows, rowIndex)
        return roomTopology.shouldDrawActiveSibling(
            data.activeSiblingStructureCount(instance, rows, rowIndex),
            data.siblingStructureStatus(instance, rows, rowIndex),
            1
        )
    end

    function api.resolveSiblingStructure(instance, rows, rowIndex)
        local policy = instance.siblingStructurePolicy
        if policy == nil then
            return "", nil
        end

        local key = rows and rows:read(rowIndex, policy.alias) or ""
        key = key or ""
        return key, policy.optionsByKey[key]
    end

    function api.siblingStructureValueStatesForRow(instance, rows, rowIndex)
        local cache = activeReadCache(instance)
        if cache == nil then
            return fillSiblingStructureValueStates(instance, rows, rowIndex, {})
        end

        cache.siblingStructureValueStates = cache.siblingStructureValueStates or {}
        local record = rowRecord(cache.siblingStructureValueStates, rowIndex)
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.states = record.states or {}
            fillSiblingStructureValueStates(instance, rows, rowIndex, record.states)
        end
        return record.states
    end

    function api.validateRoomTopology(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if data.isFixedIdentityRow(instance, rowIndex) then
            return nil
        end

        if not hasSelectableSiblingStructure(roleKey) then
            return nil
        end

        local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
        if roleKey == "Combat" and (cageCount == nil or (cageCount.cageRewardCount or 0) <= 0) then
            return invalidStatus("fields_cage_count_required", "Fields topology needs picked cage reward count")
        end

        local siblingInvalid = roomTopology.validateSiblingStructures(
            instance.siblingStructurePolicy,
            siblingPolicyContext(instance, rows, rowIndex),
            {
                requiredCode = "fields_sibling_structure_required",
                requiredMessage = "Fields topology needs sibling door structure",
                unavailableCode = "fields_sibling_structure_unavailable",
                unavailableMessage = function(sibling, siblingKey)
                    return "Sibling " .. tostring(sibling.label or siblingKey) .. " is not valid at this pick"
                end,
            }
        )
        if siblingInvalid ~= nil then
            return siblingInvalid
        end
        return nil
    end

    function api.roomTopology(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if data.isFixedIdentityRow(instance, rowIndex) then
            return nil
        end
        if data.activeSiblingStructureCount(instance, rows, rowIndex) < 1 then
            return nil
        end
        if not data.siblingStructureStatus(instance, rows, rowIndex).valid then
            return nil
        end

        local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex)
        if not siblingAvailabilityStatus(instance, rows, rowIndex, sibling).valid then
            return nil
        end
        local selected = selectedRoomTopology(roleKey, option, cageCount)
        local siblingTopology = siblingRoomTopology(sibling)
        if selected == nil or siblingTopology == nil then
            return nil
        end

        return {
            kind = "fieldsChoice",
            selected = selected,
            sibling = siblingTopology,
        }
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

    return api
end

return topology
