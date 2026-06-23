local deps = ...
local common = deps.common
local timeline = deps.timeline
local rowEngine = deps.rowEngine

local VANILLA_SIDE_ROOM_MODE = ""
local ENABLED_SIDE_ROOM_MODE = "Enabled"
local DISABLED_SIDE_ROOM_MODE = "Disabled"

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local buildOptionChoices = common.buildOptionChoices
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

local function isFixedSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function buildFixedSlot(instance, entry, section)
    local roomOptions = shallowCopyList(entry.roomOptions)
    local role = {
        key = entry.key,
        label = entry.label or entry.key,
        roomKey = entry.roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = entry.reward,
        features = entry.features,
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
        roomKey = entry.roomKey,
        roleKey = role.key,
        role = role,
        locked = entry.locked,
        features = entry.features,
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
        biomeDepthCacheCost = routeBiomeDepthCacheCost(slotLayout),
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
        { key = VANILLA_SIDE_ROOM_MODE, label = "Vanilla" },
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

local function buildSideRoomRows()
    return {
        {
            key = "ModeKey",
            type = "string",
            default = VANILLA_SIDE_ROOM_MODE,
            maxLen = 16,
        },
    }
end

local function prepareSideRoomRows(instance)
    instance.sideRoomRowOffsetByRouteRow = {}
    local rowCount = 0
    for _, slot in ipairs(instance.routeSlots or {}) do
        if slot.kind == "biomeRow" then
            instance.sideRoomRowOffsetByRouteRow[slot.rowIndex] = rowCount
            rowCount = rowCount + (instance.maxSideDoorCount or 0)
        end
    end
    instance.sideRoomRowCount = rowCount
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

data = rowEngine.create(adapter)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)

    instance.maxSideDoorCount = maxSideDoorCount(instance)
    addSideRoomModeChoices(instance)
    buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    prepareSideRoomRows(instance)
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
        {
            key = "SideRooms",
            type = "table",
            minRows = instance.sideRoomRowCount,
            defaultRows = instance.sideRoomRowCount,
            maxRows = instance.sideRoomRowCount,
            row = buildSideRoomRows(),
        },
        {
            key = "SideRewards",
            type = "table",
            minRows = instance.sideRoomRowCount,
            defaultRows = instance.sideRoomRowCount,
            maxRows = instance.sideRoomRowCount,
            row = data.buildRewardRows(),
        },
    }
end

function data.sideRoomModeAlias()
    return "ModeKey"
end

function data.sideRoomRewardAlias(_, rewardAlias)
    return rewardAlias or ""
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

function data.maxSideDoorCount(instance)
    return instance.maxSideDoorCount or 0
end

function data.sideRoomRowIndex(instance, rowIndex, sideIndex)
    local offset = instance.sideRoomRowOffsetByRouteRow
        and instance.sideRoomRowOffsetByRouteRow[math.floor(tonumber(rowIndex) or 0)]
        or nil
    sideIndex = math.floor(tonumber(sideIndex) or 0)
    if offset == nil or sideIndex < 1 or sideIndex > data.maxSideDoorCount(instance) then
        return nil
    end
    return offset + sideIndex
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
