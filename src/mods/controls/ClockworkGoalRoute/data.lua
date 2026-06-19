local deps = ...
local common = deps.common
local timeline = deps.timeline
local rowEngine = deps.rowEngine

local VANILLA_ROLE_KEY = common.VANILLA_ROLE_KEY
local GOAL_ROLE_KEY = "Goal"
local PREBOSS_ROLE_KEY = "Preboss"

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local buildOptionChoices = common.buildOptionChoices
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
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
    return slot ~= nil and slot.kind == "clockworkRoute"
end

local function forcedRouteRoleKey(instance, slot)
    if not isRouteSlot(slot) or slot.routeRow ~= 1 then
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
        coordinate = entry.coordinate or 0,
        kind = kind or entry.kind or "fixed",
        label = entry.label or key,
        roomKey = entry.roomKey,
        roomOptions = roomOptions,
        roleKey = role.key,
        role = role,
        locked = entry.locked,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    }, entry)
end

local function buildRouteSlot(instance, row)
    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        coordinate = row,
        routeRow = row,
        kind = "clockworkRoute",
        label = "Step " .. tostring(row),
    }, instance.biome.slotLayout and instance.biome.slotLayout.default or nil)
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startRow = math.floor(tonumber(slotLayout.routeStartRow) or 1)
    local endRow = math.floor(tonumber(slotLayout.routeEndRow) or startRow)
    if endRow < startRow then
        endRow = startRow
    end

    instance.routeSlots = {}
    for _, entry in ipairs(slotLayout.fixedBeforeRoute or {}) do
        buildFixedSlot(instance, entry, entry.kind or "intro", entry.key or "Intro")
    end
    for row = startRow, endRow do
        buildRouteSlot(instance, row)
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

local function requiredGoalRewards(instance)
    return tonumber(instance.clockwork.requiredGoalRewards) or 0
end

local function maxNonGoalRewards(instance)
    local budget = instance.clockwork.extensionRewardBudget or {}
    return tonumber(budget.max) or 0
end

local function roleForCount(instance, rows, rowIndex)
    local roleKey, role = data.resolveRole(instance, rows, rowIndex)
    return roleKey, role
end

local function optionForCount(instance, rows, rowIndex, roleKey)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return option
end

local function rowCountsGoal(roleKey, role)
    return roleKey == GOAL_ROLE_KEY or (role ~= nil and role.countsGoalReward == true)
end

local function rowCountsNonGoal(role, option)
    return role ~= nil and role.countsNonGoalReward == true
        or option ~= nil and option.countsNonGoalReward == true
end

local function activeReadPass(instance)
    local cache = instance and instance._readCache or nil
    if cache ~= nil and cache.active then
        return cache.pass
    end
    return nil
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function countCache(instance, rows)
    local pass = activeReadPass(instance)
    if pass == nil then
        return nil
    end

    local cache = instance._clockworkCountCache
    if cache == nil then
        cache = {
            priorGoals = {},
            priorNonGoals = {},
        }
        instance._clockworkCountCache = cache
    end
    if cache.pass ~= pass or cache.rows ~= rows then
        cache.pass = pass
        cache.rows = rows
        clearMap(cache.priorGoals)
        clearMap(cache.priorNonGoals)
    end
    return cache
end

local function countPriorGoals(instance, rows, rowIndex)
    local cache = countCache(instance, rows)
    if cache ~= nil and cache.priorGoals[rowIndex] ~= nil then
        return cache.priorGoals[rowIndex]
    end

    local count = 0
    local startIndex = 1
    if cache ~= nil and rowIndex > 1 then
        count = countPriorGoals(instance, rows, rowIndex - 1)
        startIndex = rowIndex - 1
    end

    for priorIndex = startIndex, rowIndex - 1 do
        local roleKey, role = roleForCount(instance, rows, priorIndex)
        if rowCountsGoal(roleKey, role) then
            count = count + 1
        end
    end
    if cache ~= nil then
        cache.priorGoals[rowIndex] = count
    end
    return count
end

local function goalsCompleteBeforeRow(instance, rows, rowIndex, slot)
    return isRouteSlot(slot)
        and countPriorGoals(instance, rows, rowIndex) >= requiredGoalRewards(instance)
end

local function countPriorNonGoals(instance, rows, rowIndex)
    local cache = countCache(instance, rows)
    if cache ~= nil and cache.priorNonGoals[rowIndex] ~= nil then
        return cache.priorNonGoals[rowIndex]
    end

    local count = 0
    local startIndex = 1
    if cache ~= nil and rowIndex > 1 then
        count = countPriorNonGoals(instance, rows, rowIndex - 1)
        startIndex = rowIndex - 1
    end

    for priorIndex = startIndex, rowIndex - 1 do
        local roleKey, role = roleForCount(instance, rows, priorIndex)
        local option = optionForCount(instance, rows, priorIndex, roleKey)
        if rowCountsNonGoal(role, option) then
            count = count + 1
        end
    end
    if cache ~= nil then
        cache.priorNonGoals[rowIndex] = count
    end
    return count
end

local function countRouteRows(instance, rows, predicate)
    local count = 0
    local goalLimit = requiredGoalRewards(instance)
    for rowIndex, slot in ipairs(instance.routeSlots or {}) do
        if isRouteSlot(slot) then
            if routeTerminatedBeforeRow(instance, rows, rowIndex, slot) then
                break
            end
            local roleKey, role = roleForCount(instance, rows, rowIndex)
            local option = optionForCount(instance, rows, rowIndex, roleKey)
            local shouldCount = true
            if rowCountsGoal(roleKey, role) then
                shouldCount = countPriorGoals(instance, rows, rowIndex) < goalLimit
            elseif rowCountsNonGoal(role, option) then
                shouldCount = countPriorNonGoals(instance, rows, rowIndex) < maxNonGoalRewards(instance)
            end
            if shouldCount and predicate(roleKey, role, option) then
                count = count + 1
            end
        end
    end
    return count
end

local function canOfferIExit(option)
    if option == nil then
        return false
    end
    if option.supportsExtensionChoice ~= nil then
        return option.supportsExtensionChoice == true
    end
    return tonumber(option.exitCount) ~= nil and tonumber(option.exitCount) > 1
end

local function canSpendBranchingRoom(instance, rows, rowIndex, option)
    if not canOfferIExit(option) then
        return true
    end
    return countPriorNonGoals(instance, rows, rowIndex) < maxNonGoalRewards(instance) - 1
end

local function roleRequiresPreviousIExit(role)
    return role ~= nil and role.countsNonGoalReward == true
end

local function optionRequiresPreviousIExit(option)
    return option ~= nil and (option.countsNonGoalReward == true or option.requiresExistingIExit == true)
end

local function previousRouteSupportsIExit(instance, rows, rowIndex)
    local previousIndex = rowIndex - 1
    if previousIndex < 1 then
        return false
    end

    local previousSlot = slotForRow(instance, previousIndex)
    if not isRouteSlot(previousSlot) then
        return false
    end

    local previousValidation = data.validateRow(instance, rows, previousIndex)
    if not previousValidation.valid then
        return false
    end

    local roleKey, role = roleForCount(instance, rows, previousIndex)
    if roleKey == VANILLA_ROLE_KEY or role == nil then
        return false
    end
    return canOfferIExit(optionForCount(instance, rows, previousIndex, roleKey))
end

local function requiresPreviousIExit(role, option)
    return roleRequiresPreviousIExit(role) or optionRequiresPreviousIExit(option)
end

routeTerminatedBeforeRow = function(instance, rows, rowIndex, slot)
    return goalsCompleteBeforeRow(instance, rows, rowIndex, slot)
        and not previousRouteSupportsIExit(instance, rows, rowIndex)
end

local function roleIsAllowedByCounters(instance, rows, rowIndex, roleKey, role)
    if roleKey == VANILLA_ROLE_KEY then
        return true
    end
    if routeTerminatedBeforeRow(instance, rows, rowIndex, slotForRow(instance, rowIndex)) then
        return false
    end
    if rowCountsGoal(roleKey, role) then
        return countPriorGoals(instance, rows, rowIndex) < requiredGoalRewards(instance)
    end
    if role ~= nil and role.countsNonGoalReward == true then
        return countPriorNonGoals(instance, rows, rowIndex) < maxNonGoalRewards(instance)
    end
    return true
end

local function roleIsAllowed(instance, rows, rowIndex, roleKey, role)
    if not roleIsAllowedByCounters(instance, rows, rowIndex, roleKey, role) then
        return false
    end
    if roleRequiresPreviousIExit(role) and not previousRouteSupportsIExit(instance, rows, rowIndex) then
        return false
    end
    return true
end

local function roleDisallowedStatus(instance, rows, rowIndex, roleKey, role)
    if roleRequiresPreviousIExit(role) and not previousRouteSupportsIExit(instance, rows, rowIndex) then
        return invalidStatus(
            "clockwork_previous_i_exit",
            tostring(role.label or roleKey) .. " requires a previous planned room with an I exit"
        )
    end
    if rowCountsGoal(roleKey, role) then
        return invalidStatus(
            "clockwork_goal_limit",
            "Clockwork Goal is already planned " .. tostring(requiredGoalRewards(instance)) .. " times"
        )
    end
    if role ~= nil and role.countsNonGoalReward == true then
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

    isOptionAllowed = function(instance, rows, rowIndex, _, _, _, option, slot)
        if not isRouteSlot(slot) then
            return true
        end
        if not canSpendBranchingRoom(instance, rows, rowIndex, option) then
            return false
        end
        if optionRequiresPreviousIExit(option) and not previousRouteSupportsIExit(instance, rows, rowIndex) then
            return false
        end
        return true
    end,

    roleDisallowedStatus = function(instance, rows, rowIndex, roleKey, role)
        return roleDisallowedStatus(instance, rows, rowIndex, roleKey, role)
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

        local option = optionForCount(instance, rows, rowIndex, roleKey)
        if requiresPreviousIExit(role, option) and not previousRouteSupportsIExit(instance, rows, rowIndex) then
            return invalidStatus(
                "clockwork_previous_i_exit",
                tostring(role.label or roleKey) .. " requires a previous planned room with an I exit"
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

function data.countGoals(instance, rows)
    return countRouteRows(instance, rows, function(roleKey, role)
        return rowCountsGoal(roleKey, role)
    end)
end

function data.countNonGoals(instance, rows)
    return countRouteRows(instance, rows, function(_, role, option)
        return rowCountsNonGoal(role, option)
    end)
end

function data.countStories(instance, rows)
    return countRouteRows(instance, rows, function(roleKey)
        return roleKey == "Story"
    end)
end

function data.isRouteSlot(slot)
    return isRouteSlot(slot)
end

function data.isInactiveRouteRow(instance, rows, rowIndex)
    return routeTerminatedBeforeRow(instance, rows, rowIndex, slotForRow(instance, rowIndex))
end

return data
