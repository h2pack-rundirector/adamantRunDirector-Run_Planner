local roomStructure = {}

local MAX_NORMAL_OTHER_DOOR_COUNT = 2

local function structuralValue(field, slot, role, option)
    return option and option[field]
        or role and role[field]
        or slot and slot[field]
        or nil
end

function roomStructure.exitCount(slot, role, option)
    return structuralValue("exitCount", slot, role, option)
end

function roomStructure.rewardBearingExitCount(slot, role, option)
    return structuralValue("rewardBearingExitCount", slot, role, option)
        or roomStructure.exitCount(slot, role, option)
end

function roomStructure.otherDoorCountForExitCount(exitCount)
    local count = math.max(math.floor(tonumber(exitCount) or 0) - 1, 0)
    if count > MAX_NORMAL_OTHER_DOOR_COUNT then
        return MAX_NORMAL_OTHER_DOOR_COUNT
    end
    return count
end

function roomStructure.otherDoorCount(slot, role, option)
    return roomStructure.otherDoorCountForExitCount(roomStructure.exitCount(slot, role, option))
end

return roomStructure
