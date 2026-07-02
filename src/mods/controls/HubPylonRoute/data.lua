local deps = ...
local common = deps.common
local rowData = deps.rowData
local slotTimeline = deps.slotTimeline

local ENABLED_SIDE_ROOM_MODE = "Enabled"
local DISABLED_SIDE_ROOM_MODE = "Disabled"
local SIDE_ROOM_ENTERED_ALIAS = "Entered"
local SIDE_ROOM_ENCOUNTER_CLASS_ALIAS = "EncounterClassKey"
local EMPTY_LIST = {}

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local buildOptionChoices = common.buildOptionChoices
local fixedBiomeDepthCacheCost = common.fixedBiomeDepthCacheCost
local routeRowBiomeDepthCacheCost = common.routeRowBiomeDepthCacheCost
local routeStartOrdinal = common.routeStartOrdinal
local routeEndOrdinal = common.routeEndOrdinal
local routeRowLabel = common.routeRowLabel
local applySlotDepthContext = common.applySlotDepthContext
local fixedRoomKey = common.fixedRoomKey
local fixedRoomField = common.fixedRoomField
local fixedRoomFeatures = common.fixedRoomFeatures

local data

local function slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function isFixedSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function buildFixedSlot(instance, entry, section)
    local roomOptions = shallowCopyList(entry.roomOptions)
    local roomKey = fixedRoomKey(entry)
    local features = fixedRoomFeatures(entry)
    local role = {
        key = entry.key,
        label = entry.label or entry.key,
        roomKey = roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = entry.reward,
        features = features,
        exitCount = fixedRoomField(entry, "exitCount"),
        rewardBearingExitCount = fixedRoomField(entry, "rewardBearingExitCount"),
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    }
    buildOptionChoices(role)

    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = entry.routeOrdinal,
        kind = entry.kind or section or "fixed",
        isBiomeEntry = entry.isBiomeEntry == true,
        label = entry.label or entry.key,
        roomKey = roomKey,
        exitCount = role.exitCount,
        rewardBearingExitCount = role.rewardBearingExitCount,
        roleKey = role.key,
        role = role,
        locked = entry.locked,
        features = features,
        roomHistoryCost = entry.roomHistoryCost,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    }, {
        biomeDepthCache = entry.biomeDepthCache,
        biomeDepthCacheCost = fixedBiomeDepthCacheCost(instance.biome.slotLayout, entry),
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    })
end

local function buildPylonSlot(instance, ordinal)
    local slotLayout = instance.biome.slotLayout or {}
    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = ordinal,
        kind = "biomeRow",
        label = routeRowLabel(slotLayout, ordinal, "Pylon"),
    }, {
        biomeDepthCacheCost = routeRowBiomeDepthCacheCost(slotLayout),
        roomHistoryCost = slotLayout.routeRow and slotLayout.routeRow.roomHistoryCost,
    })
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startOrdinal = routeStartOrdinal(slotLayout)
    local endOrdinal = routeEndOrdinal(slotLayout, startOrdinal)

    instance.routeSlots = {}
    for _, entry in ipairs(slotLayout.fixedBeforeHub or {}) do
        buildFixedSlot(instance, entry, "fixedBeforeHub")
    end
    for ordinal = startOrdinal, endOrdinal do
        buildPylonSlot(instance, ordinal)
    end
    for _, entry in ipairs(slotLayout.fixedAfterHub or {}) do
        buildFixedSlot(instance, entry, "fixedAfterHub")
    end
    instance.routeRowCount = #instance.routeSlots
end

local function addFixedRoleLabels(instance)
    for _, slot in ipairs(instance.routeSlots or {}) do
        if slot.roleKey ~= nil then
            instance.roleLabels[slot.roleKey] = slot.label or slot.roleKey
        end
    end
end

local function maxSideDoorCount(instance)
    local count = 0
    for _, room in ipairs(instance.biome and instance.biome.hub and instance.biome.hub.combatRooms or {}) do
        if #(room.sideDoors or {}) > count then
            count = #room.sideDoors
        end
    end
    return count
end

local function sideRoomModes(instance)
    local sideRoomAvailability = instance.biome and instance.biome.hub and instance.biome.hub.sideRoomAvailability or {}
    local modes = sideRoomAvailability.modes
    if modes ~= nil then
        return modes
    end
    return {
        { key = DISABLED_SIDE_ROOM_MODE, label = "Disabled" },
        { key = ENABLED_SIDE_ROOM_MODE, label = "Enabled" },
    }
end

local function addSideRoomModeChoices(instance)
    instance.sideRoomModeValues = {}
    instance.sideRoomModeLabels = {}
    for _, mode in ipairs(sideRoomModes(instance)) do
        instance.sideRoomModeValues[#instance.sideRoomModeValues + 1] = mode.key
        instance.sideRoomModeLabels[mode.key] = mode.label or mode.key
    end
end

local function addSideRoomEncounterClassChoices(instance)
    instance.sideRoomEncounterClassValuesByRoomKey = {}
    instance.sideRoomEncounterClassLabels = {}
    for _, room in ipairs(instance.biome and instance.biome.hub and instance.biome.hub.combatRooms or {}) do
        for _, sideDoor in ipairs(room.sideDoors or EMPTY_LIST) do
            local values = {}
            for _, encounterClass in ipairs(sideDoor.encounterClasses or EMPTY_LIST) do
                values[#values + 1] = encounterClass.key
                instance.sideRoomEncounterClassLabels[encounterClass.key] = encounterClass.label or encounterClass.key
            end
            instance.sideRoomEncounterClassValuesByRoomKey[sideDoor.roomKey] = values
        end
    end
end

local function buildOptionEnrichmentColors(instance)
    instance.optionEnrichmentColorsByRole = {}
    for _, role in ipairs(instance.roles or {}) do
        local colors
        for _, option in ipairs(data.optionListForRole(role)) do
            if option.enrichmentColor ~= nil then
                colors = colors or {}
                colors[option.key] = option.enrichmentColor
            end
        end
        if colors ~= nil then
            instance.optionEnrichmentColorsByRole[role.key] = colors
        end
    end
end

local function prefixedSideAlias(sideIndex, alias)
    return "Side" .. tostring(math.floor(tonumber(sideIndex) or 0)) .. tostring(alias or "")
end

local function appendCopy(rows, source, key)
    local copy = {}
    for fieldKey, value in pairs(source) do
        copy[fieldKey] = value
    end
    copy.key = key or source.key
    rows[#rows + 1] = copy
end

local function buildHubRoomRows(instance)
    local rows = shallowCopyList(data.buildRoomRows())
    for sideIndex = 1, data.maxSideDoorCount(instance) do
        rows[#rows + 1] = {
            key = data.sideRoomModeAlias(sideIndex),
            type = "string",
            default = DISABLED_SIDE_ROOM_MODE,
            maxLen = 16,
        }
        rows[#rows + 1] = {
            key = data.sideRoomEnteredAlias(sideIndex),
            type = "bool",
            default = false,
        }
        rows[#rows + 1] = {
            key = data.sideRoomEncounterClassAlias(sideIndex),
            type = "string",
            default = "",
            maxLen = 16,
        }
    end
    return rows
end

local function buildHubRewardRows(instance)
    local rows = shallowCopyList(data.buildRewardRows())
    local baseRewardRows = data.buildRewardRows()
    for sideIndex = 1, data.maxSideDoorCount(instance) do
        for _, row in ipairs(baseRewardRows) do
            appendCopy(rows, row, data.sideRoomRewardAlias(sideIndex, row.key))
        end
    end
    return rows
end

local adapter = {
    slotForRow = slotForRow,
    isFixedIdentitySlot = isFixedSlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
        if isFixedSlot(slot) then
            return slot.roleKey
        end
        return defaultReadRoleKey(instance, rows, rowIndex, slot)
    end,

    roleForRow = function(instance, rowIndex, roleKey, slot, defaultRoleForRow)
        if isFixedSlot(slot) then
            if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
                return slot.role
            end
            return nil
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(_, _, _, roleKey, slot)
        if isFixedSlot(slot) then
            return roleKey == slot.roleKey
        end
        return nil
    end,

    fillRoleValuesForSlot = function(_, _, _, slot, values)
        if isFixedSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        return false
    end,

    roomHistoryCost = function(instance, _, _, _, _, _, _, slot)
        if slot == nil or slot.kind ~= "biomeRow" then
            return nil
        end
        return instance.biome and instance.biome.hub and instance.biome.hub.pylonRoomHistoryCost or nil
    end,
}

data = rowData.create(adapter)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)

    instance.maxSideDoorCount = maxSideDoorCount(instance)
    addSideRoomModeChoices(instance)
    addSideRoomEncounterClassChoices(instance)
    buildRouteSlots(instance)
    slotTimeline.applyRouteSlots(instance)
    data.buildRoleChoices(instance)
    buildOptionEnrichmentColors(instance)
    addFixedRoleLabels(instance)
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
            row = buildHubRoomRows(instance),
        },
        {
            key = "Rewards",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = buildHubRewardRows(instance),
        },
    }
end

function data.sideRoomModeAlias(sideIndex)
    return prefixedSideAlias(sideIndex, "ModeKey")
end

function data.sideRoomEnteredAlias(sideIndex)
    return prefixedSideAlias(sideIndex, SIDE_ROOM_ENTERED_ALIAS)
end

function data.sideRoomEncounterClassAlias(sideIndex)
    return prefixedSideAlias(sideIndex, SIDE_ROOM_ENCOUNTER_CLASS_ALIAS)
end

function data.sideRoomRewardAlias(sideIndex, rewardAlias)
    return prefixedSideAlias(sideIndex, rewardAlias)
end

function data.sideRoomModeValues(instance)
    return instance.sideRoomModeValues or {}
end

function data.sideRoomModeLabels(instance)
    return instance.sideRoomModeLabels or {}
end

function data.sideRoomEnabledMode()
    return ENABLED_SIDE_ROOM_MODE
end

function data.sideRoomDisabledMode()
    return DISABLED_SIDE_ROOM_MODE
end

function data.sideRoomEncounterClassValues(instance, sideDoor)
    if sideDoor == nil then
        return EMPTY_LIST
    end
    return instance.sideRoomEncounterClassValuesByRoomKey[sideDoor.roomKey] or EMPTY_LIST
end

function data.sideRoomEncounterClassLabels(instance)
    return instance.sideRoomEncounterClassLabels or {}
end

function data.defaultSideRoomEncounterClassKey(instance, sideDoor)
    return data.sideRoomEncounterClassValues(instance, sideDoor)[1] or ""
end

function data.resolveSideRoomEncounterClass(instance, rows, rowIndex, sideIndex, sideDoor)
    local storedKey = rows:read(rowIndex, data.sideRoomEncounterClassAlias(sideIndex)) or ""
    if storedKey ~= "" then
        return storedKey, storedKey
    end
    return storedKey, data.defaultSideRoomEncounterClassKey(instance, sideDoor)
end

function data.maxSideDoorCount(instance)
    return instance.maxSideDoorCount or 0
end

function data.sideDoorForRow(instance, rows, rowIndex, sideIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return option and option.sideDoors and option.sideDoors[sideIndex] or nil
end

function data.sideDoorCountForRow(instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return option and #(option.sideDoors or {}) or 0
end

function data.optionEnrichmentColorsForRole(instance, roleKey)
    return instance.optionEnrichmentColorsByRole[roleKey]
end

return data
