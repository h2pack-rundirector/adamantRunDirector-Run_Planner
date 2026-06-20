local deps = ...
local common = deps.common
local timeline = deps.timeline
local rowEngine = deps.rowEngine

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local buildOptionChoices = common.buildOptionChoices
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
local fixedBiomeDepthCacheCost = common.fixedBiomeDepthCacheCost
local routeBiomeDepthCacheCost = common.routeBiomeDepthCacheCost
local routeStartOrdinal = common.routeStartOrdinal
local routeEndOrdinal = common.routeEndOrdinal
local routeRowLabel = common.routeRowLabel
local applySlotDepthContext = common.applySlotDepthContext

local data
local EMPTY_VALUES = {}

local function slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function isFixedSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function isPickSlot(slot)
    return slot ~= nil and slot.kind == "biomeRow"
end

local function buildFixedSlot(instance, entry, section)
    local roomOptions = shallowCopyList(entry.roomOptions)
    local role = {
        key = entry.key,
        label = entry.label or entry.key,
        roomKey = entry.roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = entry.reward,
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
        roomKey = entry.roomKey,
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
        rewardLegs = {},
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

    for index = 1, prepared.maxCageRewardCount do
        prepared.rewardLegs[index] = {
            key = "Cage" .. tostring(index),
            label = "Cage " .. tostring(index),
            reward = prepared.rewardContext,
        }
    end

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

local function cagePolicyForRole(instance, role)
    if role == nil or role.cageRewardPolicy == nil then
        return nil
    end
    return instance.cagePoliciesByKey and instance.cagePoliciesByKey[role.cageRewardPolicy] or nil
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

local function prepareCageRewardRows(instance)
    instance.maxCageRewardCount = maxCageRewardCount(instance)
    instance.cageRewardRowOffsetByRouteRow = {}

    local rowCount = 0
    for _, slot in ipairs(instance.routeSlots or {}) do
        if isPickSlot(slot) then
            instance.cageRewardRowOffsetByRouteRow[slot.rowIndex] = rowCount
            rowCount = rowCount + instance.maxCageRewardCount
        end
    end
    instance.cageRewardRowCount = rowCount
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

    buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    prepareCageRewardRows(instance)
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
    return cageCountKey, policy.optionsByKey[cageCountKey]
end

function data.maxCageRewardCount(instance)
    return instance.maxCageRewardCount or 0
end

function data.cageRewardRowIndex(instance, rowIndex, cageIndex)
    local offset = instance.cageRewardRowOffsetByRouteRow
        and instance.cageRewardRowOffsetByRouteRow[math.floor(tonumber(rowIndex) or 0)]
        or nil
    cageIndex = math.floor(tonumber(cageIndex) or 0)
    if offset == nil or cageIndex < 1 or cageIndex > data.maxCageRewardCount(instance) then
        return nil
    end
    return offset + cageIndex
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

function data.cageRewardLegForRow(instance, rows, rowIndex, cageIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local policy = data.cagePolicyForRole(instance, roleKey)
    if policy == nil then
        return nil
    end

    cageIndex = math.floor(tonumber(cageIndex) or 0)
    if cageIndex < 1 or cageIndex > data.cageRewardCountForRow(instance, rows, rowIndex) then
        return nil
    end
    return policy.rewardLegs and policy.rewardLegs[cageIndex] or nil
end

function data.storage(instance)
    return {
        {
            key = "Rooms",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = data.buildRoomRows(),
        },
        {
            key = "Rewards",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = data.buildRewardRows(),
        },
        {
            key = "CageRewards",
            type = "table",
            minRows = instance.cageRewardRowCount,
            defaultRows = instance.cageRewardRowCount,
            maxRows = instance.cageRewardRowCount,
            row = data.buildRewardRows(),
        },
    }
end

return data
