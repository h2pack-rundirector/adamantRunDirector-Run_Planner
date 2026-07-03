local deps = ... or {}

local common = deps.common

local routeRequirements = {}

local EMPTY_LIST = common.EMPTY_LIST

local function entryLabel(entry)
    local source = entry and entry.source or nil
    return source and (source.slotLabel or source.label)
        or entry and (entry.entryLabel or entry.slotLabel or entry.roleLabel or entry.optionLabel)
        or entry and (entry.roleKey or entry.roomKey or entry.eventKey)
end

local function validateRouteRequirement(step, requirement)
    local entry = step and step.entry or nil
    if requirement.kind == "previousRoomExitCount" then
        local previousStep = step and step.previous or nil
        local previousEntry = previousStep and previousStep.entry or nil
        local actualExitCount = previousStep
            and previousStep.topology
            and previousStep.topology.generatedExitCount
            or nil
        if actualExitCount ~= nil and actualExitCount >= requirement.minCount then
            return nil
        end
        return common.invalidAt(
            entry,
            "previous_room_exit_count",
            {
                requiredExitCount = requirement.minCount,
                actualExitCount = actualExitCount or 0,
                previousEntryLabel = entryLabel(previousEntry),
                currentEntryLabel = entryLabel(entry),
            }
        )
    end
    error("Unknown route requirement kind: " .. tostring(requirement.kind), 0)
end

function routeRequirements.validate(steps, _biome)
    for _, step in ipairs(steps or EMPTY_LIST) do
        local role = step.selected and step.selected.role or nil
        local option = step.selected and step.selected.option or nil
        for _, requirement in ipairs(role and role.routeRequirements or EMPTY_LIST) do
            local invalid = validateRouteRequirement(step, requirement)
            if invalid ~= nil then
                return invalid
            end
        end
        for _, requirement in ipairs(option and option.routeRequirements or EMPTY_LIST) do
            local invalid = validateRouteRequirement(step, requirement)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

return routeRequirements
