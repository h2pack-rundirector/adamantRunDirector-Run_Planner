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

local function generatedRoomKeyThrough(entries, entryIndex, roomKeys)
    for index = 1, entryIndex do
        if candidateInList(roomKeys, entries[index].roomKey or entries[index].eventKey) then
            return true
        end
        for _, exit in ipairs(common.selectedAndGeneratedExits(entries[index])) do
            if candidateInList(roomKeys, exit.roomKey) then
                return true
            end
        end
    end
    return false
end

function deadlines.validate(history, biome)
    local topology = common.routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    local entries = common.biomeRoomEntries(history, biome.key)
    for _, requirement in ipairs(topology.deadlineRequirements or EMPTY_LIST) do
        local deadline = requirement.biomeDepthCache
        if deadline ~= nil then
            for index, entry in ipairs(entries) do
                if (entry.biomeDepthCache or 0) >= deadline then
                    if not generatedRoomKeyThrough(entries, index, requirement.roomKeys) then
                        return common.invalidAt(
                            entry,
                            requirement.code or "room_deadline_requirement",
                            nil,
                            {
                                topologyRequirementKey = requirement.key,
                                deadlineRequirementLabel = requirement.label,
                                deadlineBiomeDepthCache = deadline,
                                requiredRoomKeys = requirement.roomKeys,
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
