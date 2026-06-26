local deps = ...
local common = deps.common

local PREBOSS_ROLE_KEY = "Preboss"

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local buildOptionChoices = common.buildOptionChoices
local fixedBiomeDepthCacheCost = common.fixedBiomeDepthCacheCost
local routeBiomeDepthCacheCost = common.routeBiomeDepthCacheCost
local routeStartOrdinal = common.routeStartOrdinal
local routeEndOrdinal = common.routeEndOrdinal
local routeRowLabel = common.routeRowLabel
local applySlotDepthContext = common.applySlotDepthContext
local fixedRoomKey = common.fixedRoomKey
local fixedRoomField = common.fixedRoomField

local slots = {}

function slots.slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

function slots.isFixedSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

function slots.isRouteSlot(slot)
    return slot ~= nil and slot.kind == "biomeRow"
end

function slots.isPrebossSlot(slot)
    return slot ~= nil and slot.kind == "preboss"
end

local function buildFixedSlot(instance, entry, kind, defaultKey)
    local roomOptions = shallowCopyList(entry.roomOptions)
    local key = entry.key or defaultKey or kind
    local roomKey = fixedRoomKey(entry)
    local role = {
        key = key,
        label = entry.label or key,
        roomKey = roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = entry.reward,
        exitCount = fixedRoomField(entry, "exitCount"),
        rewardExitCount = fixedRoomField(entry, "rewardExitCount"),
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    }
    if kind == "preboss" then
        role.roomOptions = nil
        role.optionsByKey = nil
    else
        buildOptionChoices(role)
    end

    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = entry.routeOrdinal or 0,
        kind = kind or entry.kind or "fixed",
        isBiomeEntry = entry.isBiomeEntry == true,
        label = entry.label or key,
        roomKey = roomKey,
        roomOptions = roomOptions,
        exitCount = role.exitCount,
        rewardExitCount = role.rewardExitCount,
        roleKey = role.key,
        role = role,
        locked = entry.locked,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    }, {
        biomeDepthCache = entry.biomeDepthCache,
        biomeDepthCacheCost = fixedBiomeDepthCacheCost(instance.biome.slotLayout, entry),
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
    })
end

local function buildRouteSlot(instance, ordinal)
    local slotLayout = instance.biome.slotLayout or {}
    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = ordinal,
        kind = "biomeRow",
        label = routeRowLabel(slotLayout, ordinal, "Step"),
    }, {
        biomeDepthCacheCost = routeBiomeDepthCacheCost(slotLayout),
    })
end

function slots.buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startOrdinal = routeStartOrdinal(slotLayout)
    local endOrdinal = routeEndOrdinal(slotLayout, startOrdinal)

    instance.routeSlots = {}
    for _, entry in ipairs(slotLayout.fixedBeforeRoute or {}) do
        buildFixedSlot(instance, entry, entry.kind or "intro", entry.key or "Intro")
    end
    for ordinal = startOrdinal, endOrdinal do
        buildRouteSlot(instance, ordinal)
    end
    for _, entry in ipairs(slotLayout.fixedAfterGoals or {}) do
        buildFixedSlot(instance, entry, "preboss", PREBOSS_ROLE_KEY)
    end
    instance.routeRowCount = #instance.routeSlots
end

return slots
