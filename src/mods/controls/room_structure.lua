local roomStructure = {}

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

return roomStructure
