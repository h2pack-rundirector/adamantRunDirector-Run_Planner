local deps = ...
local common = deps.common
local availability = deps.availability
local readCache = deps.readCache
local requirements = deps.requirements

local data = {}

local REWARD_SLOT_COUNT = common.REWARD_SLOT_COUNT
local VANILLA_ROLE_KEY = common.VANILLA_ROLE_KEY
local routeApi

local shallowCopyList = common.shallowCopyList
local optionListForRole = common.optionListForRole
local clearList = common.clearList
local buildLookup = common.buildLookup
local buildKeyLookup = common.buildKeyLookup
local addChoice = common.addChoice
local shouldOfferAutoOption = common.shouldOfferAutoOption
local buildRoleChoices = common.buildRoleChoices
local buildOptionChoices = common.buildOptionChoices
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
local isAvailableAtSlot = availability.isAvailableAtSlot
local optionCap = availability.optionCap
local slotDepth = availability.slotDepth
local activeReadCache = readCache.active
local rowRecord = readCache.rowRecord
local nestedRecord = readCache.nestedRecord

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

local function countPriorRoleSelections(instance, rows, rowIndex, roleKey)
    if rows == nil or roleKey == nil or roleKey == "" then
        return 0
    end

    local count = 0
    for priorIndex = 1, rowIndex - 1 do
        if rows:read(priorIndex, "RoleKey") == roleKey
            and data.isRoleAvailable(instance, rows, priorIndex, roleKey)
        then
            count = count + 1
        end
    end
    return count
end

local function countPriorOptionSelections(instance, role, rows, rowIndex, optionKey)
    if rows == nil or optionKey == nil or optionKey == "" then
        return 0
    end

    local count = 0
    for priorIndex = 1, rowIndex - 1 do
        if rows:read(priorIndex, "RoleKey") == role.key
            and rows:read(priorIndex, "OptionKey") == optionKey
            and data.isOptionAvailable(instance, rows, priorIndex, role.key, optionKey)
        then
            count = count + 1
        end
    end
    return count
end

local function isRoleWithinSelectionCap(instance, role, rows, rowIndex)
    local maxSelections = role and role.routeRules and role.routeRules.maxSelectionsPerBiome
    if maxSelections == nil then
        return true
    end
    return countPriorRoleSelections(instance, rows, rowIndex, role.key) < maxSelections
end

local function isOptionWithinSelectionCap(instance, role, option, rows, rowIndex)
    local maxSelections = optionCap(option)
    if maxSelections == nil then
        return true
    end
    return countPriorOptionSelections(instance, role, rows, rowIndex, option.key) < maxSelections
end

local function forcedRuleForSlot(instance, slot)
    local depth = slotDepth(slot)
    if depth == nil then
        return nil
    end
    return instance.forcedDepthOptions and instance.forcedDepthOptions[depth] or nil
end

local function forcedRuleForRow(instance, rowIndex)
    return forcedRuleForSlot(instance, slotForRow(instance, rowIndex))
end

local function isRoleAllowedByForcedRule(instance, rowIndex, roleKey)
    local rule = forcedRuleForRow(instance, rowIndex)
    if rule == nil or roleKey == VANILLA_ROLE_KEY then
        return true
    end
    return roleKey == rule.roleKey
end

local function isOptionAllowedByForcedRule(instance, rowIndex, roleKey, optionKey)
    local rule = forcedRuleForRow(instance, rowIndex)
    if rule == nil then
        return true
    end
    if roleKey ~= rule.roleKey then
        return false
    end
    if rule.optionKeysByKey == nil then
        return true
    end
    return rule.optionKeysByKey[optionKey] == true
end

local function hasAvailableConcreteOption(instance, role, rows, rowIndex, slot)
    for _, option in ipairs(optionListForRole(role)) do
        if isAvailableAtSlot(option, slot)
            and isOptionWithinSelectionCap(instance, role, option, rows, rowIndex)
            and isOptionAllowedByForcedRule(instance, rowIndex, role.key, option.key)
        then
            return true
        end
    end
    return false
end

local function buildFixedRoleSlot(instance, depth, special)
    local roomOptions = shallowCopyList(special.roomOptions)
    local role = {
        key = special.key or special.kind,
        label = special.label or special.key or special.kind,
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
        roleKey = role.key,
        role = role,
    }
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startDepth = math.floor(tonumber(slotLayout.routeStartDepth) or 1)
    local endDepth = math.floor(tonumber(slotLayout.routeEndDepth) or startDepth)
    if endDepth < startDepth then
        endDepth = startDepth
    end

    instance.routeSlots = {}
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

local function findFirstAvailableOption(instance, rows, rowIndex, role)
    local values = role.optionValues or instance.optionValuesByRole[role.key] or {}
    for _, optionKey in ipairs(values) do
        if data.isOptionAvailable(instance, rows, rowIndex, role.key, optionKey) then
            return optionKey, optionKey ~= "" and role.optionsByKey[optionKey] or nil
        end
    end
    return nil, nil
end

local function readRoleKey(instance, rows, rowIndex)
    local roleKey = rows and rows:read(rowIndex, "RoleKey") or nil
    local slot = instance ~= nil and slotForRow(instance, rowIndex) or nil
    if isFixedRoleSlot(slot) then
        return slot.roleKey
    end
    if isPrebossSlot(slot) then
        return firstBranchKey(slot)
    end
    if roleKey == nil or roleKey == "" then
        return VANILLA_ROLE_KEY
    end
    return roleKey
end

local function readOptionKey(rows, rowIndex)
    return rows and rows:read(rowIndex, "OptionKey") or ""
end

local function roleForRow(instance, rowIndex, roleKey)
    local slot = slotForRow(instance, rowIndex)
    if isFixedRoleSlot(slot) then
        if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
            return slot.role
        end
        return nil
    end
    return instance.rolesByKey[roleKey]
end

local function optionValuesForRole(instance, role)
    if role == nil then
        return {}
    end
    return role.optionValues or instance.optionValuesByRole[role.key] or {}
end

local function optionLabelsForRole(instance, role)
    if role == nil then
        return {}
    end
    return role.optionLabels or instance.optionLabelsByRole[role.key] or {}
end

local function buildRewardRows()
    local rows = {
        { key = "RoleKey", type = "string", default = "", maxLen = 32 },
        { key = "OptionKey", type = "string", default = "", maxLen = 64 },
        { key = "VariantKey", type = "string", default = "", maxLen = 64 },
    }

    for index = 1, REWARD_SLOT_COUNT do
        rows[#rows + 1] = {
            key = "Reward" .. tostring(index) .. "Key",
            type = "string",
            default = "",
            maxLen = 96,
        }
    end
    for index = 1, REWARD_SLOT_COUNT do
        rows[#rows + 1] = {
            key = "Reward" .. tostring(index) .. "LootKey",
            type = "string",
            default = "",
            maxLen = 96,
        }
    end
    return rows
end

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    instance.roles = shallowCopyList(instance.biome.roles)
    instance.rolesByKey = buildLookup(instance.roles)
    for _, role in ipairs(instance.roles) do
        role.optionsByKey = buildLookup(optionListForRole(role))
        requirements.prepareRole(role)
    end
    instance.forcedDepthOptions = instance.biome.forcedDepthOptions or {}
    for _, rule in pairs(instance.forcedDepthOptions) do
        rule.optionKeysByKey = buildKeyLookup(rule.optionKeys)
    end

    buildRouteSlots(instance)
    buildRoleChoices(instance)
    addBranchLabels(instance)
    requirements.prepareSlots(instance.routeSlots)
    return instance
end

function data.storage(instance)
    return {
        {
            key = "Rows",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = buildRewardRows(),
        },
    }
end

function data.optionListForRole(role)
    return optionListForRole(role)
end

function data.isFixedIdentityRow(instance, rowIndex)
    return isFixedIdentitySlot(slotForRow(instance, rowIndex))
end

function data.optionLabelsForRow(instance, rowIndex, roleKey)
    return optionLabelsForRole(instance, roleForRow(instance, rowIndex, roleKey))
end

local function isOptionAvailableUncached(instance, rows, rowIndex, roleKey, optionKey)
    if isPrebossSlot(slotForRow(instance, rowIndex)) then
        return false
    end

    local role = roleForRow(instance, rowIndex, roleKey)
    if role == nil then
        return false
    end

    local slot = slotForRow(instance, rowIndex)
    if optionKey == "" then
        return shouldOfferAutoOption(role, optionListForRole(role))
            and hasAvailableConcreteOption(instance, role, rows, rowIndex, slot)
    end

    local option = role.optionsByKey and role.optionsByKey[optionKey] or nil
    if option == nil then
        return false
    end
    return isAvailableAtSlot(option, slot)
        and isOptionWithinSelectionCap(instance, role, option, rows, rowIndex)
        and isOptionAllowedByForcedRule(instance, rowIndex, roleKey, optionKey)
end

function data.isOptionAvailable(instance, rows, rowIndex, roleKey, optionKey)
    local cache = activeReadCache(instance)
    if cache == nil then
        return isOptionAvailableUncached(instance, rows, rowIndex, roleKey, optionKey)
    end

    local roleRecords = nestedRecord(cache.optionAvailability, rowIndex, roleKey or "")
    local record = rowRecord(roleRecords, optionKey or "")
    if record.pass == cache.pass then
        return record.value
    end

    local value = isOptionAvailableUncached(instance, rows, rowIndex, roleKey, optionKey)
    record.pass = cache.pass
    record.value = value
    return value
end

local function isRoleAvailableUncached(instance, rows, rowIndex, roleKey)
    local slot = slotForRow(instance, rowIndex)
    if isFixedRoleSlot(slot) then
        return roleKey == slot.roleKey
    end
    if isPrebossSlot(slot) then
        return slot.branchesByKey[roleKey] ~= nil
    end

    local role = instance.rolesByKey[roleKey]
    if role == nil then
        return false
    end
    if roleKey == VANILLA_ROLE_KEY then
        return true
    end
    if not isRoleAllowedByForcedRule(instance, rowIndex, roleKey) then
        return false
    end
    if not isRoleWithinSelectionCap(instance, role, rows, rowIndex) then
        return false
    end
    if not requirements.status(routeApi, instance, rows, rowIndex, role).valid then
        return false
    end

    local options = optionListForRole(role)
    if #options == 0 then
        return true
    end
    return findFirstAvailableOption(instance, rows, rowIndex, role) ~= nil
end

function data.isRoleAvailable(instance, rows, rowIndex, roleKey)
    local cache = activeReadCache(instance)
    if cache == nil then
        return isRoleAvailableUncached(instance, rows, rowIndex, roleKey)
    end

    local record = nestedRecord(cache.roleAvailability, rowIndex, roleKey or "")
    if record.pass == cache.pass then
        return record.value
    end

    local value = isRoleAvailableUncached(instance, rows, rowIndex, roleKey)
    record.pass = cache.pass
    record.value = value
    return value
end

function data.readRoleKey(instanceOrRows, rowsOrIndex, rowIndex)
    if rowIndex ~= nil then
        return readRoleKey(instanceOrRows, rowsOrIndex, rowIndex)
    end
    return readRoleKey(nil, instanceOrRows, rowsOrIndex)
end

local function resolveRoleUncached(instance, rows, rowIndex)
    local roleKey = readRoleKey(instance, rows, rowIndex)
    local slot = slotForRow(instance, rowIndex)
    if isFixedRoleSlot(slot) then
        return roleKey, roleForRow(instance, rowIndex, roleKey)
    end
    if isPrebossSlot(slot) then
        return roleKey, slot.branchesByKey[roleKey]
    end
    return roleKey, instance.rolesByKey[roleKey]
end

function data.resolveRole(instance, rows, rowIndex)
    local cache = activeReadCache(instance)
    if cache == nil then
        return resolveRoleUncached(instance, rows, rowIndex)
    end

    local record = rowRecord(cache.roles, rowIndex)
    if record.pass == cache.pass then
        return record.roleKey, record.role
    end

    local roleKey, role = resolveRoleUncached(instance, rows, rowIndex)
    record.pass = cache.pass
    record.roleKey = roleKey
    record.role = role
    return roleKey, role
end

local function resolveOptionUncached(instance, rows, rowIndex, roleKey)
    if isPrebossSlot(slotForRow(instance, rowIndex)) then
        return "", nil
    end

    local role = roleForRow(instance, rowIndex, roleKey)
    if role == nil then
        return readOptionKey(rows, rowIndex) or "", nil
    end

    local options = optionListForRole(role)
    if #options == 0 then
        return "", nil
    end

    local optionKey = readOptionKey(rows, rowIndex) or ""
    if optionKey ~= "" then
        return optionKey, role.optionsByKey and role.optionsByKey[optionKey] or nil
    end

    if shouldOfferAutoOption(role, options) then
        return "", nil
    end

    local normalizedKey, option = findFirstAvailableOption(instance, rows, rowIndex, role)
    return normalizedKey or "", option
end

function data.resolveOption(instance, rows, rowIndex, roleKey)
    local cache = activeReadCache(instance)
    if cache == nil then
        return resolveOptionUncached(instance, rows, rowIndex, roleKey)
    end

    local record = nestedRecord(cache.options, rowIndex, roleKey or "")
    if record.pass == cache.pass then
        return record.optionKey, record.option
    end

    local optionKey, option = resolveOptionUncached(instance, rows, rowIndex, roleKey)
    record.pass = cache.pass
    record.optionKey = optionKey
    record.option = option
    return optionKey, option
end

local function validateRowUncached(instance, rows, rowIndex)
    local roleKey, role = data.resolveRole(instance, rows, rowIndex)
    if role == nil then
        return invalidStatus("unknown_role", "Unknown route role: " .. tostring(roleKey))
    end
    if isPrebossSlot(slotForRow(instance, rowIndex)) then
        return validStatus()
    end
    if roleKey == VANILLA_ROLE_KEY then
        return validStatus()
    end
    if not isRoleAllowedByForcedRule(instance, rowIndex, roleKey) then
        local rule = forcedRuleForRow(instance, rowIndex)
        return invalidStatus(
            "forced_depth_role",
            "Depth " .. tostring(instance.routeSlots[rowIndex] and instance.routeSlots[rowIndex].coordinate)
                .. " is forced to " .. tostring(rule and rule.roleKey or "another role")
        )
    end
    if not isRoleWithinSelectionCap(instance, role, rows, rowIndex) then
        return invalidStatus("role_limit", tostring(role.label or roleKey) .. " is already planned for this biome")
    end
    local roleRequirementStatus = requirements.status(routeApi, instance, rows, rowIndex, role)
    if not roleRequirementStatus.valid then
        return invalidStatus(roleRequirementStatus.code, roleRequirementStatus.message)
    end

    local options = optionListForRole(role)
    if #options == 0 then
        return validStatus()
    end

    local optionKey = readOptionKey(rows, rowIndex) or ""
    local resolvedOptionKey, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    if optionKey ~= "" and option == nil then
        return invalidStatus("unknown_option", "Unknown route option: " .. tostring(optionKey))
    end
    if resolvedOptionKey == "" and shouldOfferAutoOption(role, options) then
        if data.isOptionAvailable(instance, rows, rowIndex, roleKey, "") then
            return validStatus()
        end
        return invalidStatus("option_unavailable", tostring(role.label or roleKey) .. " has no valid option here")
    end
    if resolvedOptionKey == "" or not data.isOptionAvailable(instance, rows, rowIndex, roleKey, resolvedOptionKey) then
        return invalidStatus("option_unavailable", tostring(role.label or roleKey) .. " is not valid at this depth")
    end

    local requirementStatus = requirements.status(routeApi, instance, rows, rowIndex, role, option)
    if not requirementStatus.valid then
        return invalidStatus(requirementStatus.code, requirementStatus.message)
    end
    return validStatus()
end

function data.validateRow(instance, rows, rowIndex)
    local cache = activeReadCache(instance)
    if cache == nil then
        return validateRowUncached(instance, rows, rowIndex)
    end

    local record = rowRecord(cache.validations, rowIndex)
    if record.pass == cache.pass then
        return record.value
    end

    local value = validateRowUncached(instance, rows, rowIndex)
    record.pass = cache.pass
    record.value = value
    return value
end

local function fillRoleValuesUncached(instance, rows, rowIndex, values)
    clearList(values)
    local slot = slotForRow(instance, rowIndex)
    if isFixedRoleSlot(slot) then
        values[#values + 1] = slot.roleKey
        return values
    end
    if isPrebossSlot(slot) then
        for _, branchKey in ipairs(slot.branchValues or {}) do
            values[#values + 1] = branchKey
        end
        return values
    end

    for _, role in ipairs(instance.roles or {}) do
        if data.isRoleAvailable(instance, rows, rowIndex, role.key) then
            values[#values + 1] = role.key
        end
    end
    return values
end

function data.roleValuesForRow(instance, rows, rowIndex)
    local cache = activeReadCache(instance)
    if cache == nil then
        local values = {}
        return fillRoleValuesUncached(instance, rows, rowIndex, values)
    end

    local record = rowRecord(cache.roleValues, rowIndex)
    if record.pass ~= cache.pass then
        record.pass = cache.pass
        record.values = record.values or {}
        fillRoleValuesUncached(instance, rows, rowIndex, record.values)
    end
    return record.values
end

function data.fillRoleValues(instance, rows, rowIndex, values)
    if activeReadCache(instance) == nil then
        return fillRoleValuesUncached(instance, rows, rowIndex, values)
    end

    clearList(values)
    for _, value in ipairs(data.roleValuesForRow(instance, rows, rowIndex)) do
        values[#values + 1] = value
    end
    return values
end

local function fillOptionValuesUncached(instance, rows, rowIndex, roleKey, values)
    clearList(values)
    if isPrebossSlot(slotForRow(instance, rowIndex)) then
        return values
    end

    local role = roleForRow(instance, rowIndex, roleKey)
    if role == nil then
        return values
    end

    for _, optionKey in ipairs(optionValuesForRole(instance, role)) do
        if data.isOptionAvailable(instance, rows, rowIndex, roleKey, optionKey) then
            values[#values + 1] = optionKey
        end
    end
    return values
end

function data.optionValuesForRow(instance, rows, rowIndex, roleKey)
    local cache = activeReadCache(instance)
    if cache == nil then
        local values = {}
        return fillOptionValuesUncached(instance, rows, rowIndex, roleKey, values)
    end

    local record = nestedRecord(cache.optionValues, rowIndex, roleKey or "")
    if record.pass ~= cache.pass then
        record.pass = cache.pass
        record.values = record.values or {}
        fillOptionValuesUncached(instance, rows, rowIndex, roleKey, record.values)
    end
    return record.values
end

function data.fillOptionValues(instance, rows, rowIndex, roleKey, values)
    if activeReadCache(instance) == nil then
        return fillOptionValuesUncached(instance, rows, rowIndex, roleKey, values)
    end

    clearList(values)
    for _, value in ipairs(data.optionValuesForRow(instance, rows, rowIndex, roleKey)) do
        values[#values + 1] = value
    end
    return values
end

function data.beginReadPass(instance)
    readCache.begin(instance)
end

function data.invalidateReadPass(instance)
    readCache.invalidate(instance)
end

function data.endReadPass(instance)
    readCache.finish(instance)
end

routeApi = {
    resolveRole = data.resolveRole,
    resolveOption = data.resolveOption,
    validateRow = data.validateRow,
}

data.REWARD_SLOT_COUNT = REWARD_SLOT_COUNT

return data
