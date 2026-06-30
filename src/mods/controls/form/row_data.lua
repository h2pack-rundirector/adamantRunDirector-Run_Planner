local deps = ...
local common = deps.common
local readCache = deps.readCache
local valueStates = deps.valueStates
local rewards = deps.rewards

local rowEngine = {}

local VANILLA_ROLE_KEY = common.VANILLA_ROLE_KEY

local shallowCopyList = common.shallowCopyList
local optionListForRole = common.optionListForRole
local clearList = common.clearList
local buildLookup = common.buildLookup
local buildRoleChoices = common.buildRoleChoices
local activeReadCache = readCache.active
local rowRecord = readCache.rowRecord
local nestedRecord = readCache.nestedRecord

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

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
        return ""
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

local function prepareRoles(instance)
    instance.roles = shallowCopyList(instance.biome.roles)
    instance.rolesByKey = buildLookup(instance.roles)
    for _, role in ipairs(instance.roles) do
        role.optionsByKey = buildLookup(optionListForRole(role))
    end
end

function rowEngine.create(adapter)
    adapter = adapter or {}

    local data = {}

    local slotForRow = adapter.slotForRow or defaultSlotForRow
    local isFixedIdentitySlot = adapter.isFixedIdentitySlot or defaultIsFixedIdentitySlot

    local function roleForRow(instance, rows, rowIndex, roleKey)
        local slot = slotForRow(instance, rowIndex)
        if adapter.roleForRow ~= nil then
            return adapter.roleForRow(instance, rowIndex, roleKey, slot, defaultRoleForRow, rows)
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

    local function isRoleLayerConfigured(instance, role)
        local layer = role and role.requiredLayer or nil
        if layer == nil then
            return true
        end
        return common.layerConfigured(instance and instance.routeContext, instance and instance.routeKey, layer)
    end

    local function routeGeneration(instance)
        local routeContext = instance and instance.routeContext or nil
        if routeContext ~= nil and routeContext.routeGeneration ~= nil then
            return routeContext:routeGeneration(instance.routeKey)
        end
        return nil
    end

    local function isRoleAllowed(instance, rows, rowIndex, roleKey, role)
        if not isRoleLayerConfigured(instance, role) then
            return false
        end
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

    function data.prepareSlots(_instance)
    end

    function data.buildRewardRows()
        return rewards.buildRows()
    end

    function data.buildRoomRows()
        return buildRoomRows()
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
        return optionLabelsForRole(instance, roleForRow(instance, nil, rowIndex, roleKey))
    end

    local function isOptionAvailableUncached(instance, rows, rowIndex, roleKey, optionKey)
        local slot = slotForRow(instance, rowIndex)
        if adapter.skipOptionsForSlot ~= nil
            and adapter.skipOptionsForSlot(instance, rows, rowIndex, slot)
        then
            return false
        end

        local role = roleForRow(instance, rows, rowIndex, roleKey)
        if role == nil then
            return false
        end

        if optionKey == "" then
            return false
        end

        local option = role.optionsByKey and role.optionsByKey[optionKey] or nil
        if option == nil then
            return false
        end
        return isOptionAllowed(instance, rows, rowIndex, roleKey, optionKey, role, option)
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
        return roleKey, roleForRow(instance, rows, rowIndex, roleKey)
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

        local role = roleForRow(instance, rows, rowIndex, roleKey)
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
        if role.requiresConcreteOption or #options > 1 then
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

    local function fillRoleValuesUncached(instance, rows, rowIndex, values)
        clearList(values)
        local slot = slotForRow(instance, rowIndex)
        if adapter.fillRoleValuesForSlot ~= nil
            and adapter.fillRoleValuesForSlot(instance, rows, rowIndex, slot, values)
        then
            return values
        end

        for _, role in ipairs(instance.roles or {}) do
            values[#values + 1] = role.key
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

        local role = roleForRow(instance, rows, rowIndex, roleKey)
        if role == nil then
            return values
        end

        for _, optionKey in ipairs(optionValuesForRole(instance, role)) do
            values[#values + 1] = optionKey
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

    local function roleAllowedValueState(instance, rows, rowIndex, roleKey, role)
        if not isRoleLayerConfigured(instance, role) then
            return valueStates.INVALID
        end
        if adapter.isRoleAllowed == nil
            or adapter.isRoleAllowed(instance, rows, rowIndex, roleKey, role, slotForRow(instance, rowIndex))
        then
            return valueStates.NORMAL
        end
        if adapter.roleDisallowedFailureCode ~= nil then
            return valueStates.forFailureCode(adapter.roleDisallowedFailureCode(
                instance,
                rows,
                rowIndex,
                roleKey,
                role,
                slotForRow(instance, rowIndex)
            ))
        end
        if adapter.roleDisallowedStatus ~= nil then
            return valueStates.forStatus(adapter.roleDisallowedStatus(
                instance,
                rows,
                rowIndex,
                roleKey,
                role,
                slotForRow(instance, rowIndex)
            ))
        end
        return valueStates.INVALID
    end

    local function optionAllowedValueState(instance, rows, rowIndex, roleKey, optionKey, role, option)
        if adapter.isOptionAllowed == nil
            or adapter.isOptionAllowed(instance, rows, rowIndex, roleKey, optionKey, role, option, slotForRow(instance, rowIndex))
        then
            return valueStates.NORMAL
        end
        if adapter.optionDisallowedFailureCode ~= nil then
            return valueStates.forFailureCode(adapter.optionDisallowedFailureCode(
                instance,
                rows,
                rowIndex,
                roleKey,
                optionKey,
                role,
                option,
                slotForRow(instance, rowIndex)
            ))
        end
        if adapter.optionDisallowedStatus ~= nil then
            return valueStates.forStatus(adapter.optionDisallowedStatus(
                instance,
                rows,
                rowIndex,
                roleKey,
                optionKey,
                role,
                option,
                slotForRow(instance, rowIndex)
            ))
        end
        return valueStates.INVALID
    end

    local function optionValueStateUncached(instance, rows, rowIndex, roleKey, optionKey)
        local slot = slotForRow(instance, rowIndex)
        if adapter.skipOptionsForSlot ~= nil
            and adapter.skipOptionsForSlot(instance, rows, rowIndex, slot)
        then
            return valueStates.HIDDEN
        end

        local role = roleForRow(instance, rows, rowIndex, roleKey)
        if role == nil then
            return valueStates.INVALID
        end

        if optionKey == "" then
            return valueStates.HIDDEN
        end

        local option = role.optionsByKey and role.optionsByKey[optionKey] or nil
        if option == nil then
            return valueStates.INVALID
        end

        local state = valueStates.NORMAL
        state = valueStates.merge(
            state,
            optionAllowedValueState(instance, rows, rowIndex, roleKey, optionKey, role, option)
        )
        return state
    end

    local function aggregateOptionValueState(instance, rows, rowIndex, roleKey, role)
        local state = valueStates.NORMAL
        local hasOption = false
        for _, optionKey in ipairs(optionValuesForRole(instance, role)) do
            if optionKey ~= "" then
                hasOption = true
                local nextState = optionValueStateUncached(instance, rows, rowIndex, roleKey, optionKey)
                if nextState == valueStates.NORMAL then
                    return valueStates.NORMAL
                end
                state = valueStates.merge(state, nextState)
            end
        end
        if hasOption then
            return state
        end
        return valueStates.INVALID
    end

    local function roleValueStateUncached(instance, rows, rowIndex, roleKey)
        local slot = slotForRow(instance, rowIndex)
        if adapter.roleAvailabilityForSlot ~= nil then
            local value = adapter.roleAvailabilityForSlot(instance, rows, rowIndex, roleKey, slot)
            if value == false then
                return valueStates.HIDDEN
            end
        end

        local role = instance.rolesByKey[roleKey]
        if role == nil then
            return valueStates.INVALID
        end
        if roleKey == VANILLA_ROLE_KEY then
            return valueStates.NORMAL
        end

        local options = optionListForRole(role)
        local optionState = valueStates.NORMAL
        if #options > 0 then
            optionState = aggregateOptionValueState(instance, rows, rowIndex, roleKey, role)
            if optionState == valueStates.HIDDEN then
                return valueStates.HIDDEN
            end
        end

        local state = roleAllowedValueState(instance, rows, rowIndex, roleKey, role)
        if #options > 0 then
            state = valueStates.merge(state, optionState)
        end
        return state
    end

    local function fillRoleValueStatesUncached(instance, rows, rowIndex, states)
        clearMap(states)
        for _, roleKey in ipairs(data.roleValuesForRow(instance, rows, rowIndex)) do
            valueStates.set(states, roleKey, roleValueStateUncached(instance, rows, rowIndex, roleKey))
        end
        return states
    end

    function data.roleValueStatesForRow(instance, rows, rowIndex)
        local cache = activeReadCache(instance)
        if cache == nil then
            local states = {}
            return fillRoleValueStatesUncached(instance, rows, rowIndex, states)
        end

        local record = rowRecord(cache.roleValueStates, rowIndex)
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.states = record.states or {}
            fillRoleValueStatesUncached(instance, rows, rowIndex, record.states)
        end
        return record.states
    end

    local function fillOptionValueStatesUncached(instance, rows, rowIndex, roleKey, states)
        clearMap(states)
        for _, optionKey in ipairs(data.optionValuesForRow(instance, rows, rowIndex, roleKey)) do
            valueStates.set(states, optionKey, optionValueStateUncached(instance, rows, rowIndex, roleKey, optionKey))
        end
        return states
    end

    function data.optionValueStatesForRow(instance, rows, rowIndex, roleKey)
        local cache = activeReadCache(instance)
        if cache == nil then
            local states = {}
            return fillOptionValueStatesUncached(instance, rows, rowIndex, roleKey, states)
        end

        local record = nestedRecord(cache.optionValueStates, rowIndex, roleKey or "")
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.states = record.states or {}
            fillOptionValueStatesUncached(instance, rows, rowIndex, roleKey, record.states)
        end
        return record.states
    end

    function data.beginReadPass(instance)
        readCache.begin(instance, routeGeneration(instance))
    end

    function data.invalidateReadPass(instance)
        readCache.invalidate(instance)
    end

    function data.endReadPass(instance)
        readCache.finish(instance)
    end

    return data
end

return rowEngine
