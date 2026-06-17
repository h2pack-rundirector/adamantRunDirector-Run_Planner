local deps = ...
local common = deps.common

local requirements = {}

local function status(code, message)
    return common.invalidStatus(code, message)
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
    if lootName ~= nil and lootName ~= "" and countedLookup[lootName] then
        selections[lootName] = true
    end
end

local function collectRewardGodLoot(route, instance, rows, rowIndex, selections, countedLookup)
    local roleKey, role = route.resolveRole(instance, rows, rowIndex)
    if role == nil or roleKey == common.VANILLA_ROLE_KEY then
        return
    end

    local validation = route.validateRow(instance, rows, rowIndex)
    if not validation.valid then
        return
    end

    local _, option = route.resolveOption(instance, rows, rowIndex, roleKey)
    local context = common.rewardContext(role, option)
    if context == nil then
        return
    end

    local reward1 = rows:read(rowIndex, "Reward1Key") or ""
    local reward2 = rows:read(rowIndex, "Reward2Key") or ""
    local reward3 = rows:read(rowIndex, "Reward3Key") or ""

    if context.kind == "majorMinor" or context.kind == "shipWheel" then
        if reward1 == "Major" and reward2 == "Boon" then
            addGodLootSelection(selections, countedLookup, reward3)
        end
    elseif context.kind == "roomStore" then
        if common.isOnlyEligible(context.eligibleRewardTypes, "Boon") then
            addGodLootSelection(selections, countedLookup, reward1)
        elseif reward1 == "Boon" then
            addGodLootSelection(selections, countedLookup, reward2)
        end
    elseif context.kind == "forcedReward" then
        if context.rewardType == "Boon" then
            addGodLootSelection(selections, countedLookup, reward1)
        elseif context.rewardType == "Devotion" then
            addGodLootSelection(selections, countedLookup, reward1)
            addGodLootSelection(selections, countedLookup, reward2)
        end
    end
end

local function priorDistinctGodLootStatus(route, instance, rows, rowIndex, requirement)
    local countedLookup = requirement.countedLootLookup or common.buildKeyLookup(requirement.countedLootNames)
    local selections = {}
    local count = 0

    for priorIndex = 1, rowIndex - 1 do
        collectRewardGodLoot(route, instance, rows, priorIndex, selections, countedLookup)
    end

    for _ in pairs(selections) do
        count = count + 1
    end
    if count < requirement.minDistinct then
        return status(
            "prior_distinct_god_loot",
            "Requires at least " .. tostring(requirement.minDistinct) .. " prior planned god rewards"
        )
    end
    return common.validStatus()
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
    for _, requirement in ipairs(requirementList or {}) do
        local result = itemStatus(route, instance, rows, rowIndex, requirement)
        if not result.valid then
            return result
        end
    end
    return common.validStatus()
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

function requirements.prepareList(requirementList)
    for _, requirement in ipairs(requirementList or {}) do
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
    for _, slot in ipairs(slots or {}) do
        if slot.role ~= nil then
            requirements.prepareRole(slot.role)
        end
        for _, branch in ipairs(slot.branches or {}) do
            requirements.prepareContext(branch.reward)
        end
    end
end

return requirements
