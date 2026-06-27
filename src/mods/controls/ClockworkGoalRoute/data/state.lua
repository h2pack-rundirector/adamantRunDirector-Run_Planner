local deps = ...
local common = deps.common
local slots = deps.slots

local INACTIVE_ROLE_KEY = "Inactive"
local GOAL_COUNTER_KEY = "clockworkGoal"
local NON_GOAL_COUNTER_KEY = "clockworkNonGoalReward"
local STORY_COUNTER_KEY = "clockworkStory"
local ROUTE_KIND_ALIAS = "RouteKindKey"
local NON_GOAL_KIND_ALIAS = "NonGoalKindKey"
local GOAL_KIND = "Goal"
local NON_GOAL_KIND = "NonGoal"
local GOAL_COMBAT_ROLE_KEY = "GoalCombat"

local optionListForRole = common.optionListForRole
local invalidStatus = common.invalidStatus

local state = {
    INACTIVE_ROLE_KEY = INACTIVE_ROLE_KEY,
    inactiveRole = {
        key = INACTIVE_ROLE_KEY,
        label = "Inactive",
    },
}

function state.forcedRouteRoleKey(instance, slot)
    if not slots.isRouteSlot(slot) or slot.routeOrdinal ~= 1 then
        return nil
    end
    return instance.clockwork.forcedFirstRouteRole
end

function state.addFixedRoleLabels(instance)
    instance.rolesByKey[INACTIVE_ROLE_KEY] = state.inactiveRole
    instance.roleLabels[INACTIVE_ROLE_KEY] = state.inactiveRole.label
    for _, slot in ipairs(instance.routeSlots or {}) do
        if slot.roleKey ~= nil then
            instance.roleLabels[slot.roleKey] = slot.label or slot.roleKey
        end
    end
end

local function routeCounter(instance, key)
    local counters = instance.clockwork.routeCounters or {}
    return counters[key] or {}
end

local function routeCounterLimit(instance, key, fallback)
    local counter = routeCounter(instance, key)
    return tonumber(counter.maxCreationsThisRun) or fallback or 0
end

function state.requiredGoals(instance)
    return routeCounterLimit(instance, GOAL_COUNTER_KEY)
end

function state.maxNonGoalRewards(instance)
    return routeCounterLimit(instance, NON_GOAL_COUNTER_KEY)
end

function state.rewardContextForRow(_instance, _rowIndex, role, option, _slot)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function counterIncrement(source, counterKey)
    local increments = source and source.increments or nil
    if increments == nil then
        return 0
    end
    return tonumber(increments[counterKey]) or 0
end

local function rowCounterIncrement(role, option, counterKey)
    return counterIncrement(role, counterKey) + counterIncrement(option, counterKey)
end

local function rowGoalIncrement(_instance, _rows, _rowIndex, role, option, _slot)
    return rowCounterIncrement(role, option, GOAL_COUNTER_KEY)
end

local function rowNonGoalIncrement(_instance, _rows, _rowIndex, role, option, _slot)
    return rowCounterIncrement(role, option, NON_GOAL_COUNTER_KEY)
end

local function rowStoryIncrement(role, option)
    return rowCounterIncrement(role, option, STORY_COUNTER_KEY)
end

function state.rowCountsGoal(instance, rows, rowIndex, role, option, slot)
    return rowGoalIncrement(instance, rows, rowIndex, role, option, slot) > 0
end

function state.rowCountsNonGoal(instance, rows, rowIndex, role, option, slot)
    return rowNonGoalIncrement(instance, rows, rowIndex, role, option, slot) > 0
end

local function canOfferExtensionChoice(option)
    if option == nil then
        return false
    end
    if option.supportsExtensionChoice ~= nil then
        return option.supportsExtensionChoice == true
    end
    return tonumber(option.exitCount) ~= nil and tonumber(option.exitCount) > 1
end

local function requiresPreviousExtensionChoice(role)
    local requiresPrevious = role and role.requiresPrevious or nil
    return requiresPrevious ~= nil and requiresPrevious.supportsExtensionChoice == true
end

local function rowRequiresPreviousExtensionChoice(_instance, _rows, _rowIndex, role, _option, _slot)
    return requiresPreviousExtensionChoice(role)
end

local function activeReadPass(instance)
    local cache = instance and instance._readCache or nil
    if cache ~= nil and cache.active then
        return cache.pass
    end
    return nil
end

local function rawRoleKey(instance, rows, rowIndex, slot)
    if slots.isFixedSlot(slot) then
        return slot.roleKey
    end
    local forcedRoleKey = state.forcedRouteRoleKey(instance, slot)
    if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
        return forcedRoleKey
    end
    local routeKind = rows and rows:read(rowIndex, ROUTE_KIND_ALIAS) or nil
    if routeKind == GOAL_KIND then
        return GOAL_COMBAT_ROLE_KEY
    end
    if routeKind == NON_GOAL_KIND then
        local nonGoalKind = rows and rows:read(rowIndex, NON_GOAL_KIND_ALIAS) or nil
        if nonGoalKind ~= nil and nonGoalKind ~= "" then
            return nonGoalKind
        end
        return ""
    end
    return INACTIVE_ROLE_KEY
end

local function rawRoleForKey(instance, _rowIndex, roleKey, slot)
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
    return instance.rolesByKey[roleKey]
end

local function rawOptionForRole(role, rows, rowIndex)
    if role == nil then
        return "", nil
    end

    local optionKey = rows and rows:read(rowIndex, "OptionKey") or ""
    if optionKey ~= "" then
        return optionKey, role.optionsByKey and role.optionsByKey[optionKey] or nil
    end

    local options = optionListForRole(role)
    if #options == 0 or role.requiresConcreteOption or #options > 1 then
        return "", nil
    end

    local option = options[1]
    return option.key or "", option
end

local function clockworkStateCache(instance, rows)
    local pass = activeReadPass(instance)
    if pass == nil then
        return {
            rows = rows,
            byRow = {},
            volatile = true,
        }
    end

    local cache = instance._clockworkStateCache
    if cache == nil then
        cache = {
            byRow = {},
        }
        instance._clockworkStateCache = cache
    end
    if cache.pass ~= pass or cache.rows ~= rows then
        cache.pass = pass
        cache.rows = rows
        cache.built = nil
        cache.goalCount = 0
        cache.nonGoalCount = 0
        cache.storyCount = 0
    end
    return cache
end

local function canSpendBranchingRoomAt(nonGoalCount, instance, option)
    if not canOfferExtensionChoice(option) then
        return true
    end
    return nonGoalCount < state.maxNonGoalRewards(instance) - 1
end

local function buildClockworkState(instance, rows, cache)
    if cache.built then
        return cache
    end

    local goalLimit = state.requiredGoals(instance)
    local nonGoalLimit = state.maxNonGoalRewards(instance)
    local goalCount = 0
    local nonGoalCount = 0
    local storyCount = 0
    local previousSupportsExtensionChoice = false

    for rowIndex, slot in ipairs(instance.routeSlots or {}) do
        local rowState = cache.byRow[rowIndex]
        if rowState == nil then
            rowState = {}
            cache.byRow[rowIndex] = rowState
        end

        rowState.priorGoals = goalCount
        rowState.priorNonGoals = nonGoalCount
        rowState.priorStories = storyCount
        rowState.previousSupportsExtensionChoice = previousSupportsExtensionChoice
        rowState.inactive = false
        rowState.roleKey = nil
        rowState.role = nil
        rowState.optionKey = nil
        rowState.option = nil
        rowState.countsGoal = false
        rowState.countsNonGoal = false
        rowState.countsStory = false

        if slots.isRouteSlot(slot) then
            rowState.inactive = goalCount >= goalLimit and not previousSupportsExtensionChoice
            if rowState.inactive then
                rowState.roleKey = INACTIVE_ROLE_KEY
                rowState.optionKey = ""
                previousSupportsExtensionChoice = false
            else
                local roleKey = rawRoleKey(instance, rows, rowIndex, slot)
                local role = rawRoleForKey(instance, rowIndex, roleKey, slot)
                local optionKey, option = rawOptionForRole(role, rows, rowIndex)
                local goalIncrement = rowGoalIncrement(instance, rows, rowIndex, role, option, slot)
                local nonGoalIncrement = rowNonGoalIncrement(instance, rows, rowIndex, role, option, slot)
                local storyIncrement = rowStoryIncrement(role, option)
                local countsGoal = goalIncrement > 0
                local countsNonGoal = nonGoalIncrement > 0
                local countsStory = storyIncrement > 0
                local withinGoalLimit = not countsGoal or goalCount + goalIncrement <= goalLimit
                local withinNonGoalLimit = not countsNonGoal or nonGoalCount + nonGoalIncrement <= nonGoalLimit
                local hasRequiredPreviousExtensionChoice = not rowRequiresPreviousExtensionChoice(
                    instance,
                    rows,
                    rowIndex,
                    role,
                    option,
                    slot
                ) or previousSupportsExtensionChoice
                local canSpendBranch = canSpendBranchingRoomAt(nonGoalCount, instance, option)
                local supportsNextExtensionChoice = roleKey ~= INACTIVE_ROLE_KEY
                    and role ~= nil
                    and withinGoalLimit
                    and withinNonGoalLimit
                    and hasRequiredPreviousExtensionChoice
                    and canSpendBranch
                    and canOfferExtensionChoice(option)

                rowState.roleKey = roleKey
                rowState.role = role
                rowState.optionKey = optionKey
                rowState.option = option

                if countsGoal and withinGoalLimit then
                    goalCount = goalCount + goalIncrement
                    rowState.countsGoal = true
                elseif countsNonGoal and withinNonGoalLimit then
                    nonGoalCount = nonGoalCount + nonGoalIncrement
                    rowState.countsNonGoal = true
                end
                if countsStory then
                    storyCount = storyCount + storyIncrement
                    rowState.countsStory = true
                end

                previousSupportsExtensionChoice = supportsNextExtensionChoice
            end
        else
            previousSupportsExtensionChoice = false
        end
    end

    cache.goalCount = goalCount
    cache.nonGoalCount = nonGoalCount
    cache.storyCount = storyCount
    cache.built = true
    return cache
end

local function clockworkState(instance, rows)
    return buildClockworkState(instance, rows, clockworkStateCache(instance, rows))
end

local function clockworkRowState(instance, rows, rowIndex)
    local cache = clockworkState(instance, rows)
    return cache.byRow[rowIndex] or {}
end

local function countPriorGoals(instance, rows, rowIndex)
    return clockworkRowState(instance, rows, rowIndex).priorGoals or 0
end

local function countPriorNonGoals(instance, rows, rowIndex)
    return clockworkRowState(instance, rows, rowIndex).priorNonGoals or 0
end

local function previousRouteSupportsExtensionChoice(instance, rows, rowIndex)
    return clockworkRowState(instance, rows, rowIndex).previousSupportsExtensionChoice == true
end

function state.routeTerminatedBeforeRow(instance, rows, rowIndex, slot)
    return slots.isRouteSlot(slot) and clockworkRowState(instance, rows, rowIndex).inactive == true
end

function state.priorGoalCount(instance, rows, rowIndex)
    return countPriorGoals(instance, rows, rowIndex)
end

local function roleIsAllowedByCounters(instance, rows, rowIndex, roleKey, role)
    if roleKey == INACTIVE_ROLE_KEY then
        return true
    end
    local slot = slots.slotForRow(instance, rowIndex)
    if state.routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
        return false
    end
    local _, option = rawOptionForRole(role, rows, rowIndex)
    local goalIncrement = rowGoalIncrement(instance, rows, rowIndex, role, option, slot)
    if goalIncrement > 0 then
        return countPriorGoals(instance, rows, rowIndex) + goalIncrement <= state.requiredGoals(instance)
    end
    local nonGoalIncrement = rowNonGoalIncrement(instance, rows, rowIndex, role, option, slot)
    if nonGoalIncrement > 0 then
        return countPriorNonGoals(instance, rows, rowIndex) + nonGoalIncrement <= state.maxNonGoalRewards(instance)
    end
    return true
end

function state.roleIsAllowed(instance, rows, rowIndex, roleKey, role)
    if not roleIsAllowedByCounters(instance, rows, rowIndex, roleKey, role) then
        return false
    end
    local slot = slots.slotForRow(instance, rowIndex)
    local _, option = rawOptionForRole(role, rows, rowIndex)
    if rowRequiresPreviousExtensionChoice(instance, rows, rowIndex, role, option, slot)
        and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex)
    then
        return false
    end
    return true
end

function state.optionIsAllowed(instance, rows, rowIndex, role, option, slot)
    local priorNonGoals = countPriorNonGoals(instance, rows, rowIndex)
    local nonGoalIncrement = rowNonGoalIncrement(instance, rows, rowIndex, role, option, slot)
    if nonGoalIncrement > 0 and priorNonGoals + nonGoalIncrement > state.maxNonGoalRewards(instance) then
        return false
    end
    if not canSpendBranchingRoomAt(priorNonGoals, instance, option) then
        return false
    end
    if rowRequiresPreviousExtensionChoice(instance, rows, rowIndex, role, option, slot)
        and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex)
    then
        return false
    end
    return true
end

function state.roleDisallowedStatus(instance, rows, rowIndex, roleKey, role)
    local slot = slots.slotForRow(instance, rowIndex)
    local _, option = rawOptionForRole(role, rows, rowIndex)
    if rowRequiresPreviousExtensionChoice(instance, rows, rowIndex, role, option, slot)
        and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex)
    then
        return invalidStatus(
            "clockwork_previous_extension_choice",
            tostring(role.label or roleKey) .. " requires a previous planned room with an extension choice"
        )
    end
    if rowGoalIncrement(instance, rows, rowIndex, role, option, slot) > 0 then
        return invalidStatus(
            "clockwork_goal_limit",
            "Clockwork Goal is already planned " .. tostring(state.requiredGoals(instance)) .. " times"
        )
    end
    if rowNonGoalIncrement(instance, rows, rowIndex, role, option, slot) > 0 then
        return invalidStatus(
            "clockwork_extension_budget",
            "Clockwork non-goal rewards are already planned "
                .. tostring(state.maxNonGoalRewards(instance))
                .. " times"
        )
    end
    return invalidStatus(
        "clockwork_route_complete",
        "Clockwork route is complete after the fifth goal"
    )
end

function state.roleDisallowedFailureCode(instance, rows, rowIndex, _roleKey, role)
    local slot = slots.slotForRow(instance, rowIndex)
    local _, option = rawOptionForRole(role, rows, rowIndex)
    if rowRequiresPreviousExtensionChoice(instance, rows, rowIndex, role, option, slot)
        and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex)
    then
        return "clockwork_previous_extension_choice"
    end
    if rowGoalIncrement(instance, rows, rowIndex, role, option, slot) > 0 then
        return "clockwork_goal_limit"
    end
    if rowNonGoalIncrement(instance, rows, rowIndex, role, option, slot) > 0 then
        return "clockwork_extension_budget"
    end
    return "clockwork_route_complete"
end

function state.countGoals(instance, rows)
    return clockworkState(instance, rows).goalCount or 0
end

function state.countNonGoals(instance, rows)
    return clockworkState(instance, rows).nonGoalCount or 0
end

function state.countStories(instance, rows)
    return clockworkState(instance, rows).storyCount or 0
end

return state
