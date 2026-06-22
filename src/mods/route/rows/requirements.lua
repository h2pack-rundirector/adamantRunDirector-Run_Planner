local deps = ...
local common = deps.common
local rewards = deps.rewards

local requirements = {}
local EMPTY_LIST = {}

local function status(code, message)
    return common.invalidStatus(code, message)
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function scratchSelections(instance)
    local scratch = instance._routeRequirementSelections
    if scratch == nil then
        scratch = {}
        instance._routeRequirementSelections = scratch
    else
        clearMap(scratch)
    end
    return scratch
end

local function previousRoomExitCountSatisfied(route, instance, rows, rowIndex, requirement)
    local previousIndex = rowIndex - 1
    if previousIndex < 1 then
        return false
    end

    local previousValidation = route.validateRow(instance, rows, previousIndex)
    if not previousValidation.valid then
        return false
    end

    local previousRoleKey = route.resolveRole(instance, rows, previousIndex)
    if previousRoleKey == common.VANILLA_ROLE_KEY then
        return false
    end

    local _, previousOption = route.resolveOption(instance, rows, previousIndex, previousRoleKey)
    local exitCount = previousOption and tonumber(previousOption.exitCount) or nil
    return exitCount ~= nil and exitCount >= requirement.minCount
end

local function previousRoomExitCountStatus(route, instance, rows, rowIndex, requirement)
    local previousIndex = rowIndex - 1
    if previousIndex < 1 then
        return status(
            "previous_room_exit_count",
            "Previous planned room must have at least " .. tostring(requirement.minCount) .. " exits"
        )
    end

    local previousValidation = route.validateRow(instance, rows, previousIndex)
    if not previousValidation.valid then
        return status(
            "previous_room_invalid",
            "Previous planned room is invalid"
        )
    end

    local previousRoleKey = route.resolveRole(instance, rows, previousIndex)
    if previousRoleKey == common.VANILLA_ROLE_KEY then
        return status(
            "previous_room_unplanned",
            "Previous planned room is Vanilla"
        )
    end

    local _, previousOption = route.resolveOption(instance, rows, previousIndex, previousRoleKey)
    local exitCount = previousOption and tonumber(previousOption.exitCount) or nil
    if exitCount == nil or exitCount < requirement.minCount then
        return status(
            "previous_room_exit_count",
            "Previous planned room must have at least " .. tostring(requirement.minCount) .. " exits"
        )
    end
    return common.validStatus()
end

local function addGodLootSelection(selections, countedLookup, lootName)
    if lootName ~= nil and lootName ~= "" and countedLookup[lootName] and not selections[lootName] then
        selections[lootName] = true
        return 1
    end
    return 0
end

local function selectionCount(selections)
    local count = 0
    for _ in pairs(selections) do
        count = count + 1
    end
    return count
end

local function collectRewardGodLoot(route, instance, rows, rowIndex, selections, countedLookup)
    local roleKey, role = route.resolveRole(instance, rows, rowIndex)
    if role == nil or roleKey == common.VANILLA_ROLE_KEY then
        return 0
    end

    local validation = route.validateRow(instance, rows, rowIndex)
    if not validation.valid then
        return 0
    end

    local _, option = route.resolveOption(instance, rows, rowIndex, roleKey)
    local context = common.rewardContext(role, option)
    if context == nil then
        return 0
    end

    local reward1 = rows:read(rowIndex, rewards.rewardAlias(1)) or ""
    local reward2 = rows:read(rowIndex, rewards.rewardAlias(2)) or ""
    local reward3 = rows:read(rowIndex, rewards.rewardAlias(3)) or ""
    local reward4 = rows:read(rowIndex, rewards.rewardAlias(4)) or ""
    local reward5 = rows:read(rowIndex, rewards.rewardAlias(5)) or ""
    local reward6 = rows:read(rowIndex, rewards.rewardAlias(6)) or ""
    local count = 0

    if context.kind == "majorMinor" then
        if reward1 == "Major" and reward2 == "Boon" then
            count = count + addGodLootSelection(selections, countedLookup, reward3)
        elseif reward1 == "Major" and reward2 == "Devotion" then
            count = count + addGodLootSelection(selections, countedLookup, reward5)
            count = count + addGodLootSelection(selections, countedLookup, reward6)
        end
    elseif context.kind == "roomStore" then
        if common.isOnlyEligible(context.eligibleRewardTypes, "Boon") then
            count = count + addGodLootSelection(selections, countedLookup, reward1)
        elseif reward1 == "Boon" then
            count = count + addGodLootSelection(selections, countedLookup, reward2)
        elseif reward1 == "Devotion" then
            count = count + addGodLootSelection(selections, countedLookup, reward3)
            count = count + addGodLootSelection(selections, countedLookup, reward4)
        end
    elseif context.kind == "forcedReward" then
        if context.rewardType == "Boon" then
            count = count + addGodLootSelection(selections, countedLookup, reward1)
        elseif context.rewardType == "Devotion" then
            count = count + addGodLootSelection(selections, countedLookup, reward1)
            count = count + addGodLootSelection(selections, countedLookup, reward2)
        end
    end
    return count
end

local function collectRouteContextGodLoot(instance, countedLookup, selections, stopAtCount)
    local routeContext = instance and instance.routeContext or nil
    if routeContext ~= nil and routeContext.collectPriorGodLoot ~= nil then
        routeContext:collectPriorGodLoot(instance.routeKey, instance.biomeKey, countedLookup, selections, stopAtCount)
    end
end

local function priorDistinctGodLootSatisfied(route, instance, rows, rowIndex, requirement, selections)
    local countedLookup = requirement.countedLootLookup or common.buildKeyLookup(requirement.countedLootNames)
    selections = selections or scratchSelections(instance)

    collectRouteContextGodLoot(instance, countedLookup, selections, requirement.minDistinct)
    local count = selectionCount(selections)
    if count >= requirement.minDistinct then
        return true
    end

    for priorIndex = 1, rowIndex - 1 do
        count = count + collectRewardGodLoot(route, instance, rows, priorIndex, selections, countedLookup)
        if count >= requirement.minDistinct then
            return true
        end
    end
    return false
end

local function priorDistinctGodLootStatus(route, instance, rows, rowIndex, requirement)
    if priorDistinctGodLootSatisfied(route, instance, rows, rowIndex, requirement) then
        return common.validStatus()
    end
    return status(
        "prior_distinct_god_loot",
        "Requires at least " .. tostring(requirement.minDistinct) .. " prior planned god rewards"
    )
end

local function itemSatisfied(route, instance, rows, rowIndex, requirement)
    if requirement.kind == "previousRoomExitCount" then
        return previousRoomExitCountSatisfied(route, instance, rows, rowIndex, requirement)
    elseif requirement.kind == "priorDistinctGodLoot" then
        return priorDistinctGodLootSatisfied(route, instance, rows, rowIndex, requirement)
    end
    return false
end

local function itemStatus(route, instance, rows, rowIndex, requirement)
    if requirement.kind == "previousRoomExitCount" then
        return previousRoomExitCountStatus(route, instance, rows, rowIndex, requirement)
    elseif requirement.kind == "priorDistinctGodLoot" then
        return priorDistinctGodLootStatus(route, instance, rows, rowIndex, requirement)
    end
    return status(
        "unknown_route_requirement",
        "Unknown route requirement: " .. tostring(requirement.kind)
    )
end

local function listStatus(route, instance, rows, rowIndex, requirementList)
    for _, requirement in ipairs(requirementList or EMPTY_LIST) do
        local result = itemStatus(route, instance, rows, rowIndex, requirement)
        if not result.valid then
            return result
        end
    end
    return common.validStatus()
end

local function listSatisfied(route, instance, rows, rowIndex, requirementList)
    for _, requirement in ipairs(requirementList or EMPTY_LIST) do
        if not itemSatisfied(route, instance, rows, rowIndex, requirement) then
            return false
        end
    end
    return true
end

function requirements.status(route, instance, rows, rowIndex, role, option)
    local result = listStatus(route, instance, rows, rowIndex, role.routeRequirements)
    if not result.valid then
        return result
    end

    local context = common.rewardContext(role, option)
    if context == nil then
        return common.validStatus()
    end
    return listStatus(route, instance, rows, rowIndex, context.routeRequirements)
end

function requirements.isSatisfied(route, instance, rows, rowIndex, role, option)
    if not listSatisfied(route, instance, rows, rowIndex, role.routeRequirements) then
        return false
    end

    local context = common.rewardContext(role, option)
    if context == nil then
        return true
    end
    return listSatisfied(route, instance, rows, rowIndex, context.routeRequirements)
end

function requirements.prepareList(requirementList)
    for _, requirement in ipairs(requirementList or EMPTY_LIST) do
        if requirement.kind == "priorDistinctGodLoot" and requirement.countedLootLookup == nil then
            requirement.countedLootLookup = common.buildKeyLookup(requirement.countedLootNames)
        end
    end
end

function requirements.prepareContext(context)
    if context ~= nil then
        requirements.prepareList(context.routeRequirements)
    end
end

function requirements.prepareRole(role)
    requirements.prepareList(role.routeRequirements)
    requirements.prepareContext(role.reward)
    for _, option in ipairs(common.optionListForRole(role)) do
        requirements.prepareContext(option.reward)
    end
end

function requirements.prepareSlots(slots)
    for _, slot in ipairs(slots or EMPTY_LIST) do
        if slot.role ~= nil then
            requirements.prepareRole(slot.role)
        end
        for _, branch in ipairs(slot.branches or EMPTY_LIST) do
            requirements.prepareContext(branch.reward)
        end
    end
end

return requirements
