local deps = ...
local common = deps.common
local readCache = deps.readCache
local timeline = deps.timeline
local rowEngine = deps.rowEngine
local roomTopology = deps.roomTopology

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local buildOptionChoices = common.buildOptionChoices
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
local activeReadCache = readCache.active
local rowRecord = readCache.rowRecord
local fixedBiomeDepthCacheCost = common.fixedBiomeDepthCacheCost
local routeBiomeDepthCacheCost = common.routeBiomeDepthCacheCost
local routeStartOrdinal = common.routeStartOrdinal
local routeEndOrdinal = common.routeEndOrdinal
local routeRowLabel = common.routeRowLabel
local applySlotDepthContext = common.applySlotDepthContext
local fixedRoomKey = common.fixedRoomKey
local fixedRoomField = common.fixedRoomField

local data
local EMPTY_VALUES = {}
local EMPTY_LABELS = {}

local function shallowCopyMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function isFixedSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function buildFixedSlot(instance, entry, section)
    local roomOptions = shallowCopyList(entry.roomOptions)
    local roomKey = fixedRoomKey(entry)
    local role = {
        key = entry.key,
        label = entry.label or entry.key,
        roomKey = roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = entry.reward,
        exitCount = fixedRoomField(entry, "exitCount"),
        rewardExitCount = fixedRoomField(entry, "rewardExitCount"),
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    }
    buildOptionChoices(role)

    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = entry.routeOrdinal,
        kind = entry.kind or section or "fixed",
        isBiomeEntry = entry.isBiomeEntry == true,
        label = entry.label or entry.key,
        roomKey = roomKey,
        exitCount = role.exitCount,
        rewardExitCount = role.rewardExitCount,
        roomOfferCount = entry.roomOfferCount or common.rewardOfferCount(entry.reward),
        roleKey = role.key,
        role = role,
        locked = entry.locked,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    }, {
        biomeDepthCache = entry.biomeDepthCache,
        biomeDepthCacheCost = fixedBiomeDepthCacheCost(instance.biome.slotLayout, entry),
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    })
end

local function buildPickSlot(instance, ordinal)
    local slotLayout = instance.biome.slotLayout or {}
    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = ordinal,
        kind = "biomeRow",
        label = routeRowLabel(slotLayout, ordinal, "Pick"),
    }, {
        biomeDepthCacheCost = routeBiomeDepthCacheCost(slotLayout),
    })
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startOrdinal = routeStartOrdinal(slotLayout)
    local endOrdinal = routeEndOrdinal(slotLayout, startOrdinal)

    instance.routeSlots = {}
    for _, entry in ipairs(slotLayout.fixedBeforeRoute or {}) do
        buildFixedSlot(instance, entry, "fixedBeforeRoute")
    end
    for ordinal = startOrdinal, endOrdinal do
        buildPickSlot(instance, ordinal)
    end
    for _, entry in ipairs(slotLayout.fixedAfterRoute or {}) do
        buildFixedSlot(instance, entry, "fixedAfterRoute")
    end
    instance.routeRowCount = #instance.routeSlots
end

local function addFixedRoleLabels(instance)
    for _, slot in ipairs(instance.routeSlots or {}) do
        if slot.roleKey ~= nil then
            instance.roleLabels[slot.roleKey] = slot.label or slot.roleKey
        end
    end
end

local function variantStorageKey(policy, option)
    if option.key == policy.defaultKey then
        return ""
    end
    return option.key
end

local function prepareCagePolicy(policy)
    if policy == nil or policy.countControl == nil then
        return nil
    end

    local countControl = policy.countControl
    local prepared = {
        key = policy.key,
        label = policy.label,
        rewardStore = policy.rewardStore,
        defaultKey = countControl.default or "",
        defaultStorageKey = "",
        values = {},
        valuesByMaxCageRewards = {},
        labels = {},
        optionsByKey = {},
        rewardContext = {
            kind = "fieldsCages",
            rewardStore = policy.rewardStore or "RunProgress",
        },
        maxCageRewardCount = math.floor(tonumber(countControl.max) or 0),
    }

    for _, option in ipairs(countControl.options or {}) do
        local storageKey = variantStorageKey(prepared, option)
        local choice = {
            key = storageKey,
            sourceKey = option.key,
            label = option.label or option.key,
            cageRewardCount = option.cageRewardCount,
            requiresAllOfferedRoomsSupport = option.requiresAllOfferedRoomsSupport,
        }
        prepared.values[#prepared.values + 1] = storageKey
        prepared.labels[storageKey] = choice.label
        prepared.optionsByKey[storageKey] = choice
        if option.cageRewardCount ~= nil and option.cageRewardCount > prepared.maxCageRewardCount then
            prepared.maxCageRewardCount = option.cageRewardCount
        end
    end

    prepared.rewardContext.sourceCount = prepared.maxCageRewardCount

    return prepared
end

local function isCageChoiceValidForMax(choice, maxCageRewards)
    local count = choice and math.floor(tonumber(choice.cageRewardCount) or 0) or 0
    if count <= 0 then
        return true
    end
    if maxCageRewards == nil then
        return false
    end
    return count <= maxCageRewards
end

local function prepareCagePolicyValueLists(policy)
    for maxCageRewards = 0, policy.maxCageRewardCount do
        local values = {}
        for _, key in ipairs(policy.values or {}) do
            if isCageChoiceValidForMax(policy.optionsByKey[key], maxCageRewards) then
                values[#values + 1] = key
            end
        end
        policy.valuesByMaxCageRewards[maxCageRewards] = values
    end
end

local function prepareCagePolicies(instance)
    instance.cagePoliciesByKey = {}

    local policy = prepareCagePolicy(instance.biome.fields and instance.biome.fields.cageRewardPolicy or nil)
    if policy ~= nil then
        prepareCagePolicyValueLists(policy)
        instance.cagePoliciesByKey[policy.key] = policy
    end
end

local function prepareSiblingStructurePolicy(instance)
    local topology = instance.biome.fields
        and instance.biome.fields.roomTopology
        or nil
    instance.siblingStructurePolicy = roomTopology.prepareSiblingPolicy(topology, {
        namespace = "fields",
    })
end

local function cagePolicyForRole(instance, role)
    if role == nil or role.cageRewardPolicy == nil then
        return nil
    end
    return instance.cagePoliciesByKey and instance.cagePoliciesByKey[role.cageRewardPolicy] or nil
end

local function prepareCageRewardContexts(instance)
    for _, role in ipairs(instance.roles or {}) do
        local policy = cagePolicyForRole(instance, role)
        if policy ~= nil and role.reward ~= nil then
            role.reward = shallowCopyMap(role.reward)
            role.reward.sourceCount = policy.maxCageRewardCount
        end
    end
end

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

local function rowRoomKey(instance, rows, rowIndex)
    return data.rowRoomKey(instance, rows, rowIndex)
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

local function siblingPolicyContext(instance, rows, rowIndex)
    return {
        rowIndex = rowIndex,
        routeRowCount = instance.routeRowCount,
        rowContext = data.rowContext(instance, rows, rowIndex),
        selectedRoomKey = rowRoomKey(instance, rows, rowIndex),
        roomKeyAt = function(index)
            return rowRoomKey(instance, rows, index)
        end,
        siblingRoomKeyAt = function(index)
            return siblingCandidateRoomKey(instance, rows, index)
        end,
        extraRuleStatus = function(sibling)
            return topologyRulesStatus(instance, rows, rowIndex, sibling)
        end,
    }
end

local function maxCageRewardCount(instance)
    local count = 0
    for _, policy in pairs(instance.cagePoliciesByKey or {}) do
        if (policy.maxCageRewardCount or 0) > count then
            count = policy.maxCageRewardCount
        end
    end
    return count
end

local function selectedCombatOption(instance, rows, rowIndex, roleKey)
    if roleKey ~= "Combat" then
        return nil
    end
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return option
end

local function isCageCountValidForOption(choice, option)
    local count = choice and math.floor(tonumber(choice.cageRewardCount) or 0) or 0
    if count <= 0 then
        return true
    end
    if option == nil then
        return false
    end
    return count <= math.floor(tonumber(option.maxCageRewards) or 0)
end

local adapter = {
    slotForRow = slotForRow,
    isFixedIdentitySlot = isFixedSlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
        if isFixedSlot(slot) then
            return slot.roleKey
        end
        return defaultReadRoleKey(instance, rows, rowIndex, slot)
    end,

    roleForRow = function(instance, rowIndex, roleKey, slot, defaultRoleForRow)
        if isFixedSlot(slot) then
            if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
                return slot.role
            end
            return nil
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(_, _, _, roleKey, slot)
        if isFixedSlot(slot) then
            return roleKey == slot.roleKey
        end
        return nil
    end,

    fillRoleValuesForSlot = function(_, _, _, slot, values)
        if isFixedSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        return false
    end,

    validateSlot = function(instance, rows, rowIndex, roleKey, role, slot)
        if isFixedSlot(slot) then
            return validStatus()
        end

        local policy = cagePolicyForRole(instance, role)
        if policy == nil then
            return nil
        end

        local cageCountKey = rows:read(rowIndex, "VariantKey") or ""
        local choice = policy.optionsByKey[cageCountKey]
        if choice == nil and cageCountKey == "" then
            return nil
        end
        if choice == nil then
            return invalidStatus("unknown_cage_count", "Unknown cage reward count: " .. tostring(cageCountKey))
        end
        local option = selectedCombatOption(instance, rows, rowIndex, roleKey)
        if option == nil and (rows:read(rowIndex, "OptionKey") or "") ~= "" then
            return nil
        end
        if not isCageCountValidForOption(choice, option) then
            if option == nil then
                return invalidStatus("cage_count_requires_map", "Forced cage rewards require a combat map")
            end
            return invalidStatus(
                "cage_count_exceeds_map",
                tostring(choice.label or cageCountKey) .. " exceeds " .. tostring(option.label or option.key)
            )
        end
        return nil
    end,

    optionUnavailableMessage = function(_, _, _, _, role)
        return tostring(role.label or role.key) .. " is not valid at this pick"
    end,
}

data = rowEngine.create(adapter)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)
    prepareCagePolicies(instance)
    prepareSiblingStructurePolicy(instance)
    prepareCageRewardContexts(instance)

    buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    instance.maxCageRewardCount = maxCageRewardCount(instance)
    data.buildRoleChoices(instance)
    addFixedRoleLabels(instance)
    data.prepareSlots(instance)
    return instance
end

function data.cagePolicyForRole(instance, roleKey)
    return cagePolicyForRole(instance, instance.rolesByKey and instance.rolesByKey[roleKey] or nil)
end

function data.cageCountLabelsForRole(instance, roleKey)
    local policy = data.cagePolicyForRole(instance, roleKey)
    return policy and policy.labels or {}
end

function data.cageCountValuesForRow(instance, rows, rowIndex, roleKey)
    local policy = data.cagePolicyForRole(instance, roleKey)
    if policy == nil then
        return EMPTY_VALUES
    end

    local option = selectedCombatOption(instance, rows, rowIndex, roleKey)
    local maxCageRewards = option and math.floor(tonumber(option.maxCageRewards) or 0) or 0
    if maxCageRewards > policy.maxCageRewardCount then
        maxCageRewards = policy.maxCageRewardCount
    end
    return policy.valuesByMaxCageRewards[maxCageRewards] or policy.valuesByMaxCageRewards[0] or EMPTY_VALUES
end

function data.resolveCageCount(instance, rows, rowIndex, roleKey)
    local policy = data.cagePolicyForRole(instance, roleKey)
    if policy == nil then
        return "", nil
    end

    local cageCountKey = rows and rows:read(rowIndex, "VariantKey") or ""
    cageCountKey = cageCountKey or ""
    if cageCountKey == "" and policy.optionsByKey[cageCountKey] == nil then
        local values = data.cageCountValuesForRow(instance, rows, rowIndex, roleKey)
        if values[1] ~= nil and values[2] == nil then
            cageCountKey = values[1]
        end
    end
    return cageCountKey, policy.optionsByKey[cageCountKey]
end

function data.siblingStructureAlias(instance)
    local policy = instance.siblingStructurePolicy
    return policy and policy.alias or "SiblingStructureKey"
end

function data.siblingStructureLabels(instance)
    local policy = instance.siblingStructurePolicy
    return policy and policy.labels or EMPTY_LABELS
end

function data.siblingStructureValues(instance)
    local policy = instance.siblingStructurePolicy
    return policy and policy.values or EMPTY_VALUES
end

function data.siblingStructureStatus(instance, rows, rowIndex)
    local policy = instance.siblingStructurePolicy
    if policy == nil then
        return validStatus()
    end
    return roomTopology.siblingWindowStatus(policy, data.rowContext(instance, rows, rowIndex))
end

function data.shouldDrawSiblingStructure(instance, rows, rowIndex)
    local status = data.siblingStructureStatus(instance, rows, rowIndex)
    if not status.valid then
        return false
    end
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    return roleKey == "Combat" or roleKey == "Miniboss" or roleKey == "Bridge"
end

function data.resolveSiblingStructure(instance, rows, rowIndex)
    local policy = instance.siblingStructurePolicy
    if policy == nil then
        return "", nil
    end

    local key = rows and rows:read(rowIndex, policy.alias) or ""
    key = key or ""
    return key, policy.optionsByKey[key]
end

local function siblingAvailabilityStatus(instance, rows, rowIndex, sibling)
    return roomTopology.siblingCandidateStatus(
        instance.siblingStructurePolicy,
        siblingPolicyContext(instance, rows, rowIndex),
        sibling
    )
end

local function isSiblingTopologyStatus(instance, status)
    return roomTopology.isSiblingTopologyStatus(instance.siblingStructurePolicy, status)
end

local function fillSiblingStructureValueStates(instance, rows, rowIndex, states)
    return roomTopology.fillSiblingValueStates(
        instance.siblingStructurePolicy,
        siblingPolicyContext(instance, rows, rowIndex),
        states
    )
end

function data.siblingStructureValueStatesForRow(instance, rows, rowIndex)
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

function data.validateRoomTopology(instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    if data.isFixedIdentityRow(instance, rowIndex) then
        return nil
    end

    local structureStatus = data.siblingStructureStatus(instance, rows, rowIndex)
    if not structureStatus.valid then
        return nil
    end

    if roleKey == "Vanilla" then
        local forcedStatus = roomTopology.forcedGroupsStatus(
            instance.siblingStructurePolicy,
            siblingPolicyContext(instance, rows, rowIndex)
        )
        if not forcedStatus.valid then
            return forcedStatus
        end
        return nil
    end
    if roleKey ~= "Combat" and roleKey ~= "Miniboss" and roleKey ~= "Bridge" then
        return nil
    end

    local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
    if roleKey == "Combat" and (cageCount == nil or (cageCount.cageRewardCount or 0) <= 0) then
        return invalidStatus("fields_cage_count_required", "Fields topology needs picked cage reward count")
    end

    local siblingKey, sibling = data.resolveSiblingStructure(instance, rows, rowIndex)
    if sibling == nil or siblingKey == "" then
        return invalidStatus("fields_sibling_structure_required", "Fields topology needs sibling door structure")
    end
    local siblingStatus = siblingAvailabilityStatus(instance, rows, rowIndex, sibling)
    if not siblingStatus.valid then
        if isSiblingTopologyStatus(instance, siblingStatus) then
            return siblingStatus
        end
        return invalidStatus(
            "fields_sibling_structure_unavailable",
            "Sibling " .. tostring(sibling.label or siblingKey) .. " is not valid at this pick"
        )
    end
    return nil
end

function data.roomTopology(instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    if roleKey == "Vanilla" or data.isFixedIdentityRow(instance, rowIndex) then
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

function data.maxCageRewardCount(instance)
    return instance.maxCageRewardCount or 0
end

function data.cageRewardCountForRow(instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, choice = data.resolveCageCount(instance, rows, rowIndex, roleKey)
    if choice == nil then
        return 0
    end
    if not isCageCountValidForOption(choice, selectedCombatOption(instance, rows, rowIndex, roleKey)) then
        return 0
    end
    return math.floor(tonumber(choice.cageRewardCount) or 0)
end

function data.storage(instance)
    local roomRows = data.buildRoomRows()
    roomRows[#roomRows + 1] = {
        key = data.siblingStructureAlias(instance),
        type = "string",
        default = "",
        maxLen = 32,
    }
    return {
        {
            key = "Rooms",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = roomRows,
        },
        {
            key = "Rewards",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = data.buildRewardRows(),
        },
    }
end

return data
