local deps = ...
local common = deps.common
local timeline = deps.timeline
local rowEngine = deps.rowEngine
local slots = import("mods/controls/ClockworkGoalRoute/data/slots.lua", nil, {
    common = common,
})
local state = import("mods/controls/ClockworkGoalRoute/data/state.lua", nil, {
    common = common,
    slots = slots,
})

local VANILLA_ROLE_KEY = common.VANILLA_ROLE_KEY
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus

local data

local adapter = {
    slotForRow = slots.slotForRow,
    isFixedIdentitySlot = slots.isFixedSlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
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
        return defaultReadRoleKey(instance, rows, rowIndex, slot)
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
            if goalCount ~= state.requiredGoalRewards(instance) then
                return invalidStatus(
                    "clockwork_goal_count",
                    "Preboss requires exactly " .. tostring(state.requiredGoalRewards(instance)) .. " Clockwork Goal rows"
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

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.clockwork = instance.biome.clockwork or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    state.prepareForcedFirstRouteReward(instance)
    data.prepareRoles(instance)
    slots.buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    data.buildRoleChoices(instance)
    state.addFixedRoleLabels(instance)
    data.prepareSlots(instance)
    return instance
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
    }
end

function data.requiredGoalRewards(instance)
    return state.requiredGoalRewards(instance)
end

function data.maxNonGoalRewards(instance)
    return state.maxNonGoalRewards(instance)
end

function data.rewardContext(instance, _rows, rowIndex, role, option)
    return state.rewardContextForRow(instance, rowIndex, role, option, slots.slotForRow(instance, rowIndex))
end

function data.rowCountsGoalReward(instance, rows, rowIndex, role, option)
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

return data
