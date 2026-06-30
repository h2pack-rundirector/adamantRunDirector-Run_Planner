local deps = ... or {}

local common = deps.common
local findings = deps.findings

local pickedEntries = {}

local EMPTY_LIST = common.EMPTY_LIST

local function variantFailure(entry)
    if entry == nil
        or entry.variantKey == nil
        or entry.variantKey == ""
        or entry.variantAvailability == nil
    then
        return nil
    end
    if common.rangeContains(entry.variantAvailability, entry.biomeEncounterDepth) then
        return nil
    end
    return "encounter_depth_unavailable"
end

local function variantFinding(entry, reason, message)
    return findings.variantCandidateInvalid(entry, {
        key = entry and entry.variantKey or nil,
        label = entry and entry.variantLabel or nil,
        availableAtBiomeEncounterDepth = entry and entry.variantAvailability or nil,
        controlAlias = "VariantKey",
    }, reason, {
        message = message,
        expected = entry and entry.variantAvailability or nil,
        actual = entry and entry.biomeEncounterDepth or nil,
    })
end

local function hasTag(tags, expected)
    for _, tag in ipairs(tags or EMPTY_LIST) do
        if tag == expected then
            return true
        end
    end
    return false
end

local function nextRoomTagsFailure(requiredTags, tags)
    if requiredTags == nil then
        return nil
    end
    for _, requiredTag in ipairs(requiredTags) do
        if hasTag(tags, requiredTag) then
            return nil
        end
    end
    return "previous_room_next_tags"
end

local function nextRoomTagsMessage(requiredTags)
    local requiredTag = requiredTags and requiredTags[1] or "required"
    return "Previous planned room only leads to " .. tostring(requiredTag) .. " rooms"
end

local function optionList(role)
    return role and (role.roomOptions or role.mapOptions) or EMPTY_LIST
end

local function optionByKey(role, key)
    if role == nil or key == nil or key == "" then
        return nil
    end
    if role.optionsByKey ~= nil then
        return role.optionsByKey[key]
    end
    for _, option in ipairs(optionList(role)) do
        if option.key == key then
            return option
        end
    end
    return nil
end

local function optionByRoomKey(role, roomKey)
    if role == nil or roomKey == nil or roomKey == "" then
        return nil
    end
    for _, option in ipairs(optionList(role)) do
        if option.key == roomKey then
            return option
        end
    end
    return nil
end

function pickedEntries.declarationForEntry(biome, entry)
    local role = biome
        and biome.rolesByKey
        and biome.rolesByKey[entry and entry.roleKey or nil]
        or nil
    local option = optionByKey(role, entry and entry.optionKey)
        or optionByRoomKey(role, entry and entry.roomKey)
    return role, option
end

local function capFor(value)
    return value and (
        value.maxCreationsThisRun
            or value.maxAppearancesThisBiome
            or value.routeRules and value.routeRules.maxSelectionsPerBiome
    ) or nil
end

local function appendCount(counts, key)
    if key == nil or key == "" then
        return 0
    end
    local value = (counts[key] or 0) + 1
    counts[key] = value
    return value
end

function pickedEntries.validate(history, biome)
    local roleCounts = {}
    local optionCounts = {}
    local previousOption = nil
    for _, entry in ipairs(common.biomeRoomEntries(history, biome.key)) do
        local role, option = pickedEntries.declarationForEntry(biome, entry)
        if previousOption ~= nil then
            local requiredTags = previousOption.nextRoomTags
            local failure = nextRoomTagsFailure(requiredTags, option and option.tags)
            if failure ~= nil then
                return common.invalidAt(entry, failure, nextRoomTagsMessage(requiredTags))
            end
        end
        if option ~= nil then
            local failure = common.availabilityFailure(option, entry)
            if failure ~= nil then
                return common.invalidAt(entry, failure, "Room is not valid at this generated depth")
            end
        end
        local variantInvalid = variantFailure(entry)
        if variantInvalid ~= nil then
            local message = tostring(entry.variantLabel or entry.variantKey) .. " is not valid at this encounter depth"
            return common.invalidWithFindings(
                entry,
                variantInvalid,
                message,
                {
                    variantFinding(entry, variantInvalid, message),
                }
            )
        end

        local roleCap = capFor(role)
        if roleCap ~= nil and appendCount(roleCounts, role.key) > roleCap then
            return common.invalidAt(entry, "role_limit", tostring(role.label or role.key) .. " is already planned")
        end

        local optionCap = capFor(option)
        if optionCap ~= nil and appendCount(optionCounts, option.key) > optionCap then
            return common.invalidAt(
                entry,
                "option_limit",
                tostring(option.label or option.key) .. " is already generated"
            )
        end
        previousOption = option
    end
    return nil
end

return pickedEntries
