local deps = ...
local common = deps.common
local readCache = deps.readCache
local timeline = deps.timeline
local rowEngine = deps.rowEngine
local roomTopology = deps.roomTopology
local roomStructure = deps.roomStructure

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
local fixedRoomKey = common.fixedRoomKey
local fixedRoomField = common.fixedRoomField
local fixedRoomFeatures = common.fixedRoomFeatures
local activeReadCache = readCache.active
local nestedRecord = readCache.nestedRecord

local data
local EMPTY_VALUES = {}
local EMPTY_LABELS = {}

local function slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function isPrebossSlot(slot)
    return slot ~= nil and slot.kind == "preboss"
end

local function isFixedRoleSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function isFixedIdentitySlot(slot)
    return isPrebossSlot(slot) or isFixedRoleSlot(slot)
end

local function buildFixedRoleSlot(instance, ordinal, special)
    local kind = special.kind
    local roomOptions = shallowCopyList(special.roomOptions)
    local roomKey = fixedRoomKey(special)
    local features = fixedRoomFeatures(special)
    local role = {
        key = special.key or kind,
        label = special.label or special.key or kind,
        roomKey = roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = special.reward,
        features = features,
        exitCount = fixedRoomField(special, "exitCount"),
        rewardExitCount = fixedRoomField(special, "rewardExitCount"),
        biomeDepthCacheCost = special.biomeDepthCacheCost,
        biomeEncounterDepthCost = special.biomeEncounterDepthCost,
    }
    buildOptionChoices(role)

    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = ordinal,
        kind = kind,
        isBiomeEntry = special.isBiomeEntry == true,
        label = special.label or role.label,
        roomKey = roomKey,
        exitCount = role.exitCount,
        rewardExitCount = role.rewardExitCount,
        roomOfferCount = special.roomOfferCount or common.rewardOfferCount(special.reward),
        roleKey = role.key,
        role = role,
        features = features,
    }, {
        biomeDepthCache = special.biomeDepthCache,
        biomeDepthCacheCost = fixedBiomeDepthCacheCost(instance.biome.slotLayout, special),
        biomeEncounterDepthCost = special.biomeEncounterDepthCost,
    })
end

local function buildEntrySlot(instance, entry)
    if entry == nil then
        return
    end

    buildFixedRoleSlot(instance, entry.routeOrdinal or 0, {
        kind = entry.kind or "intro",
        key = entry.key or "Intro",
        label = entry.label or "Intro",
        room = entry.room,
        roomKey = entry.roomKey,
        roomOptions = entry.roomOptions,
        reward = entry.reward,
        features = entry.features,
        exitCount = entry.exitCount,
        rewardExitCount = entry.rewardExitCount,
        isBiomeEntry = entry.isBiomeEntry == true,
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
        locked = entry.locked,
    })
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startOrdinal = routeStartOrdinal(slotLayout)
    local endOrdinal = routeEndOrdinal(slotLayout, startOrdinal)

    instance.routeSlots = {}
    buildEntrySlot(instance, slotLayout.entry)

    local fixedOrdinals = {}
    for ordinal, slot in pairs(slotLayout.special or {}) do
        if slot.kind == "opening" then
            fixedOrdinals[#fixedOrdinals + 1] = math.floor(tonumber(ordinal) or 0)
        end
    end
    table.sort(fixedOrdinals)
    for _, ordinal in ipairs(fixedOrdinals) do
        buildFixedRoleSlot(instance, ordinal, slotLayout.special[ordinal])
    end

    for ordinal = startOrdinal, endOrdinal do
        local rowIndex = #instance.routeSlots + 1
        instance.routeSlots[rowIndex] = applySlotDepthContext({
            rowIndex = rowIndex,
            routeOrdinal = ordinal,
            kind = "biomeRow",
            label = routeRowLabel(slotLayout, ordinal, "Depth"),
        }, {
            biomeDepthCacheCost = routeBiomeDepthCacheCost(slotLayout),
        })
    end

    local specialOrdinals = {}
    for ordinal, slot in pairs(slotLayout.special or {}) do
        if slot.kind == "preboss" then
            specialOrdinals[#specialOrdinals + 1] = math.floor(tonumber(ordinal) or 0)
        end
    end
    table.sort(specialOrdinals)
    for _, ordinal in ipairs(specialOrdinals) do
        buildFixedRoleSlot(instance, ordinal, slotLayout.special[ordinal])
    end
    instance.routeRowCount = #instance.routeSlots
end

local function prepareSiblingStructurePolicy(instance)
    instance.siblingStructurePolicy = roomTopology.prepareSiblingPolicy(instance.biome.roomTopology, {
        namespace = "fixed",
    })
end

local function indexedSiblingStructureAlias(baseAlias, siblingIndex)
    siblingIndex = math.floor(tonumber(siblingIndex) or 1)
    if siblingIndex <= 1 then
        return baseAlias
    end
    local prefix = string.match(baseAlias or "", "^(.*)Key$")
    return (prefix or tostring(baseAlias or "SiblingStructure")) .. tostring(siblingIndex) .. "Key"
end

local function maxRewardExitCountForRole(role)
    local maxCount = math.floor(tonumber(roomStructure.rewardExitCount(nil, role)) or 0)
    for _, option in ipairs(data.optionListForRole(role)) do
        local count = math.floor(tonumber(roomStructure.rewardExitCount(nil, role, option)) or 0)
        if count > maxCount then
            maxCount = count
        end
    end
    return maxCount
end

local function prepareSiblingStructureCount(instance)
    if instance.siblingStructurePolicy == nil then
        instance.maxSiblingStructureCount = 0
        return
    end

    local maxRewardExitCount = 0
    for _, role in ipairs(instance.roles or EMPTY_VALUES) do
        local roleMax = maxRewardExitCountForRole(role)
        if roleMax > maxRewardExitCount then
            maxRewardExitCount = roleMax
        end
    end
    instance.maxSiblingStructureCount = math.max(maxRewardExitCount - 1, 0)
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

local function selectedRoomTopologyForRow(instance, rows, rowIndex)
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

local function siblingCandidateRoomKey(instance, rows, rowIndex, siblingIndex)
    local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
    return roomTopology.roomKey(sibling)
end

local function rowRoomKey(instance, rows, rowIndex)
    return data.rowRoomKey(instance, rows, rowIndex)
end

local function selectedRewardStoreForRow(instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    if roleKey == "Combat" or roleKey == "Fountain" then
        return rewardStoreForMajorMinorChoice(rows, rowIndex)
    elseif roleKey == "Miniboss" then
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        return option and "RunProgress" or nil
    end
    return nil
end

local function siblingRewardStoreForRow(instance, rows, rowIndex, siblingIndex)
    local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
    return sibling and sibling.rewardStore or nil
end

local function structuralCountForRow(instance, rows, rowIndex, field)
    local slot = slotForRow(instance, rowIndex)
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

    local selectedStore = selectedRewardStoreForRow(instance, rows, rowIndex)
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
    return {
        rowIndex = rowIndex,
        routeRowCount = instance.routeRowCount,
        candidateSiblingIndex = siblingIndex,
        rowContext = data.rowContext(instance, rows, rowIndex),
        selectedRoomKey = rowRoomKey(instance, rows, rowIndex),
        roomKeyAt = function(index)
            return rowRoomKey(instance, rows, index)
        end,
        siblingCountAt = function(index)
            return data.activeSiblingStructureCount(instance, rows, index)
        end,
        siblingRoomKeyAt = function(index, currentSiblingIndex)
            return siblingCandidateRoomKey(instance, rows, index, currentSiblingIndex)
        end,
        generatedExitCountAt = function(index, group)
            return structuralCountForRow(instance, rows, index, group and group.generatedExitCountField)
        end,
        extraRuleStatus = function(sibling)
            return topologyRulesStatus(instance, rows, rowIndex, siblingIndex, sibling)
        end,
    }
end

local adapter = {
    slotForRow = slotForRow,
    isFixedIdentitySlot = isFixedIdentitySlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
        if isFixedRoleSlot(slot) then
            return slot.roleKey
        end
        return defaultReadRoleKey(instance, rows, rowIndex, slot)
    end,

    roleForRow = function(instance, rowIndex, roleKey, slot, defaultRoleForRow)
        if isFixedRoleSlot(slot) then
            if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
                return slot.role
            end
            return nil
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(_, _, _, roleKey, slot)
        if isFixedRoleSlot(slot) then
            return roleKey == slot.roleKey
        end
        return nil
    end,

    fillRoleValuesForSlot = function(_, _, _, slot, values)
        if isFixedRoleSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        return false
    end,

    skipOptionsForSlot = function(_, _, _, slot)
        return isPrebossSlot(slot)
    end,

    validateSlot = function(_, _, _, _, _, slot)
        if isPrebossSlot(slot) then
            return validStatus()
        end
        return nil
    end,

    optionUnavailableMessage = function(_, _, _, _, role)
        return tostring(role.label or role.key) .. " is not valid at this depth"
    end,
}

data = rowEngine.create(adapter)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)

    buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    data.buildRoleChoices(instance)
    data.prepareSlots(instance)
    prepareSiblingStructurePolicy(instance)
    prepareSiblingStructureCount(instance)
    return instance
end

function data.storage(instance)
    local roomRows = data.buildRoomRows()
    if instance.siblingStructurePolicy ~= nil then
        for siblingIndex = 1, data.maxSiblingStructureCount(instance) do
            roomRows[#roomRows + 1] = {
                key = data.siblingStructureAlias(instance, siblingIndex),
                type = "string",
                default = "",
                maxLen = 32,
            }
        end
    end
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

function data.maxSiblingStructureCount(instance)
    return instance.maxSiblingStructureCount or 0
end

function data.siblingStructureAlias(instance, siblingIndex)
    local policy = instance.siblingStructurePolicy
    return indexedSiblingStructureAlias(policy and policy.alias or "SiblingStructureKey", siblingIndex)
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

function data.activeSiblingStructureCount(instance, rows, rowIndex)
    if instance.siblingStructurePolicy == nil or data.isFixedIdentityRow(instance, rowIndex) then
        return 0
    end
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    if not hasSelectableSiblingStructure(roleKey, option) then
        return 0
    end

    local slot = slotForRow(instance, rowIndex)
    local _, role = data.resolveRole(instance, rows, rowIndex)
    local rewardExitCount = math.floor(tonumber(roomStructure.rewardExitCount(slot, role, option)) or 0)
    local count = math.max(rewardExitCount - 1, 0)
    local maxCount = data.maxSiblingStructureCount(instance)
    if count > maxCount then
        return maxCount
    end
    return count
end

function data.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
    if data.activeSiblingStructureCount(instance, rows, rowIndex) < (siblingIndex or 1) then
        return false
    end
    if not data.siblingStructureStatus(instance, rows, rowIndex).valid then
        return false
    end
    return true
end

function data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
    local policy = instance.siblingStructurePolicy
    if policy == nil then
        return "", nil
    end

    local key = rows and rows:read(rowIndex, data.siblingStructureAlias(instance, siblingIndex)) or ""
    key = key or ""
    return key, policy.optionsByKey[key]
end

local function siblingAvailabilityStatus(instance, rows, rowIndex, siblingIndex, sibling)
    return roomTopology.siblingCandidateStatus(
        instance.siblingStructurePolicy,
        siblingPolicyContext(instance, rows, rowIndex, siblingIndex),
        sibling
    )
end

local function isSiblingTopologyStatus(instance, status)
    return roomTopology.isSiblingTopologyStatus(instance.siblingStructurePolicy, status)
end

local function fillSiblingStructureValueStates(instance, rows, rowIndex, siblingIndex, states)
    return roomTopology.fillSiblingValueStates(
        instance.siblingStructurePolicy,
        siblingPolicyContext(instance, rows, rowIndex, siblingIndex),
        states
    )
end

function data.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
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

function data.validateRoomTopology(instance, rows, rowIndex)
    if data.siblingStructureStatus(instance, rows, rowIndex).valid ~= true then
        return nil
    end

    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    if not hasSelectableSiblingStructure(roleKey, option) then
        return nil
    end

    local count = data.activeSiblingStructureCount(instance, rows, rowIndex)
    for siblingIndex = 1, count do
        local siblingKey, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        if sibling == nil or siblingKey == "" then
            return invalidStatus("fixed_sibling_structure_required", "Topology needs sibling door structure")
        end

        local siblingStatus = siblingAvailabilityStatus(instance, rows, rowIndex, siblingIndex, sibling)
        if not siblingStatus.valid then
            if isSiblingTopologyStatus(instance, siblingStatus) then
                return siblingStatus
            end
            return invalidStatus(
                "fixed_sibling_structure_unavailable",
                "Sibling " .. tostring(sibling.label or siblingKey) .. " is not valid at this depth"
            )
        end
    end

    local forcedStatus = roomTopology.forcedGroupsStatus(
        instance.siblingStructurePolicy,
        siblingPolicyContext(instance, rows, rowIndex)
    )
    if not forcedStatus.valid then
        return forcedStatus
    end
    return nil
end

function data.roomTopology(instance, rows, rowIndex)
    if instance.siblingStructurePolicy == nil
        or data.isFixedIdentityRow(instance, rowIndex)
        or not data.siblingStructureStatus(instance, rows, rowIndex).valid
    then
        return nil
    end

    local selected = selectedRoomTopologyForRow(instance, rows, rowIndex)
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

return data
