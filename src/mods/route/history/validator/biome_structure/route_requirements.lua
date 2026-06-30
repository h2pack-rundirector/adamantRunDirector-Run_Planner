local deps = ... or {}

local common = deps.common
local routeQuery = deps.query
local pickedEntries = deps.pickedEntries

local routeRequirements = {}

local EMPTY_LIST = common.EMPTY_LIST

local function validateRouteRequirement(history, entry, requirement)
    if requirement.kind == "previousRoomExitCount" then
        if routeQuery.requiredMinExits(history, entry, requirement.minCount) then
            return nil
        end
        return common.invalidAt(
            entry,
            "previous_room_exit_count",
            "Previous planned room must have at least " .. tostring(requirement.minCount) .. " exits"
        )
    end
    return common.invalidAt(
        entry,
        "unknown_route_requirement",
        "Unknown route requirement: " .. tostring(requirement.kind)
    )
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
