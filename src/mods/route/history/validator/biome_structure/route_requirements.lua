local deps = ... or {}

local common = deps.common
local routeQuery = deps.query
local pickedEntries = deps.pickedEntries

local routeRequirements = {}

local EMPTY_LIST = common.EMPTY_LIST

local function entryLabel(entry)
    local source = entry and entry.source or nil
    return source and (source.slotLabel or source.label)
        or entry and (entry.entryLabel or entry.slotLabel or entry.roleLabel or entry.optionLabel)
        or entry and (entry.roleKey or entry.roomKey or entry.eventKey)
end

local function validateRouteRequirement(history, entry, requirement)
    if requirement.kind == "previousRoomExitCount" then
        local actualExitCount, previousEntry = routeQuery.previousGeneratedExitDetails(history, entry)
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

function routeRequirements.validate(history, biome)
    for _, entry in ipairs(common.biomeRoomEntries(history, biome.key)) do
        local role, option = pickedEntries.declarationForEntry(biome, entry)
        for _, requirement in ipairs(role and role.routeRequirements or EMPTY_LIST) do
            local invalid = validateRouteRequirement(history, entry, requirement)
            if invalid ~= nil then
                return invalid
            end
        end
        for _, requirement in ipairs(option and option.routeRequirements or EMPTY_LIST) do
            local invalid = validateRouteRequirement(history, entry, requirement)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

return routeRequirements
