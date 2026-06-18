local data = {}

local EMPTY_LIST = {}

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

local function addSlot(instance, feature)
    local rowIndex = #instance.slots + 1
    instance.slots[rowIndex] = {
        rowIndex = rowIndex,
        key = feature.key,
        label = feature.label or feature.key,
        featureKey = feature.featureKey,
        feature = feature,
        plannedSpacingRooms = feature.plannedSpacingRooms,
    }
end

local function buildSlots(instance)
    local routeLookup = routeBiomeLookup(instance.route)
    instance.slots = {}

    for _, featureKey in ipairs(instance.features.ordered or EMPTY_LIST) do
        local feature = instance.features.byKey and instance.features.byKey[featureKey] or nil
        if feature ~= nil and routeHasFeature(routeLookup, feature) then
            addSlot(instance, feature)
        end
    end

    instance.slotCount = #instance.slots
end

function data.prepare(instance)
    instance.route = instance.route or {}
    instance.routeKey = instance.route.key or instance.routeKey or instance.name
    instance.label = instance.label or "Features"
    instance.features = instance.features or {}
    instance.biomeLookup = instance.biomeLookup or {}
    buildSlots(instance)
    return instance
end

function data.storage(instance)
    return {
        {
            key = "Targets",
            type = "table",
            minRows = instance.slotCount,
            defaultRows = instance.slotCount,
            maxRows = instance.slotCount,
            row = {
                { key = "TargetKey", type = "string", default = "", maxLen = 96 },
                { key = "BiomeKey", type = "string", default = "", maxLen = 8 },
                { key = "RowIndex", type = "string", default = "", maxLen = 16 },
            },
        },
    }
end

function data.targetKey(biomeKey, rowIndex)
    if biomeKey == nil or biomeKey == "" or rowIndex == nil or rowIndex == "" then
        return ""
    end
    return tostring(biomeKey) .. ":" .. tostring(rowIndex)
end

return data
