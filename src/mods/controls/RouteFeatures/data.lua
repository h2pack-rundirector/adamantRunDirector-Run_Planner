local data = {}

local EMPTY_LIST = {}
data.DEFAULT_MANAGED_COUNT = 1
data.MAX_MANAGED_COUNT = 10
data.MANAGED_COUNT_VALUES = {
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
}

local function routeBiomeLookup(route)
    local lookup = {}
    for _, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        lookup[biomeKey] = true
    end
    return lookup
end

local function routeHasFeature(routeLookup, feature)
    for biomeKey in pairs(feature and feature.biomes or {}) do
        if routeLookup[biomeKey] then
            return true
        end
    end
    return false
end

local function clampCount(value, defaultValue, maxValue)
    local count = math.floor(tonumber(value) or defaultValue or data.DEFAULT_MANAGED_COUNT)
    if count < 1 then
        return 1
    end
    if count > maxValue then
        return maxValue
    end
    return count
end

local function addSlot(instance, feature, slotIndex, slotCount)
    local rowIndex = #instance.slots + 1
    local label = "Entry"
    local key = feature.key
    if slotCount > 1 then
        label = label .. " " .. tostring(slotIndex)
        key = key .. tostring(slotIndex)
    end
    instance.slots[rowIndex] = {
        rowIndex = rowIndex,
        key = key,
        label = label,
        slotIndex = slotIndex,
        featureKey = feature.featureKey,
        feature = feature,
        plannedSpacingRooms = feature.plannedSpacingRooms,
    }
end

local function buildSlots(instance)
    local routeLookup = routeBiomeLookup(instance.route)
    local feature = instance.feature
    instance.slots = {}

    if feature ~= nil and routeHasFeature(routeLookup, feature) then
        local slotCount = instance.maxManagedCount
        for slotIndex = 1, slotCount do
            addSlot(instance, feature, slotIndex, slotCount)
        end
    end

    instance.slotCount = #instance.slots
end

function data.prepare(instance)
    instance.route = instance.route or {}
    instance.routeKey = instance.route.key or instance.routeKey or instance.name
    instance.label = instance.label or (instance.feature and instance.feature.label) or "Feature"
    instance.maxManagedCount = clampCount(
        instance.feature and instance.feature.maxManagedCount,
        data.MAX_MANAGED_COUNT,
        data.MAX_MANAGED_COUNT
    )
    instance.defaultManagedCount = clampCount(
        instance.feature and instance.feature.defaultManagedCount,
        data.DEFAULT_MANAGED_COUNT,
        instance.maxManagedCount
    )
    instance.biomeLookup = instance.biomeLookup or {}
    buildSlots(instance)
    return instance
end

function data.storage(instance)
    return {
        {
            key = "ManagedCount",
            type = "string",
            default = tostring(instance.defaultManagedCount),
            maxLen = 2,
        },
        {
            key = "Targets",
            type = "table",
            minRows = instance.maxManagedCount,
            defaultRows = instance.maxManagedCount,
            maxRows = instance.maxManagedCount,
            row = {
                { key = "TargetKey", type = "string", default = "", maxLen = 96 },
                { key = "BiomeKey", type = "string", default = "", maxLen = 8 },
                { key = "RowIndex", type = "string", default = "", maxLen = 16 },
            },
        },
    }
end

function data.clampManagedCount(instance, value)
    return clampCount(value, instance.defaultManagedCount, instance.maxManagedCount)
end

function data.targetKey(biomeKey, rowIndex)
    if biomeKey == nil or biomeKey == "" or rowIndex == nil or rowIndex == "" then
        return ""
    end
    return tostring(biomeKey) .. ":" .. tostring(rowIndex)
end

return data
