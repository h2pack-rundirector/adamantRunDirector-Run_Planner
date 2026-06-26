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
local fixedRoomFeatures = common.fixedRoomFeatures

function slots.slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

function slots.isPrebossSlot(slot)
    return slot ~= nil and slot.kind == "preboss"
end

function slots.isFixedRoleSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

function slots.isFixedIdentitySlot(slot)
    return slots.isPrebossSlot(slot) or slots.isFixedRoleSlot(slot)
end

local function buildFixedRoleSlot(instance, ordinal, special)
    local kind = special.kind
    local roomOptions = shallowCopyList(special.roomOptions)
    local roomKey = fixedRoomKey(special)
    local features = fixedRoomFeatures(special)
    local role = {
        key = special.key or kind,
        label = special.label or special.key or kind,
        roomKey = roomKey,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = special.reward,
        features = features,
        exitCount = fixedRoomField(special, "exitCount"),
        rewardExitCount = fixedRoomField(special, "rewardExitCount"),
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
        roomKey = roomKey,
        exitCount = role.exitCount,
        rewardExitCount = role.rewardExitCount,
        roomOfferCount = special.roomOfferCount or common.rewardOfferCount(special.reward),
        roleKey = role.key,
        role = role,
        features = features,
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
        room = entry.room,
        roomKey = entry.roomKey,
        roomOptions = entry.roomOptions,
        reward = entry.reward,
        features = entry.features,
        exitCount = entry.exitCount,
        rewardExitCount = entry.rewardExitCount,
        isBiomeEntry = entry.isBiomeEntry == true,
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
        locked = entry.locked,
    })
end

function slots.buildRouteSlots(instance)
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
        buildFixedRoleSlot(instance, ordinal, slotLayout.special[ordinal])
    end
    instance.routeRowCount = #instance.routeSlots
end

return slots
