local deps = ...
local common = deps.common
local availability = deps.availability
local readCache = deps.readCache
local requirements = deps.requirements
local biomeRules = deps.biomeRules

local rowEngine = {}

local REWARD_SLOT_COUNT = common.REWARD_SLOT_COUNT
local VANILLA_ROLE_KEY = common.VANILLA_ROLE_KEY

local shallowCopyList = common.shallowCopyList
local optionListForRole = common.optionListForRole
local clearList = common.clearList
local buildLookup = common.buildLookup
local shouldOfferAutoOption = common.shouldOfferAutoOption
local buildRoleChoices = common.buildRoleChoices
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
local isAvailable = availability.isAvailable
local availabilityStatus = availability.status
local optionCap = availability.optionCap
local activeReadCache = readCache.active
local rowRecord = readCache.rowRecord
local nestedRecord = readCache.nestedRecord

local function defaultSlotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function defaultIsFixedIdentitySlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function defaultRoleForRow(instance, _rowIndex, roleKey, slot)
    if slot ~= nil and slot.role ~= nil then
        if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
            return slot.role
        end
        return nil
    end
    return instance.rolesByKey[roleKey]
end

local function defaultReadRoleKey(_instance, rows, rowIndex, slot)
    if slot ~= nil and slot.roleKey ~= nil then
        return slot.roleKey
    end

    local roleKey = rows and rows:read(rowIndex, "RoleKey") or nil
    if roleKey == nil or roleKey == "" then
        return VANILLA_ROLE_KEY
    end
    return roleKey
end

local function readOptionKey(rows, rowIndex)
    return rows and rows:read(rowIndex, "OptionKey") or ""
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

local function buildRoomRows()
    return {
        { key = "RoleKey", type = "string", default = "", maxLen = 32 },
        { key = "OptionKey", type = "string", default = "", maxLen = 64 },
        { key = "VariantKey", type = "string", default = "", maxLen = 64 },
    }
end

local function buildRewardRows()
    local rows = {}

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

local function prepareRoles(instance)
    instance.roles = shallowCopyList(instance.biome.roles)
    instance.rolesByKey = buildLookup(instance.roles)
    for _, role in ipairs(instance.roles) do
        role.optionsByKey = buildLookup(optionListForRole(role))
        requirements.prepareRole(role)
    end
end

function rowEngine.create(adapter)
    adapter = adapter or {}

    local data = {}
    local routeApi

    local slotForRow = adapter.slotForRow or defaultSlotForRow
    local isFixedIdentitySlot = adapter.isFixedIdentitySlot or defaultIsFixedIdentitySlot

    local function roleForRow(instance, rowIndex, roleKey)
        local slot = slotForRow(instance, rowIndex)
        if adapter.roleForRow ~= nil then
            return adapter.roleForRow(instance, rowIndex, roleKey, slot, defaultRoleForRow)
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end

    local function readRoleKey(instance, rows, rowIndex)
        local slot = instance ~= nil and slotForRow(instance, rowIndex) or nil
        if adapter.readRoleKey ~= nil then
            return adapter.readRoleKey(instance, rows, rowIndex, slot, defaultReadRoleKey)
        end
        return defaultReadRoleKey(instance, rows, rowIndex, slot)
    end

    local function isRoleAllowed(instance, rows, rowIndex, roleKey, role)
        if adapter.isRoleAllowed == nil then
            return true
        end
        return adapter.isRoleAllowed(instance, rows, rowIndex, roleKey, role, slotForRow(instance, rowIndex))
    end

    local function isOptionAllowed(instance, rows, rowIndex, roleKey, optionKey, role, option)
        if adapter.isOptionAllowed == nil then
            return true
        end
        return adapter.isOptionAllowed(instance, rows, rowIndex, roleKey, optionKey, role, option, slotForRow(instance, rowIndex))
    end

    local function selectedOptionForCost(role, rows, rowIndex)
        if role == nil then
            return "", nil
        end

        local optionKey = readOptionKey(rows, rowIndex) or ""
        if optionKey ~= "" then
            return optionKey, role.optionsByKey and role.optionsByKey[optionKey] or nil
        end

        local options = optionListForRole(role)
        if #options == 1 and not shouldOfferAutoOption(role, options) then
            local option = options[1]
            return option.key or "", option
        end
        return "", nil
    end

    local function explicitBiomeEncounterDepthCost(value)
        if value == nil then
            return nil
        end
        return common.numericCost(value, 0)
    end

    local function explicitBiomeDepthCacheCost(value)
        if value == nil then
            return nil
        end
        return common.numericCost(value, 0)
    end

    local function explicitRoomHistoryCost(value)
        if value == nil then
            return nil
        end
        return common.numericCost(value, 0)
    end

    local function biomeDepthCacheStart(instance)
        local slotLayout = instance and instance.biome and instance.biome.slotLayout or nil
        if slotLayout == nil then
            return 0
        end
        if slotLayout.biomeDepthCacheStart ~= nil then
            return math.floor(tonumber(slotLayout.biomeDepthCacheStart) or 0)
        end
        local depthRange = slotLayout.depthRange
        if depthRange ~= nil and depthRange.min ~= nil then
            return math.floor(tonumber(depthRange.min) or 0)
        end
        return 0
    end

    local function adapterBiomeEncounterDepthCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if adapter.biomeEncounterDepthCost == nil then
            return nil
        end

        local cost = adapter.biomeEncounterDepthCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if cost ~= nil then
            return common.numericCost(cost, 0)
        end
        return nil
    end

    local function effectiveBiomeEncounterDepthCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        local cost = adapterBiomeEncounterDepthCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if cost ~= nil then
            return cost
        end
        cost = explicitBiomeEncounterDepthCost(option and option.biomeEncounterDepthCost)
        if cost ~= nil then
            return cost
        end
        cost = explicitBiomeEncounterDepthCost(role and role.biomeEncounterDepthCost)
        if cost ~= nil then
            return cost
        end
        cost = explicitBiomeEncounterDepthCost(slot and slot.biomeEncounterDepthCost)
        if cost ~= nil then
            return cost
        end
        return nil
    end

    local function adapterBiomeDepthCacheCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if adapter.biomeDepthCacheCost == nil then
            return nil
        end

        local cost = adapter.biomeDepthCacheCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if cost ~= nil then
            return common.numericCost(cost, 0)
        end
        return nil
    end

    local function effectiveBiomeDepthCacheCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        local cost = adapterBiomeDepthCacheCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if cost ~= nil then
            return cost
        end
        cost = explicitBiomeDepthCacheCost(option and option.biomeDepthCacheCost)
        if cost ~= nil then
            return cost
        end
        cost = explicitBiomeDepthCacheCost(role and role.biomeDepthCacheCost)
        if cost ~= nil then
            return cost
        end
        cost = explicitBiomeDepthCacheCost(slot and slot.biomeDepthCacheCost)
        if cost ~= nil then
            return cost
        end
        return nil
    end

    local function adapterRoomHistoryCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if adapter.roomHistoryCost == nil then
            return nil
        end

        local cost = adapter.roomHistoryCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if cost ~= nil then
            return common.numericCost(cost, 0)
        end
        return nil
    end

    local function effectiveRoomHistoryCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        local cost = adapterRoomHistoryCost(instance, rows, rowIndex, roleKey, role, optionKey, option, slot)
        if cost ~= nil then
            return cost
        end
        cost = explicitRoomHistoryCost(option and option.roomHistoryCost)
        if cost ~= nil then
            return cost
        end
        cost = explicitRoomHistoryCost(role and role.roomHistoryCost)
        if cost ~= nil then
            return cost
        end
        cost = explicitRoomHistoryCost(slot and slot.roomHistoryCost)
        if cost ~= nil then
            return cost
        end
        return nil
    end

    local function rowContextUncached(instance, rows, rowIndex, target)
        local slot = slotForRow(instance, rowIndex)
        local previous = nil
        if rowIndex > 1 then
            previous = data.rowContext(instance, rows, rowIndex - 1)
        end

        local biomeDepthCache = biomeDepthCacheStart(instance)
        local biomeDepthCacheKnown = true
        if rowIndex > 1 then
            if previous == nil
                or previous.biomeDepthCacheKnown == false
                or previous.biomeDepthCache == nil
                or previous.biomeDepthCacheCost == nil
            then
                biomeDepthCache = nil
                biomeDepthCacheKnown = false
            else
                biomeDepthCache = previous.biomeDepthCache + previous.biomeDepthCacheCost
            end
        end

        local biomeEncounterDepth = 0
        local biomeEncounterDepthKnown = true
        if rowIndex > 1 then
            if previous == nil
                or previous.biomeEncounterDepthKnown == false
                or previous.biomeEncounterDepth == nil
                or previous.biomeEncounterDepthCost == nil
            then
                biomeEncounterDepth = nil
                biomeEncounterDepthKnown = false
            else
                biomeEncounterDepth = previous.biomeEncounterDepth + previous.biomeEncounterDepthCost
            end
        end
        local roleKey = readRoleKey(instance, rows, rowIndex)
        local role = roleForRow(instance, rowIndex, roleKey)
        local optionKey, option = selectedOptionForCost(role, rows, rowIndex)
        local biomeDepthCacheCost = effectiveBiomeDepthCacheCost(
            instance,
            rows,
            rowIndex,
            roleKey,
            role,
            optionKey,
            option,
            slot
        )
        local biomeEncounterDepthCost = effectiveBiomeEncounterDepthCost(
            instance,
            rows,
            rowIndex,
            roleKey,
            role,
            optionKey,
            option,
            slot
        )
        local roomHistoryCost = effectiveRoomHistoryCost(
            instance,
            rows,
            rowIndex,
            roleKey,
            role,
            optionKey,
            option,
            slot
        )
        target = target or {}
        target.rowIndex = rowIndex
        target.routeOrdinal = slot and slot.routeOrdinal or nil
        target.biomeDepthCache = biomeDepthCache
        target.biomeDepthCacheKnown = biomeDepthCacheKnown
        target.biomeDepthCacheCost = biomeDepthCacheCost
        target.biomeDepthCacheCostKnown = biomeDepthCacheCost ~= nil
        target.biomeEncounterDepth = biomeEncounterDepth
        target.biomeEncounterDepthKnown = biomeEncounterDepthKnown
        target.biomeEncounterDepthCost = biomeEncounterDepthCost
        target.biomeEncounterDepthCostKnown = biomeEncounterDepthCost ~= nil
        target.roomHistoryCost = roomHistoryCost
        return target
    end

    function data.rowContext(instance, rows, rowIndex)
        local cache = activeReadCache(instance)
        if cache == nil then
            return rowContextUncached(instance, rows, rowIndex)
        end

        local record = rowRecord(cache.rowContexts, rowIndex)
        if record.pass == cache.pass then
            return record.value
        end

        local value = rowContextUncached(instance, rows, rowIndex, record.value)
        record.pass = cache.pass
        record.value = value
        return value
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

    local function hasAvailableConcreteOption(instance, role, rows, rowIndex, rowContext)
        for _, option in ipairs(optionListForRole(role)) do
            if isAvailable(option, rowContext)
                and isOptionWithinSelectionCap(instance, role, option, rows, rowIndex)
                and isOptionAllowed(instance, rows, rowIndex, role.key, option.key, role, option)
            then
                return true
            end
        end
        return false
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

    function data.prepareRoles(instance)
        prepareRoles(instance)
    end

    function data.buildRoleChoices(instance)
        buildRoleChoices(instance)
    end

    function data.prepareSlots(instance)
        requirements.prepareSlots(instance.routeSlots)
    end

    function data.buildRewardRows()
        return buildRewardRows()
    end

    function data.buildRoomRows()
        return buildRoomRows()
    end

    function data.isRewardAlias(alias)
        return type(alias) == "string" and string.match(alias, "^Reward%d+.*Key$") ~= nil
    end

    function data.optionListForRole(role)
        return optionListForRole(role)
    end

    function data.rowFeatures(slot, _role, option)
        if option ~= nil then
            return option.features
        end
        if slot ~= nil and slot.roomKey ~= nil then
            return slot.features
        end
        return nil
    end

    function data.isFixedIdentityRow(instance, rowIndex)
        return isFixedIdentitySlot(slotForRow(instance, rowIndex))
    end

    function data.optionLabelsForRow(instance, rowIndex, roleKey)
        return optionLabelsForRole(instance, roleForRow(instance, rowIndex, roleKey))
    end

    local function isOptionAvailableUncached(instance, rows, rowIndex, roleKey, optionKey)
        local slot = slotForRow(instance, rowIndex)
        if adapter.skipOptionsForSlot ~= nil
            and adapter.skipOptionsForSlot(instance, rows, rowIndex, slot)
        then
            return false
        end

        local role = roleForRow(instance, rowIndex, roleKey)
        if role == nil then
            return false
        end

        if optionKey == "" then
            return shouldOfferAutoOption(role, optionListForRole(role))
                and hasAvailableConcreteOption(instance, role, rows, rowIndex, data.rowContext(instance, rows, rowIndex))
        end

        local option = role.optionsByKey and role.optionsByKey[optionKey] or nil
        if option == nil then
            return false
        end
        return isAvailable(option, data.rowContext(instance, rows, rowIndex))
            and isOptionWithinSelectionCap(instance, role, option, rows, rowIndex)
            and isOptionAllowed(instance, rows, rowIndex, roleKey, optionKey, role, option)
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
        if adapter.roleAvailabilityForSlot ~= nil then
            local value = adapter.roleAvailabilityForSlot(instance, rows, rowIndex, roleKey, slot)
            if value ~= nil then
                return value
            end
        end

        local role = instance.rolesByKey[roleKey]
        if role == nil then
            return false
        end
        if roleKey == VANILLA_ROLE_KEY then
            return true
        end
        if not isRoleAllowed(instance, rows, rowIndex, roleKey, role) then
            return false
        end
        if not isRoleWithinSelectionCap(instance, role, rows, rowIndex) then
            return false
        end
        if not requirements.isSatisfied(routeApi, instance, rows, rowIndex, role) then
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
        return roleKey, roleForRow(instance, rowIndex, roleKey)
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
        local slot = slotForRow(instance, rowIndex)
        if adapter.skipOptionsForSlot ~= nil
            and adapter.skipOptionsForSlot(instance, rows, rowIndex, slot)
        then
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
        if role.requiresConcreteOption then
            return "", nil
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

    local function rowRoomKeyUncached(instance, rows, rowIndex)
        local slot = slotForRow(instance, rowIndex)
        local roleKey, role = data.resolveRole(instance, rows, rowIndex)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        if option ~= nil and option.key ~= nil and option.key ~= "" then
            return option.key
        end
        if role ~= nil and role.roomKey ~= nil and role.roomKey ~= "" then
            return role.roomKey
        end
        return slot and slot.roomKey or nil
    end

    function data.rowRoomKey(instance, rows, rowIndex)
        return rowRoomKeyUncached(instance, rows, rowIndex)
    end

    local function validateBaseRowUncached(instance, rows, rowIndex)
        local slot = slotForRow(instance, rowIndex)
        local roleKey, role = data.resolveRole(instance, rows, rowIndex)
        if role == nil then
            return invalidStatus("unknown_role", "Unknown route role: " .. tostring(roleKey))
        end

        if adapter.validateSlot ~= nil then
            local result = adapter.validateSlot(instance, rows, rowIndex, roleKey, role, slot)
            if result ~= nil then
                return result
            end
        end
        if roleKey == VANILLA_ROLE_KEY then
            return validStatus()
        end
        if not isRoleAllowed(instance, rows, rowIndex, roleKey, role) then
            if adapter.roleDisallowedStatus ~= nil then
                return adapter.roleDisallowedStatus(instance, rows, rowIndex, roleKey, role, slot)
            end
            return invalidStatus("role_unavailable", tostring(role.label or roleKey) .. " is not valid here")
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
        if optionKey == "" and role.requiresConcreteOption then
            return invalidStatus("option_required", "Choose a " .. tostring(role.label or roleKey))
        end
        if resolvedOptionKey == "" and shouldOfferAutoOption(role, options) then
            if data.isOptionAvailable(instance, rows, rowIndex, roleKey, "") then
                return validStatus()
            end
            return invalidStatus("option_unavailable", tostring(role.label or roleKey) .. " has no valid option here")
        end
        if resolvedOptionKey ~= "" then
            local status = availabilityStatus(option, data.rowContext(instance, rows, rowIndex))
            if not status.valid then
                return invalidStatus(status.code, status.message)
            end
        end
        if resolvedOptionKey == "" or not data.isOptionAvailable(instance, rows, rowIndex, roleKey, resolvedOptionKey) then
            local message
            if adapter.optionUnavailableMessage ~= nil then
                message = adapter.optionUnavailableMessage(instance, rows, rowIndex, roleKey, role, slot)
            end
            message = message or (tostring(role.label or roleKey) .. " is not valid here")
            return invalidStatus("option_unavailable", message)
        end

        local requirementStatus = requirements.status(routeApi, instance, rows, rowIndex, role, option)
        if not requirementStatus.valid then
            return invalidStatus(requirementStatus.code, requirementStatus.message)
        end
        return validStatus()
    end

    function data.validateBaseRow(instance, rows, rowIndex)
        return validateBaseRowUncached(instance, rows, rowIndex)
    end

    local function validateRowUncached(instance, rows, rowIndex)
        local status = validateBaseRowUncached(instance, rows, rowIndex)
        if not status.valid then
            return status
        end
        if biomeRules ~= nil then
            status = biomeRules.status(routeApi, instance, rows, rowIndex)
            if not status.valid then
                return status
            end
        end
        return status
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
        if adapter.fillRoleValuesForSlot ~= nil
            and adapter.fillRoleValuesForSlot(instance, rows, rowIndex, slot, values)
        then
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
        local slot = slotForRow(instance, rowIndex)
        if adapter.skipOptionsForSlot ~= nil
            and adapter.skipOptionsForSlot(instance, rows, rowIndex, slot)
        then
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
        rowContext = data.rowContext,
        rowRoomKey = data.rowRoomKey,
        validateBaseRow = data.validateBaseRow,
        validateRow = data.validateRow,
    }

    data.REWARD_SLOT_COUNT = REWARD_SLOT_COUNT

    return data
end

return rowEngine
