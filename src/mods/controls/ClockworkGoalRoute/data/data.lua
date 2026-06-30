local deps = ...
local common = deps.common
local rowData = deps.rowData
local valueStates = deps.valueStates
local slotTimeline = deps.slotTimeline
local slots = import("mods/controls/ClockworkGoalRoute/data/slots.lua", nil, {
    common = common,
})
local topologyFactory = import("mods/controls/ClockworkGoalRoute/data/topology.lua", nil, {
    common = common,
    roomTopology = deps.roomTopology,
    topologyControls = deps.topologyControls,
    slots = slots,
})

local ROUTE_KIND_ALIAS = "RouteKindKey"
local NON_GOAL_KIND_ALIAS = "NonGoalKindKey"
local OPTION_ALIAS = "OptionKey"
local VARIANT_ALIAS = "VariantKey"
local GOAL_KIND = "Goal"
local NON_GOAL_KIND = "NonGoal"
local PREBOSS_KIND = "Preboss"
local GOAL_COMBAT_ROLE_KEY = "GoalCombat"
local REWARD_COMBAT_ROLE_KEY = "RewardCombat"

local ROUTE_KIND_VALUES = { GOAL_KIND, NON_GOAL_KIND, PREBOSS_KIND }
local GOAL_KIND_VALUES = { GOAL_KIND }
local ROUTE_KIND_LABELS = {
    Goal = "Goal",
    NonGoal = "Non Goal",
    Preboss = "Preboss",
}
local NON_GOAL_KIND_VALUES = {
    REWARD_COMBAT_ROLE_KEY,
    "Story",
    "Fountain",
    "Miniboss",
}

local data
local topology

local function forcedRouteRoleKey(instance, slot)
    if not slots.isRouteSlot(slot) or slot.routeOrdinal ~= 1 then
        return nil
    end
    return instance.clockwork.forcedFirstRouteRole
end

local function addFixedRoleLabels(instance)
    for _, slot in ipairs(instance.routeSlots or {}) do
        if slot.roleKey ~= nil then
            instance.roleLabels[slot.roleKey] = slot.label or slot.roleKey
        end
    end
end

local function rewardContextForRow(role, option)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function roleKeyForRouteChoice(rows, rowIndex)
    local routeKind = rows and rows:read(rowIndex, ROUTE_KIND_ALIAS) or ""
    if routeKind == GOAL_KIND then
        return GOAL_COMBAT_ROLE_KEY
    end
    if routeKind == NON_GOAL_KIND then
        return rows and rows:read(rowIndex, NON_GOAL_KIND_ALIAS) or ""
    end
    if routeKind == PREBOSS_KIND then
        return PREBOSS_KIND
    end
    return ""
end

local function routeKindForRoleKey(roleKey)
    if roleKey == GOAL_COMBAT_ROLE_KEY then
        return GOAL_KIND
    end
    if roleKey == PREBOSS_KIND then
        return PREBOSS_KIND
    end
    if roleKey ~= nil and roleKey ~= "" then
        return NON_GOAL_KIND
    end
    return roleKey or ""
end

local function buildRoomRows()
    return {
        { key = ROUTE_KIND_ALIAS, type = "string", default = "", maxLen = 32 },
        { key = NON_GOAL_KIND_ALIAS, type = "string", default = "", maxLen = 32 },
        { key = OPTION_ALIAS, type = "string", default = "", maxLen = 64 },
        { key = VARIANT_ALIAS, type = "string", default = "", maxLen = 64 },
    }
end

local function aggregateAlternativeValueState(states, values)
    local mergedState = nil
    local allHidden = true
    for _, key in ipairs(values) do
        local valueState = states[key]
        if valueState == nil or valueState == valueStates.NORMAL then
            return nil
        end
        if valueState ~= valueStates.HIDDEN then
            allHidden = false
            mergedState = valueStates.merge(mergedState, valueState)
        end
    end
    if allHidden then
        return valueStates.HIDDEN
    end
    return mergedState
end

local adapter = {
    slotForRow = slots.slotForRow,
    isFixedIdentitySlot = slots.isFixedSlot,

    readRoleKey = function(instance, rows, rowIndex, slot, _defaultReadRoleKey)
        if slots.isFixedSlot(slot) then
            return slot.roleKey
        end
        local forcedRoleKey = forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            return forcedRoleKey
        end
        return roleKeyForRouteChoice(rows, rowIndex)
    end,

    roleForRow = function(instance, rowIndex, roleKey, slot, defaultRoleForRow, _rows)
        if slots.isFixedSlot(slot) then
            if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
                return slot.role
            end
            return nil
        end
        local forcedRoleKey = forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            if roleKey == forcedRoleKey then
                return instance.rolesByKey[forcedRoleKey]
            end
            return nil
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(instance, _rows, _rowIndex, roleKey, slot)
        if slots.isFixedSlot(slot) then
            return roleKey == slot.roleKey
        end
        local forcedRoleKey = forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            return roleKey == forcedRoleKey
        end
        return nil
    end,

    fillRoleValuesForSlot = function(instance, _rows, _rowIndex, slot, values)
        if slots.isFixedSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        local forcedRoleKey = forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            values[#values + 1] = forcedRoleKey
            return true
        end
        return false
    end,

    skipOptionsForSlot = function(_, _, _, slot)
        return slots.isPrebossSlot(slot)
    end,

}

data = rowData.create(adapter)
topology = topologyFactory.create(data)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.clockwork = instance.biome.clockwork or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)
    slots.buildRouteSlots(instance)
    slotTimeline.applyRouteSlots(instance)
    data.buildRoleChoices(instance)
    addFixedRoleLabels(instance)
    data.prepareSlots(instance)
    topology.prepareSiblingStructurePolicy(instance)
    topology.prepareSiblingStructureCount(instance)
    return instance
end

function data.storage(instance)
    local roomRows = buildRoomRows()
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

function data.routeKindAlias()
    return ROUTE_KIND_ALIAS
end

function data.nonGoalKindAlias()
    return NON_GOAL_KIND_ALIAS
end

function data.optionAlias()
    return OPTION_ALIAS
end

function data.routeKindLabels()
    return ROUTE_KIND_LABELS
end

function data.nonGoalKindLabels(instance)
    return instance.roleLabels
end

function data.readRouteKind(instance, rows, rowIndex)
    local routeKind = rows and rows:read(rowIndex, ROUTE_KIND_ALIAS) or ""
    if routeKind == GOAL_KIND or routeKind == NON_GOAL_KIND or routeKind == PREBOSS_KIND then
        return routeKind
    end
    return routeKindForRoleKey(data.readRoleKey(instance, rows, rowIndex))
end

function data.readNonGoalKind(_instance, rows, rowIndex)
    return rows and rows:read(rowIndex, NON_GOAL_KIND_ALIAS) or ""
end

function data.routeKindValuesForRow(instance, rows, rowIndex)
    local roleValues = data.roleValuesForRow(instance, rows, rowIndex)
    if roleValues[1] == GOAL_COMBAT_ROLE_KEY and roleValues[2] == nil then
        return GOAL_KIND_VALUES
    end
    return ROUTE_KIND_VALUES
end

function data.nonGoalKindValuesForRow()
    return NON_GOAL_KIND_VALUES
end

function data.routeKindValueStatesForRow(instance, rows, rowIndex)
    local roleStates = data.roleValueStatesForRow(instance, rows, rowIndex)
    instance.clockworkRouteKindValueStatesByRow = instance.clockworkRouteKindValueStatesByRow or {}
    local states = instance.clockworkRouteKindValueStatesByRow[rowIndex]
    if states == nil then
        states = {}
        instance.clockworkRouteKindValueStatesByRow[rowIndex] = states
    end
    states[GOAL_KIND] = roleStates[GOAL_COMBAT_ROLE_KEY]
    states[NON_GOAL_KIND] = aggregateAlternativeValueState(roleStates, NON_GOAL_KIND_VALUES)
    states[PREBOSS_KIND] = roleStates[PREBOSS_KIND]
    return states
end

function data.nonGoalKindValueStatesForRow(instance, rows, rowIndex)
    return data.roleValueStatesForRow(instance, rows, rowIndex)
end

function data.rewardContext(_instance, _rows, _rowIndex, role, option)
    return rewardContextForRow(role, option)
end

function data.isRouteSlot(slot)
    return slots.isRouteSlot(slot)
end

function data.maxSiblingStructureCount(instance)
    return topology.maxSiblingStructureCount(instance)
end

function data.siblingStructureAlias(instance, siblingIndex)
    return topology.siblingStructureAlias(instance, siblingIndex)
end

function data.siblingStructureLabels(instance)
    return topology.siblingStructureLabels(instance)
end

function data.siblingStructureValues(instance)
    return topology.siblingStructureValues(instance)
end

function data.siblingStructureStatus(instance, rows, rowIndex)
    return topology.siblingStructureStatus(instance, rows, rowIndex)
end

function data.siblingTopologyStatus(instance, rows, rowIndex)
    return topology.siblingTopologyStatus(instance, rows, rowIndex)
end

function data.activeSiblingStructureCount(instance, rows, rowIndex)
    return topology.activeSiblingStructureCount(instance, rows, rowIndex)
end

function data.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
    return topology.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
end

function data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
    return topology.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
end

function data.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
    return topology.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
end

function data.validateRoomTopology(instance, rows, rowIndex)
    return topology.validateRoomTopology(instance, rows, rowIndex)
end

function data.roomTopology(instance, rows, rowIndex)
    return topology.roomTopology(instance, rows, rowIndex)
end

return data
