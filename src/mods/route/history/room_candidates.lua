local roomCandidates = {}

local EMPTY_LIST = {}

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = copyValue(child)
    end
    return copy
end

local function optionList(role)
    return role and (role.roomOptions or role.mapOptions) or EMPTY_LIST
end

local function roomKeyFor(role, option)
    return option and option.key
        or role and role.roomKey
        or role and role.room and role.room.key
        or nil
end

local function capFor(value)
    return value and (
        value.maxCreationsThisRun
            or value.maxAppearancesThisBiome
            or value.routeRules and value.routeRules.maxSelectionsPerBiome
    ) or nil
end

local function appendCandidate(candidates, role, option)
    candidates[#candidates + 1] = {
        roleKey = role and role.key or nil,
        roleLabel = role and role.label or nil,
        optionKey = option and option.key or nil,
        optionLabel = option and option.label or nil,
        roomKey = roomKeyFor(role, option),
        roleAvailability = copyValue(role and role.availability),
        optionAvailability = copyValue(option and option.availability),
        roleMaxCreationsThisRun = role and role.maxCreationsThisRun or nil,
        optionMaxCreationsThisRun = option and option.maxCreationsThisRun or nil,
        roleMaxAppearancesThisBiome = role and role.maxAppearancesThisBiome or nil,
        optionMaxAppearancesThisBiome = option and option.maxAppearancesThisBiome or nil,
        maxSelectionsPerBiome = role and role.routeRules and role.routeRules.maxSelectionsPerBiome or nil,
        cap = capFor(option) or capFor(role),
        biomeEncounterDepthCost = option and option.biomeEncounterDepthCost
            or role and role.biomeEncounterDepthCost
            or nil,
        biomeDepthCacheCost = option and option.biomeDepthCacheCost
            or role and role.biomeDepthCacheCost
            or nil,
        roomHistoryCost = option and option.roomHistoryCost
            or role and role.roomHistoryCost
            or nil,
        requiredLayer = role and role.requiredLayer or nil,
        nextRoomTags = copyValue(option and option.nextRoomTags),
    }
end

local function appendRoleCandidates(candidates, role)
    local options = optionList(role)
    if options[1] == nil then
        appendCandidate(candidates, role)
        return
    end
    for _, option in ipairs(options) do
        appendCandidate(candidates, role, option)
    end
end

function roomCandidates.forBiomeRow(biome, selectedRow, resolved)
    local candidates = {}
    local selectedRole = resolved and resolved.role or nil
    local roleKey = selectedRow and selectedRow.roleKey or nil
    if selectedRole ~= nil
        and (
            biome == nil
            or biome.rolesByKey == nil
            or biome.rolesByKey[roleKey] == nil
        )
    then
        appendCandidate(candidates, selectedRole, resolved and resolved.option or nil)
        return candidates
    end

    for _, role in ipairs(biome and biome.roles or EMPTY_LIST) do
        appendRoleCandidates(candidates, role)
    end
    return candidates
end

return roomCandidates
