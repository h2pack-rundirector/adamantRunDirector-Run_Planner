local deps = ...
local common = deps.common
local timeline = deps.timeline
local rowEngine = deps.rowEngine

local VANILLA_ROLE_KEY = common.VANILLA_ROLE_KEY
local GOAL_ROLE_KEY = "Goal"
local PREBOSS_ROLE_KEY = "Preboss"
local GOAL_COUNTER_KEY = "clockworkGoal"
local NON_GOAL_COUNTER_KEY = "clockworkNonGoalReward"
local STORY_COUNTER_KEY = "clockworkStory"

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local buildOptionChoices = common.buildOptionChoices
local optionListForRole = common.optionListForRole
local shouldOfferAutoOption = common.shouldOfferAutoOption
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
local fixedBiomeDepthCacheCost = common.fixedBiomeDepthCacheCost
local routeBiomeDepthCacheCost = common.routeBiomeDepthCacheCost
local routeStartOrdinal = common.routeStartOrdinal
local routeEndOrdinal = common.routeEndOrdinal
local routeRowLabel = common.routeRowLabel
local applySlotDepthContext = common.applySlotDepthContext

local data
local routeTerminatedBeforeRow

local function slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function isFixedSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function isRouteSlot(slot)
    return slot ~= nil and slot.kind == "biomeRow"
end

local function forcedRouteRoleKey(instance, slot)
    if not isRouteSlot(slot) or slot.routeOrdinal ~= 1 then
        return nil
    end
    return instance.clockwork.forcedFirstRouteRole
end

local function isPrebossSlot(slot)
    return slot ~= nil and slot.kind == "preboss"
end

local function buildFixedSlot(instance, entry, kind, defaultKey)
    local roomOptions = shallowCopyList(entry.roomOptions)
    local key = entry.key or defaultKey or kind
    local role = {
        key = key,
        label = entry.label or key,
        roomKey = entry.roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = entry.reward,
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    }
    if kind == "preboss" then
        role.roomOptions = nil
        role.optionsByKey = nil
    else
        buildOptionChoices(role)
    end

    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = entry.routeOrdinal or 0,
        kind = kind or entry.kind or "fixed",
        isBiomeEntry = entry.isBiomeEntry == true,
        label = entry.label or key,
        roomKey = entry.roomKey,
        roomOptions = roomOptions,
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

local function buildRouteSlot(instance, ordinal)
    local slotLayout = instance.biome.slotLayout or {}
    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = ordinal,
        kind = "biomeRow",
        label = routeRowLabel(slotLayout, ordinal, "Step"),
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
        buildFixedSlot(instance, entry, entry.kind or "intro", entry.key or "Intro")
    end
    for ordinal = startOrdinal, endOrdinal do
        buildRouteSlot(instance, ordinal)
    end
    for _, entry in ipairs(slotLayout.fixedAfterGoals or {}) do
        buildFixedSlot(instance, entry, "preboss", PREBOSS_ROLE_KEY)
    end
    instance.routeRowCount = #instance.routeSlots
end

local function copyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function normalizeGoalRole(instance)
    local role = instance.rolesByKey and instance.rolesByKey[GOAL_ROLE_KEY] or nil
    if role == nil or role.mapOptions == nil then
        return
    end

    local normalized = copyTable(role)
    normalized.mapOptions = {}
    for index, option in ipairs(role.mapOptions) do
        local optionCopy = copyTable(option)
        optionCopy.reward = nil
        normalized.mapOptions[index] = optionCopy
    end
    normalized.optionsByKey = buildLookup(normalized.mapOptions)

    for index, item in ipairs(instance.roles) do
        if item.key == GOAL_ROLE_KEY then
            instance.roles[index] = normalized
            break
        end
    end
    instance.rolesByKey[GOAL_ROLE_KEY] = normalized
end

local function addFixedRoleLabels(instance)
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

local function requiredGoalRewards(instance)
    return routeCounterLimit(instance, GOAL_COUNTER_KEY)
end

local function maxNonGoalRewards(instance)
    return routeCounterLimit(instance, NON_GOAL_COUNTER_KEY)
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

local function rowGoalIncrement(role, option)
    return rowCounterIncrement(role, option, GOAL_COUNTER_KEY)
end

local function rowNonGoalIncrement(role, option)
    return rowCounterIncrement(role, option, NON_GOAL_COUNTER_KEY)
end

local function rowStoryIncrement(role, option)
    return rowCounterIncrement(role, option, STORY_COUNTER_KEY)
end

local function rowCountsGoal(role, option)
    return rowGoalIncrement(role, option) > 0
end

local function rowCountsNonGoal(role, option)
    return rowNonGoalIncrement(role, option) > 0
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

local function activeReadPass(instance)
    local cache = instance and instance._readCache or nil
    if cache ~= nil and cache.active then
        return cache.pass
    end
    return nil
end

local function rawRoleKey(instance, rows, rowIndex, slot)
    if isFixedSlot(slot) then
        return slot.roleKey
    end
    local forcedRoleKey = forcedRouteRoleKey(instance, slot)
    if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
        return forcedRoleKey
    end
    local roleKey = rows and rows:read(rowIndex, "RoleKey") or nil
    if roleKey == nil or roleKey == "" then
        return VANILLA_ROLE_KEY
    end
    return roleKey
end

local function rawRoleForKey(instance, _rowIndex, roleKey, slot)
    if isFixedSlot(slot) then
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
    if #options == 0 or role.requiresConcreteOption then
        return "", nil
    end
    if shouldOfferAutoOption(role, options) then
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
    return nonGoalCount < maxNonGoalRewards(instance) - 1
end

local function buildClockworkState(instance, rows, cache)
    if cache.built then
        return cache
    end

    local goalLimit = requiredGoalRewards(instance)
    local nonGoalLimit = maxNonGoalRewards(instance)
    local goalCount = 0
    local nonGoalCount = 0
    local storyCount = 0
    local previousSupportsExtensionChoice = false

    for rowIndex, slot in ipairs(instance.routeSlots or {}) do
        local state = cache.byRow[rowIndex]
        if state == nil then
            state = {}
            cache.byRow[rowIndex] = state
        end

        state.priorGoals = goalCount
        state.priorNonGoals = nonGoalCount
        state.priorStories = storyCount
        state.previousSupportsExtensionChoice = previousSupportsExtensionChoice
        state.inactive = false
        state.roleKey = nil
        state.role = nil
        state.optionKey = nil
        state.option = nil
        state.countsGoal = false
        state.countsNonGoal = false
        state.countsStory = false

        if isRouteSlot(slot) then
            state.inactive = goalCount >= goalLimit and not previousSupportsExtensionChoice
            if state.inactive then
                state.roleKey = VANILLA_ROLE_KEY
                state.optionKey = ""
                previousSupportsExtensionChoice = false
            else
                local roleKey = rawRoleKey(instance, rows, rowIndex, slot)
                local role = rawRoleForKey(instance, rowIndex, roleKey, slot)
                local optionKey, option = rawOptionForRole(role, rows, rowIndex)
                local goalIncrement = rowGoalIncrement(role, option)
                local nonGoalIncrement = rowNonGoalIncrement(role, option)
                local storyIncrement = rowStoryIncrement(role, option)
                local countsGoal = goalIncrement > 0
                local countsNonGoal = nonGoalIncrement > 0
                local countsStory = storyIncrement > 0
                local withinGoalLimit = not countsGoal or goalCount + goalIncrement <= goalLimit
                local withinNonGoalLimit = not countsNonGoal or nonGoalCount + nonGoalIncrement <= nonGoalLimit
                local hasRequiredPreviousExtensionChoice = not requiresPreviousExtensionChoice(role) or previousSupportsExtensionChoice
                local canSpendBranch = canSpendBranchingRoomAt(nonGoalCount, instance, option)
                local supportsNextExtensionChoice = roleKey ~= VANILLA_ROLE_KEY
                    and role ~= nil
                    and withinGoalLimit
                    and withinNonGoalLimit
                    and hasRequiredPreviousExtensionChoice
                    and canSpendBranch
                    and canOfferExtensionChoice(option)

                state.roleKey = roleKey
                state.role = role
                state.optionKey = optionKey
                state.option = option

                if countsGoal and withinGoalLimit then
                    goalCount = goalCount + goalIncrement
                    state.countsGoal = true
                elseif countsNonGoal and withinNonGoalLimit then
                    nonGoalCount = nonGoalCount + nonGoalIncrement
                    state.countsNonGoal = true
                end
                if countsStory then
                    storyCount = storyCount + storyIncrement
                    state.countsStory = true
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

routeTerminatedBeforeRow = function(instance, rows, rowIndex, slot)
    return isRouteSlot(slot) and clockworkRowState(instance, rows, rowIndex).inactive == true
end

local function roleIsAllowedByCounters(instance, rows, rowIndex, roleKey, role)
    if roleKey == VANILLA_ROLE_KEY then
        return true
    end
    if routeTerminatedBeforeRow(instance, rows, rowIndex, slotForRow(instance, rowIndex)) then
        return false
    end
    local goalIncrement = rowGoalIncrement(role)
    if goalIncrement > 0 then
        return countPriorGoals(instance, rows, rowIndex) + goalIncrement <= requiredGoalRewards(instance)
    end
    local nonGoalIncrement = rowNonGoalIncrement(role)
    if nonGoalIncrement > 0 then
        return countPriorNonGoals(instance, rows, rowIndex) + nonGoalIncrement <= maxNonGoalRewards(instance)
    end
    return true
end

local function roleIsAllowed(instance, rows, rowIndex, roleKey, role)
    if not roleIsAllowedByCounters(instance, rows, rowIndex, roleKey, role) then
        return false
    end
    if requiresPreviousExtensionChoice(role) and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex) then
        return false
    end
    return true
end

local function roleDisallowedStatus(instance, rows, rowIndex, roleKey, role)
    if requiresPreviousExtensionChoice(role) and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex) then
        return invalidStatus(
            "clockwork_previous_extension_choice",
            tostring(role.label or roleKey) .. " requires a previous planned room with an extension choice"
        )
    end
    if rowGoalIncrement(role) > 0 then
        return invalidStatus(
            "clockwork_goal_limit",
            "Clockwork Goal is already planned " .. tostring(requiredGoalRewards(instance)) .. " times"
        )
    end
    if rowNonGoalIncrement(role) > 0 then
        return invalidStatus(
            "clockwork_extension_budget",
            "Clockwork non-goal rewards are already planned " .. tostring(maxNonGoalRewards(instance)) .. " times"
        )
    end
    return invalidStatus(
        "clockwork_route_complete",
        "Clockwork route is complete after the fifth goal"
    )
end

local function roleDisallowedFailureCode(instance, rows, rowIndex, _roleKey, role)
    if requiresPreviousExtensionChoice(role) and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex) then
        return "clockwork_previous_extension_choice"
    end
    if rowGoalIncrement(role) > 0 then
        return "clockwork_goal_limit"
    end
    if rowNonGoalIncrement(role) > 0 then
        return "clockwork_extension_budget"
    end
    return "clockwork_route_complete"
end

local adapter = {
    slotForRow = slotForRow,
    isFixedIdentitySlot = isFixedSlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
        if isFixedSlot(slot) then
            return slot.roleKey
        end
        local forcedRoleKey = forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            return forcedRoleKey
        end
        if routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            return VANILLA_ROLE_KEY
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
        local forcedRoleKey = forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            if roleKey == forcedRoleKey then
                return instance.rolesByKey[forcedRoleKey]
            end
            return nil
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(instance, rows, rowIndex, roleKey, slot)
        if isFixedSlot(slot) then
            return roleKey == slot.roleKey
        end
        local forcedRoleKey = forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            return roleKey == forcedRoleKey
        end
        if routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            return roleKey == VANILLA_ROLE_KEY
        end
        return nil
    end,

    fillRoleValuesForSlot = function(instance, rows, rowIndex, slot, values)
        if isFixedSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        local forcedRoleKey = forcedRouteRoleKey(instance, slot)
        if forcedRoleKey ~= nil and forcedRoleKey ~= "" then
            values[#values + 1] = forcedRoleKey
            return true
        end
        if routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            values[#values + 1] = VANILLA_ROLE_KEY
            return true
        end
        return false
    end,

    skipOptionsForSlot = function(_, _, _, slot)
        return isPrebossSlot(slot)
    end,

    biomeEncounterDepthCost = function(instance, rows, rowIndex, _, _, _, _, slot)
        if routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            return 0
        end
        return nil
    end,

    isRoleAllowed = function(instance, rows, rowIndex, roleKey, role, slot)
        if not isRouteSlot(slot) then
            return true
        end
        return roleIsAllowed(instance, rows, rowIndex, roleKey, role)
    end,

    isOptionAllowed = function(instance, rows, rowIndex, _, _, role, option, slot)
        if not isRouteSlot(slot) then
            return true
        end
        local priorNonGoals = countPriorNonGoals(instance, rows, rowIndex)
        local nonGoalIncrement = rowNonGoalIncrement(role, option)
        if nonGoalIncrement > 0 and priorNonGoals + nonGoalIncrement > maxNonGoalRewards(instance) then
            return false
        end
        if not canSpendBranchingRoomAt(priorNonGoals, instance, option) then
            return false
        end
        if requiresPreviousExtensionChoice(role) and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex) then
            return false
        end
        return true
    end,

    roleDisallowedStatus = function(instance, rows, rowIndex, roleKey, role)
        return roleDisallowedStatus(instance, rows, rowIndex, roleKey, role)
    end,

    roleDisallowedFailureCode = function(instance, rows, rowIndex, roleKey, role)
        return roleDisallowedFailureCode(instance, rows, rowIndex, roleKey, role)
    end,

    optionUnavailableMessage = function(_, _, _, _, role)
        return tostring(role.label or role.key) .. " is not valid at this step"
    end,

    validateSlot = function(instance, rows, rowIndex, roleKey, role, slot)
        if isPrebossSlot(slot) then
            local goalCount = data.countGoals(instance, rows)
            if goalCount ~= requiredGoalRewards(instance) then
                return invalidStatus(
                    "clockwork_goal_count",
                    "Preboss requires exactly " .. tostring(requiredGoalRewards(instance)) .. " Clockwork Goal rows"
                )
            end
            return validStatus()
        end
        if not isRouteSlot(slot) or roleKey == VANILLA_ROLE_KEY then
            return nil
        end
        if routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
            return validStatus()
        end
        if not roleIsAllowed(instance, rows, rowIndex, roleKey, role) then
            return roleDisallowedStatus(instance, rows, rowIndex, roleKey, role)
        end

        if requiresPreviousExtensionChoice(role) and not previousRouteSupportsExtensionChoice(instance, rows, rowIndex) then
            return invalidStatus(
                "clockwork_previous_extension_choice",
                tostring(role.label or roleKey) .. " requires a previous planned room with an extension choice"
            )
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
    data.prepareRoles(instance)
    normalizeGoalRole(instance)
    buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    data.buildRoleChoices(instance)
    addFixedRoleLabels(instance)
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
    return requiredGoalRewards(instance)
end

function data.maxNonGoalRewards(instance)
    return maxNonGoalRewards(instance)
end

function data.rowCountsGoalReward(role, option)
    return rowCountsGoal(role, option)
end

function data.rowCountsNonGoalReward(role, option)
    return rowCountsNonGoal(role, option)
end

function data.countGoals(instance, rows)
    return clockworkState(instance, rows).goalCount or 0
end

function data.countNonGoals(instance, rows)
    return clockworkState(instance, rows).nonGoalCount or 0
end

function data.countStories(instance, rows)
    return clockworkState(instance, rows).storyCount or 0
end

function data.isRouteSlot(slot)
    return isRouteSlot(slot)
end

function data.isInactiveRouteRow(instance, rows, rowIndex)
    return routeTerminatedBeforeRow(instance, rows, rowIndex, slotForRow(instance, rowIndex))
end

return data
