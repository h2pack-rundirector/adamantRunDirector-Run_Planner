local deps = ...
local common = deps.common
local timeline = deps.timeline
local rowEngine = deps.rowEngine
local valueStates = deps.valueStates
local slots = import("mods/controls/ClockworkGoalRoute/data/slots.lua", nil, {
    common = common,
})
local state = import("mods/controls/ClockworkGoalRoute/data/state.lua", nil, {
    common = common,
    slots = slots,
})
local topologyFactory = import("mods/controls/ClockworkGoalRoute/data/topology.lua", nil, {
    common = common,
    roomTopologyAdapter = deps.roomTopologyAdapter,
    roomTopology = deps.roomTopology,
    slots = slots,
})

local VANILLA_ROLE_KEY = common.VANILLA_ROLE_KEY
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus

local ROUTE_KIND_ALIAS = "RouteKindKey"
local NON_GOAL_KIND_ALIAS = "NonGoalKindKey"
local OPTION_ALIAS = "OptionKey"
local VARIANT_ALIAS = "VariantKey"
local GOAL_KIND = "Goal"
local NON_GOAL_KIND = "NonGoal"
local GOAL_COMBAT_ROLE_KEY = "GoalCombat"
local REWARD_COMBAT_ROLE_KEY = "RewardCombat"

local ROUTE_KIND_VALUES = { GOAL_KIND, NON_GOAL_KIND }
local GOAL_KIND_VALUES = { GOAL_KIND }
local VANILLA_KIND_VALUES = { VANILLA_ROLE_KEY }
local ROUTE_KIND_LABELS = {
    Goal = "Goal",
    NonGoal = "Non Goal",
}
local NON_GOAL_KIND_VALUES = {
    REWARD_COMBAT_ROLE_KEY,
    "Story",
    "Fountain",
    "Miniboss",
}

local data
local topology

local function roleKeyForRouteChoice(rows, rowIndex)
    local routeKind = rows and rows:read(rowIndex, ROUTE_KIND_ALIAS) or ""
    if routeKind == GOAL_KIND then
        return GOAL_COMBAT_ROLE_KEY
    end
    if routeKind == NON_GOAL_KIND then
        return rows and rows:read(rowIndex, NON_GOAL_KIND_ALIAS) or ""
    end
    return ""
end

local function routeKindForRoleKey(roleKey)
    if roleKey == GOAL_COMBAT_ROLE_KEY then
        return GOAL_KIND
    end
    if roleKey ~= nil and roleKey ~= "" and roleKey ~= VANILLA_ROLE_KEY then
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
        local forcedRoleKey = state.forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            return forcedRoleKey
        end
        if state.routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            return VANILLA_ROLE_KEY
        end
        return roleKeyForRouteChoice(rows, rowIndex)
    end,

    roleForRow = function(instance, rowIndex, roleKey, slot, defaultRoleForRow, rows)
        if slots.isFixedSlot(slot) then
            if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
                return slot.role
            end
            return nil
        end
        local forcedRoleKey = state.forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            if roleKey == forcedRoleKey then
                return instance.rolesByKey[forcedRoleKey]
            end
            return nil
        end
        if state.routeTerminatedBeforeRow(instance, rows, rowIndex, slot) and roleKey == VANILLA_ROLE_KEY then
            return state.inactiveRole
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(instance, rows, rowIndex, roleKey, slot)
        if slots.isFixedSlot(slot) then
            return roleKey == slot.roleKey
        end
        local forcedRoleKey = state.forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            return roleKey == forcedRoleKey
        end
        if state.routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            return roleKey == VANILLA_ROLE_KEY
        end
        return nil
    end,

    fillRoleValuesForSlot = function(instance, rows, rowIndex, slot, values)
        if slots.isFixedSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        local forcedRoleKey = state.forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            values[#values + 1] = forcedRoleKey
            return true
        end
        if state.routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            values[#values + 1] = VANILLA_ROLE_KEY
            return true
        end
        return false
    end,

    skipOptionsForSlot = function(_, _, _, slot)
        return slots.isPrebossSlot(slot)
    end,

    biomeEncounterDepthCost = function(instance, rows, rowIndex, _, _, _, _, slot)
        if state.routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            return 0
        end
        return nil
    end,

    isRoleAllowed = function(instance, rows, rowIndex, roleKey, role, slot)
        if not slots.isRouteSlot(slot) then
            return true
        end
        return state.roleIsAllowed(instance, rows, rowIndex, roleKey, role)
    end,

    isOptionAllowed = function(instance, rows, rowIndex, _, _, role, option, slot)
        if not slots.isRouteSlot(slot) then
            return true
        end
        return state.optionIsAllowed(instance, rows, rowIndex, role, option, slot)
    end,

    roleDisallowedStatus = function(instance, rows, rowIndex, roleKey, role)
        return state.roleDisallowedStatus(instance, rows, rowIndex, roleKey, role)
    end,

    roleDisallowedFailureCode = function(instance, rows, rowIndex, roleKey, role)
        return state.roleDisallowedFailureCode(instance, rows, rowIndex, roleKey, role)
    end,

    optionUnavailableMessage = function(_, _, _, _, role)
        return tostring(role.label or role.key) .. " is not valid at this step"
    end,

    validateSlot = function(instance, rows, rowIndex, roleKey, role, slot)
        if slots.isPrebossSlot(slot) then
            local goalCount = data.countGoals(instance, rows)
            if goalCount ~= state.requiredGoals(instance) then
                return invalidStatus(
                    "clockwork_goal_count",
                    "Preboss requires exactly " .. tostring(state.requiredGoals(instance)) .. " Clockwork Goal rows"
                )
            end
            return validStatus()
        end
        if not slots.isRouteSlot(slot) or roleKey == VANILLA_ROLE_KEY then
            return nil
        end
        if state.routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            return validStatus()
        end
        if not state.roleIsAllowed(instance, rows, rowIndex, roleKey, role) then
            return state.roleDisallowedStatus(instance, rows, rowIndex, roleKey, role)
        end
        return nil
    end,
}

data = rowEngine.create(adapter)
topology = topologyFactory.create(data)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.clockwork = instance.biome.clockwork or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)
    slots.buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    data.buildRoleChoices(instance)
    state.addFixedRoleLabels(instance)
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
    if routeKind == GOAL_KIND or routeKind == NON_GOAL_KIND then
        return routeKind
    end
    return routeKindForRoleKey(data.readRoleKey(instance, rows, rowIndex))
end

function data.readNonGoalKind(_instance, rows, rowIndex)
    return rows and rows:read(rowIndex, NON_GOAL_KIND_ALIAS) or ""
end

function data.routeKindValuesForRow(instance, rows, rowIndex)
    local roleValues = data.roleValuesForRow(instance, rows, rowIndex)
    if roleValues[1] == VANILLA_ROLE_KEY then
        return VANILLA_KIND_VALUES
    end
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
    states[VANILLA_ROLE_KEY] = roleStates[VANILLA_ROLE_KEY]
    return states
end

function data.nonGoalKindValueStatesForRow(instance, rows, rowIndex)
    return data.roleValueStatesForRow(instance, rows, rowIndex)
end

function data.requiredGoals(instance)
    return state.requiredGoals(instance)
end

function data.priorGoalCount(instance, rows, rowIndex)
    return state.priorGoalCount(instance, rows, rowIndex)
end

function data.maxNonGoalRewards(instance)
    return state.maxNonGoalRewards(instance)
end

function data.rewardContext(instance, _rows, rowIndex, role, option)
    return state.rewardContextForRow(instance, rowIndex, role, option, slots.slotForRow(instance, rowIndex))
end

function data.rowCountsGoal(instance, rows, rowIndex, role, option)
    return state.rowCountsGoal(instance, rows, rowIndex, role, option, slots.slotForRow(instance, rowIndex))
end

function data.rowCountsNonGoalReward(instance, rows, rowIndex, role, option)
    return state.rowCountsNonGoal(instance, rows, rowIndex, role, option, slots.slotForRow(instance, rowIndex))
end

function data.countGoals(instance, rows)
    return state.countGoals(instance, rows)
end

function data.countNonGoals(instance, rows)
    return state.countNonGoals(instance, rows)
end

function data.countStories(instance, rows)
    return state.countStories(instance, rows)
end

function data.isRouteSlot(slot)
    return slots.isRouteSlot(slot)
end

function data.isInactiveRouteRow(instance, rows, rowIndex)
    return state.routeTerminatedBeforeRow(instance, rows, rowIndex, slots.slotForRow(instance, rowIndex))
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
