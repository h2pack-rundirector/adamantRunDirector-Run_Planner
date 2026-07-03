local deps = ... or {}

local common = deps.common

local deadlines = {}

local EMPTY_LIST = common.EMPTY_LIST

local function candidateInList(candidates, roomKey)
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        if candidate == roomKey then
            return true
        end
    end
    return false
end

local function generatedRoomKeyThrough(steps, entryIndex, roomKeys)
    for index = 1, entryIndex do
        local step = steps[index]
        local entry = step and step.entry or nil
        if candidateInList(roomKeys, entry and (entry.roomKey or entry.eventKey)) then
            return true
        end
        for _, exit in ipairs(step and step.topology and step.topology.exits or EMPTY_LIST) do
            if candidateInList(roomKeys, exit.roomKey) then
                return true
            end
        end
    end
    return false
end

function deadlines.validate(steps, biome)
    local topology = common.routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    for _, requirement in ipairs(topology.deadlineRequirements or EMPTY_LIST) do
        local deadline = requirement.biomeDepthCache
        if deadline ~= nil then
            for index, step in ipairs(steps or EMPTY_LIST) do
                local entry = step.entry
                if (entry.biomeDepthCache or 0) >= deadline then
                    if not generatedRoomKeyThrough(steps, index, requirement.roomKeys) then
                        return common.invalidAt(
                            entry,
                            requirement.code or "room_deadline_requirement",
                            {
                                topologyRequirementKey = requirement.key,
                                deadlineRequirementLabel = requirement.label,
                                deadlineBiomeDepthCache = deadline,
                                requiredRoomKeys = requirement.roomKeys,
                                generatedCount = 0,
                                requiredGeneratedCount = requirement.requiredGeneratedCount or 1,
                            }
                        )
                    end
                    break
                end
            end
        end
    end
    return nil
end

return deadlines
