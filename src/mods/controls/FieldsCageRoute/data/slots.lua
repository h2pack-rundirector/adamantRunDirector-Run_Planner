local deps = ...
local common = deps.common

local slots = {}

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

function slots.slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

function slots.isFixedSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function buildFixedSlot(instance, entry, section)
    local roomOptions = shallowCopyList(entry.roomOptions)
    local roomKey = fixedRoomKey(entry)
    local role = {
        key = entry.key,
        label = entry.label or entry.key,
        roomKey = roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = entry.reward,
        exitCount = fixedRoomField(entry, "exitCount"),
        rewardExitCount = fixedRoomField(entry, "rewardExitCount"),
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
        rewardExitCount = role.rewardExitCount,
        roomOfferCount = entry.roomOfferCount or common.rewardOfferCount(entry.reward),
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

local function buildPickSlot(instance, ordinal)
    local slotLayout = instance.biome.slotLayout or {}
    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = applySlotDepthContext({
        rowIndex = rowIndex,
        routeOrdinal = ordinal,
        kind = "biomeRow",
        label = routeRowLabel(slotLayout, ordinal, "Pick"),
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
        buildFixedSlot(instance, entry, "fixedBeforeRoute")
    end
    for ordinal = startOrdinal, endOrdinal do
        buildPickSlot(instance, ordinal)
    end
    for _, entry in ipairs(slotLayout.fixedAfterRoute or {}) do
        buildFixedSlot(instance, entry, "fixedAfterRoute")
    end
    instance.routeRowCount = #instance.routeSlots
end

function slots.addFixedRoleLabels(instance)
    for _, slot in ipairs(instance.routeSlots or {}) do
        if slot.roleKey ~= nil then
            instance.roleLabels[slot.roleKey] = slot.label or slot.roleKey
        end
    end
end

return slots
