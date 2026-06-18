local deps = ...
local common = deps.common
local availability = deps.availability
local timeline = deps.timeline
local rowEngine = deps.rowEngine

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local addChoice = common.addChoice
local buildOptionChoices = common.buildOptionChoices
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
local slotDepth = availability.slotDepth
local isInRange = availability.isInRange

local data

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

local function firstBranchKey(slot)
    return slot and (slot.branchKey or (slot.branchValues and slot.branchValues[1])) or ""
end

local function buildFixedRoleSlot(instance, depth, special)
    local roomOptions = shallowCopyList(special.roomOptions)
    local role = {
        key = special.key or special.kind,
        label = special.label or special.key or special.kind,
        roomKey = special.roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = special.reward,
    }
    buildOptionChoices(role)

    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = {
        rowIndex = rowIndex,
        coordinate = depth,
        kind = special.kind,
        label = special.label or role.label,
        roomKey = special.roomKey,
        roleKey = role.key,
        role = role,
    }
end

local function buildEntrySlot(instance, entry)
    if entry == nil then
        return
    end

    buildFixedRoleSlot(instance, entry.coordinate or 0, {
        kind = entry.kind or "intro",
        key = entry.key or "Intro",
        label = entry.label or "Intro",
        roomKey = entry.roomKey,
        roomOptions = entry.roomOptions,
        reward = entry.reward,
        locked = entry.locked,
    })
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startDepth = math.floor(tonumber(slotLayout.routeStartDepth) or 1)
    local endDepth = math.floor(tonumber(slotLayout.routeEndDepth) or startDepth)
    if endDepth < startDepth then
        endDepth = startDepth
    end

    instance.routeSlots = {}
    buildEntrySlot(instance, slotLayout.entry)

    local fixedDepths = {}
    for depth, slot in pairs(slotLayout.special or {}) do
        if slot.kind == "opening" then
            fixedDepths[#fixedDepths + 1] = math.floor(tonumber(depth) or 0)
        end
    end
    table.sort(fixedDepths)
    for _, depth in ipairs(fixedDepths) do
        buildFixedRoleSlot(instance, depth, slotLayout.special[depth])
    end

    for depth = startDepth, endDepth do
        local rowIndex = #instance.routeSlots + 1
        instance.routeSlots[rowIndex] = {
            rowIndex = rowIndex,
            coordinate = depth,
            kind = "route",
            label = "Depth " .. tostring(depth),
        }
    end

    local specialDepths = {}
    for depth, slot in pairs(slotLayout.special or {}) do
        if slot.kind == "preboss" then
            specialDepths[#specialDepths + 1] = math.floor(tonumber(depth) or 0)
        end
    end
    table.sort(specialDepths)
    for _, depth in ipairs(specialDepths) do
        local special = slotLayout.special[depth]
        for _, branch in ipairs(special.branches or {}) do
            local branches = { branch }
            local rowIndex = #instance.routeSlots + 1
            local slot = {
                rowIndex = rowIndex,
                coordinate = depth,
                kind = "preboss",
                label = branch.label or special.label or ("Depth " .. tostring(depth) .. " Preboss"),
                roomKey = special.roomKey,
                branchKey = branch.key,
                branch = branch,
                branches = branches,
                branchesByKey = buildLookup(branches),
                branchValues = {},
                branchLabels = {},
            }
            addChoice(slot.branchValues, slot.branchLabels, branch.key, branch.label)
            instance.routeSlots[rowIndex] = slot
        end
    end
    instance.routeRowCount = #instance.routeSlots
end

local function addBranchLabels(instance)
    for _, slot in ipairs(instance.routeSlots or {}) do
        for _, branch in ipairs(slot.branches or {}) do
            instance.roleLabels[branch.key] = branch.label or branch.key
        end
    end
end

local function variantStorageKey(policy, option)
    if option.key == policy.defaultKey then
        return ""
    end
    return option.key
end

local function prepareEncounterPolicy(policy)
    if policy == nil or policy.countControl == nil then
        return nil
    end

    local countControl = policy.countControl
    local prepared = {
        key = policy.key,
        label = policy.label,
        defaultKey = countControl.default or "",
        values = {},
        labels = {},
        optionsByKey = {},
        rewardLegs = {},
    }

    for _, option in ipairs(countControl.options or {}) do
        local storageKey = variantStorageKey(prepared, option)
        local choice = {
            key = storageKey,
            sourceKey = option.key,
            label = option.label or option.key,
            realCombatCount = option.realCombatCount,
            availableAtBiomeEncounterDepth = option.availableAtBiomeEncounterDepth,
        }
        prepared.values[#prepared.values + 1] = storageKey
        prepared.labels[storageKey] = choice.label
        prepared.optionsByKey[storageKey] = choice
    end
    for _, leg in ipairs(policy.legs or {}) do
        if leg.hasReward then
            prepared.rewardLegs[#prepared.rewardLegs + 1] = {
                key = leg.key,
                label = leg.label or leg.key,
                reward = leg.reward,
            }
        end
    end

    return prepared
end

local function prepareEncounterPolicies(instance)
    instance.encounterPoliciesByKey = {}

    local policy = prepareEncounterPolicy(instance.biome.combatEncounterPolicy)
    if policy ~= nil then
        instance.encounterPoliciesByKey[policy.key] = policy
    end
end

local function encounterPolicyForRole(instance, role)
    if role == nil or role.encounterPolicy == nil then
        return nil
    end
    return instance.encounterPoliciesByKey and instance.encounterPoliciesByKey[role.encounterPolicy] or nil
end

local function isVariantAvailableAtSlot(variant, slot)
    if variant == nil then
        return false
    end
    local depth = slotDepth(slot)
    return isInRange(depth, variant.availableAtBiomeEncounterDepth)
end

local function buildVariantChoices(instance)
    instance.variantValuesByRowRole = {}
    for _, slot in ipairs(instance.routeSlots or {}) do
        local valuesByRole = {}
        for _, role in ipairs(instance.roles or {}) do
            local policy = encounterPolicyForRole(instance, role)
            if policy ~= nil then
                local values = {}
                for _, variantKey in ipairs(policy.values or {}) do
                    local variant = policy.optionsByKey[variantKey]
                    if isVariantAvailableAtSlot(variant, slot) then
                        values[#values + 1] = variantKey
                    end
                end
                valuesByRole[role.key] = values
            end
        end
        instance.variantValuesByRowRole[slot.rowIndex] = valuesByRole
    end
end

local function maxEncounterRewardLegCount(instance)
    local count = 0
    for _, policy in pairs(instance.encounterPoliciesByKey or {}) do
        if #(policy.rewardLegs or {}) > count then
            count = #policy.rewardLegs
        end
    end
    return count
end

local function prepareEncounterRewardRows(instance)
    instance.maxEncounterRewardLegCount = maxEncounterRewardLegCount(instance)
    instance.encounterRewardRowOffsetByRouteRow = {}

    local rowCount = 0
    for _, slot in ipairs(instance.routeSlots or {}) do
        if slot.kind == "route" then
            instance.encounterRewardRowOffsetByRouteRow[slot.rowIndex] = rowCount
            rowCount = rowCount + instance.maxEncounterRewardLegCount
        end
    end
    instance.encounterRewardRowCount = rowCount
end

local adapter = {
    slotForRow = slotForRow,
    isFixedIdentitySlot = isFixedIdentitySlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
        if isFixedRoleSlot(slot) then
            return slot.roleKey
        end
        if isPrebossSlot(slot) then
            return firstBranchKey(slot)
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
        if isPrebossSlot(slot) then
            return slot.branchesByKey[roleKey]
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(_, _, _, roleKey, slot)
        if isFixedRoleSlot(slot) then
            return roleKey == slot.roleKey
        end
        if isPrebossSlot(slot) then
            return slot.branchesByKey[roleKey] ~= nil
        end
        return nil
    end,

    fillRoleValuesForSlot = function(_, _, _, slot, values)
        if isFixedRoleSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        if isPrebossSlot(slot) then
            for _, branchKey in ipairs(slot.branchValues or {}) do
                values[#values + 1] = branchKey
            end
            return true
        end
        return false
    end,

    skipOptionsForSlot = function(_, _, _, slot)
        return isPrebossSlot(slot)
    end,

    validateSlot = function(instance, rows, rowIndex, _, role, slot)
        if isPrebossSlot(slot) then
            return validStatus()
        end

        local policy = encounterPolicyForRole(instance, role)
        if policy == nil then
            return nil
        end

        local variantKey = rows:read(rowIndex, "VariantKey") or ""
        local variant = policy.optionsByKey[variantKey]
        if variant == nil then
            return invalidStatus("unknown_variant", "Unknown encounter count: " .. tostring(variantKey))
        end
        if not isVariantAvailableAtSlot(variant, slot) then
            return invalidStatus(
                "variant_unavailable",
                tostring(variant.label or variantKey) .. " is not valid at this depth"
            )
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
    prepareEncounterPolicies(instance)

    buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    buildVariantChoices(instance)
    prepareEncounterRewardRows(instance)
    data.buildRoleChoices(instance)
    addBranchLabels(instance)
    data.prepareSlots(instance)
    return instance
end

function data.variantPolicyForRole(instance, roleKey)
    return encounterPolicyForRole(instance, instance.rolesByKey and instance.rolesByKey[roleKey] or nil)
end

function data.variantLabelsForRow(instance, roleKey)
    local policy = data.variantPolicyForRole(instance, roleKey)
    return policy and policy.labels or {}
end

function data.variantValuesForRow(instance, rowIndex, roleKey)
    return instance.variantValuesByRowRole
        and instance.variantValuesByRowRole[rowIndex]
        and instance.variantValuesByRowRole[rowIndex][roleKey]
        or {}
end

function data.resolveVariant(instance, rows, rowIndex, roleKey)
    local policy = data.variantPolicyForRole(instance, roleKey)
    if policy == nil then
        return "", nil
    end

    local variantKey = rows and rows:read(rowIndex, "VariantKey") or ""
    variantKey = variantKey or ""
    return variantKey, policy.optionsByKey[variantKey]
end

function data.maxEncounterRewardLegCount(instance)
    return instance.maxEncounterRewardLegCount or 0
end

function data.encounterRewardRowIndex(instance, rowIndex, legIndex)
    local offset = instance.encounterRewardRowOffsetByRouteRow
        and instance.encounterRewardRowOffsetByRouteRow[math.floor(tonumber(rowIndex) or 0)]
        or nil
    legIndex = math.floor(tonumber(legIndex) or 0)
    if offset == nil or legIndex < 1 or legIndex > data.maxEncounterRewardLegCount(instance) then
        return nil
    end
    return offset + legIndex
end

function data.encounterRewardLegCountForRow(instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local policy = data.variantPolicyForRole(instance, roleKey)
    if policy == nil then
        return 0
    end

    local _, variant = data.resolveVariant(instance, rows, rowIndex, roleKey)
    local realCombatCount = variant and math.floor(tonumber(variant.realCombatCount) or 0) or 0
    if realCombatCount <= 0 then
        return 0
    end
    if not isVariantAvailableAtSlot(variant, slotForRow(instance, rowIndex)) then
        return 0
    end

    local activeCount = realCombatCount - 1
    local legCount = #(policy.rewardLegs or {})
    if activeCount > legCount then
        return legCount
    end
    return activeCount
end

function data.encounterRewardLegForRow(instance, rows, rowIndex, legIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local policy = data.variantPolicyForRole(instance, roleKey)
    if policy == nil then
        return nil
    end

    legIndex = math.floor(tonumber(legIndex) or 0)
    if legIndex < 1 or legIndex > data.encounterRewardLegCountForRow(instance, rows, rowIndex) then
        return nil
    end
    return policy.rewardLegs and policy.rewardLegs[legIndex] or nil
end

function data.encounterRewardLegsForRow(instance, rows, rowIndex)
    local legs = {}
    for legIndex = 1, data.encounterRewardLegCountForRow(instance, rows, rowIndex) do
        legs[#legs + 1] = data.encounterRewardLegForRow(instance, rows, rowIndex, legIndex)
    end
    return legs
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
            key = "EncounterRewards",
            type = "table",
            minRows = instance.encounterRewardRowCount,
            defaultRows = instance.encounterRewardRowCount,
            maxRows = instance.encounterRewardRowCount,
            row = data.buildRewardRows(),
        },
    }
end

return data
