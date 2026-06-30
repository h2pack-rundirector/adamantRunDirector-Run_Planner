local roomStructure = {}

local MAX_NORMAL_SIBLING_COUNT = 2

local function structuralValue(field, slot, role, option)
    return option and option[field]
        or role and role[field]
        or slot and slot[field]
        or nil
end

function roomStructure.exitCount(slot, role, option)
    return structuralValue("exitCount", slot, role, option)
end

function roomStructure.rewardExitCount(slot, role, option)
    return structuralValue("rewardExitCount", slot, role, option)
        or roomStructure.exitCount(slot, role, option)
end

function roomStructure.siblingCountForExitCount(exitCount)
    local count = math.max(math.floor(tonumber(exitCount) or 0) - 1, 0)
    if count > MAX_NORMAL_SIBLING_COUNT then
        return MAX_NORMAL_SIBLING_COUNT
    end
    return count
end

function roomStructure.siblingCount(slot, role, option)
    return roomStructure.siblingCountForExitCount(roomStructure.exitCount(slot, role, option))
end

return roomStructure
