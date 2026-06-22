local deps = ...
local common = deps.common

local requirements = {}
local EMPTY_LIST = {}

local function status(code, message)
    return common.invalidStatus(code, message)
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

local function itemSatisfied(route, instance, rows, rowIndex, requirement)
    if requirement.kind == "previousRoomExitCount" then
        return previousRoomExitCountSatisfied(route, instance, rows, rowIndex, requirement)
    end
    return false
end

local function itemStatus(route, instance, rows, rowIndex, requirement)
    if requirement.kind == "previousRoomExitCount" then
        return previousRoomExitCountStatus(route, instance, rows, rowIndex, requirement)
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

function requirements.prepareList(_requirementList) end

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
