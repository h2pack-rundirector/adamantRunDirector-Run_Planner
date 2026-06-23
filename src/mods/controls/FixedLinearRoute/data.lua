local deps = ...
local common = deps.common
local timeline = deps.timeline
local rowEngine = deps.rowEngine

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local addChoice = common.addChoice
local buildOptionChoices = common.buildOptionChoices
local validStatus = common.validStatus
local fixedBiomeDepthCacheCost = common.fixedBiomeDepthCacheCost
local routeBiomeDepthCacheCost = common.routeBiomeDepthCacheCost
local routeStartOrdinal = common.routeStartOrdinal
local routeEndOrdinal = common.routeEndOrdinal
local routeRowLabel = common.routeRowLabel
local applySlotDepthContext = common.applySlotDepthContext

local data

local function slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function isPrebossSlot(slot)
    return slot ~= nil and slot.kind == "preboss"
end

local function isFixedRoleSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function isFixedIdentitySlot(slot)
    return isPrebossSlot(slot) or isFixedRoleSlot(slot)
end

local function firstBranchKey(slot)
    return slot and (slot.branchKey or (slot.branchValues and slot.branchValues[1])) or ""
end

local function buildFixedRoleSlot(instance, ordinal, special)
    local kind = special.kind
    local roomOptions = shallowCopyList(special.roomOptions)
    local role = {
        key = special.key or kind,
        label = special.label or special.key or kind,
        roomKey = special.roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = special.reward,
        features = special.features,
        biomeDepthCacheCost = special.biomeDepthCacheCost,
        biomeEncounterDepthCost = special.biomeEncounterDepthCost,
    }
    buildOptionChoices(role)

    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = ordinal,
        kind = kind,
        isBiomeEntry = special.isBiomeEntry == true,
        label = special.label or role.label,
        roomKey = special.roomKey,
        roleKey = role.key,
        role = role,
        features = special.features,
    }, {
        biomeDepthCache = special.biomeDepthCache,
        biomeDepthCacheCost = fixedBiomeDepthCacheCost(instance.biome.slotLayout, special),
        biomeEncounterDepthCost = special.biomeEncounterDepthCost,
    })
end

local function buildEntrySlot(instance, entry)
    if entry == nil then
        return
    end

    buildFixedRoleSlot(instance, entry.routeOrdinal or 0, {
        kind = entry.kind or "intro",
        key = entry.key or "Intro",
        label = entry.label or "Intro",
        roomKey = entry.roomKey,
        roomOptions = entry.roomOptions,
        reward = entry.reward,
        features = entry.features,
        isBiomeEntry = entry.isBiomeEntry == true,
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
        locked = entry.locked,
    })
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startOrdinal = routeStartOrdinal(slotLayout)
    local endOrdinal = routeEndOrdinal(slotLayout, startOrdinal)

    instance.routeSlots = {}
    buildEntrySlot(instance, slotLayout.entry)

    local fixedOrdinals = {}
    for ordinal, slot in pairs(slotLayout.special or {}) do
        if slot.kind == "opening" then
            fixedOrdinals[#fixedOrdinals + 1] = math.floor(tonumber(ordinal) or 0)
        end
    end
    table.sort(fixedOrdinals)
    for _, ordinal in ipairs(fixedOrdinals) do
        buildFixedRoleSlot(instance, ordinal, slotLayout.special[ordinal])
    end

    for ordinal = startOrdinal, endOrdinal do
        local rowIndex = #instance.routeSlots + 1
        instance.routeSlots[rowIndex] = applySlotDepthContext({
            rowIndex = rowIndex,
            routeOrdinal = ordinal,
            kind = "biomeRow",
            label = routeRowLabel(slotLayout, ordinal, "Depth"),
        }, {
            biomeDepthCacheCost = routeBiomeDepthCacheCost(slotLayout),
        })
    end

    local specialOrdinals = {}
    for ordinal, slot in pairs(slotLayout.special or {}) do
        if slot.kind == "preboss" then
            specialOrdinals[#specialOrdinals + 1] = math.floor(tonumber(ordinal) or 0)
        end
    end
    table.sort(specialOrdinals)
    for _, ordinal in ipairs(specialOrdinals) do
        local special = slotLayout.special[ordinal]
        for _, branch in ipairs(special.branches or {}) do
            local branches = { branch }
            local rowIndex = #instance.routeSlots + 1
            local slot = applySlotDepthContext({
                rowIndex = rowIndex,
                routeOrdinal = ordinal,
                kind = "preboss",
                isBiomeEntry = special.isBiomeEntry == true,
                label = branch.label or special.label or (routeRowLabel(slotLayout, ordinal, "Depth") .. " Preboss"),
                roomKey = special.roomKey,
                branchKey = branch.key,
                branch = branch,
                branches = branches,
                branchesByKey = buildLookup(branches),
                branchValues = {},
                branchLabels = {},
            }, {
                biomeDepthCache = special.biomeDepthCache,
                biomeDepthCacheCost = fixedBiomeDepthCacheCost(slotLayout, special),
                biomeEncounterDepthCost = special.biomeEncounterDepthCost,
            })
            addChoice(slot.branchValues, slot.branchLabels, branch.key, branch.label)
            instance.routeSlots[rowIndex] = slot
        end
    end
    instance.routeRowCount = #instance.routeSlots
end

local function addBranchLabels(instance)
    for _, slot in ipairs(instance.routeSlots or {}) do
        for _, branch in ipairs(slot.branches or {}) do
            instance.roleLabels[branch.key] = branch.label or branch.key
        end
    end
end

local adapter = {
    slotForRow = slotForRow,
    isFixedIdentitySlot = isFixedIdentitySlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
        if isFixedRoleSlot(slot) then
            return slot.roleKey
        end
        if isPrebossSlot(slot) then
            return firstBranchKey(slot)
        end
        return defaultReadRoleKey(instance, rows, rowIndex, slot)
    end,

    roleForRow = function(instance, rowIndex, roleKey, slot, defaultRoleForRow)
        if isFixedRoleSlot(slot) then
            if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
                return slot.role
            end
            return nil
        end
        if isPrebossSlot(slot) then
            return slot.branchesByKey[roleKey]
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(_, _, _, roleKey, slot)
        if isFixedRoleSlot(slot) then
            return roleKey == slot.roleKey
        end
        if isPrebossSlot(slot) then
            return slot.branchesByKey[roleKey] ~= nil
        end
        return nil
    end,

    fillRoleValuesForSlot = function(_, _, _, slot, values)
        if isFixedRoleSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        if isPrebossSlot(slot) then
            for _, branchKey in ipairs(slot.branchValues or {}) do
                values[#values + 1] = branchKey
            end
            return true
        end
        return false
    end,

    skipOptionsForSlot = function(_, _, _, slot)
        return isPrebossSlot(slot)
    end,

    validateSlot = function(_, _, _, _, _, slot)
        if isPrebossSlot(slot) then
            return validStatus()
        end
        return nil
    end,

    optionUnavailableMessage = function(_, _, _, _, role)
        return tostring(role.label or role.key) .. " is not valid at this depth"
    end,
}

data = rowEngine.create(adapter)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)

    buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    data.buildRoleChoices(instance)
    addBranchLabels(instance)
    data.prepareSlots(instance)
    return instance
end

function data.storage(instance)
    return {
        {
            key = "Rooms",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = data.buildRoomRows(),
        },
        {
            key = "Rewards",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = data.buildRewardRows(),
        },
    }
end

return data
