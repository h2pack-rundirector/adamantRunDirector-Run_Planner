local layout = {}

local INDOOR_TAGS = { "Indoor" }
local OUTDOOR_TAGS = { "Outdoor" }
local INDOOR_OUTDOOR_TAGS = { "Indoor", "Outdoor" }
local CHAOS_FEATURES = { chaos = true }
local CHAOS_SURFACE_FEATURES = { chaos = true, surfaceShop = true }
local SURFACE_SHOP_COMBAT_ROOMS = {
    P_Combat01 = true,
    P_Combat02 = true,
    P_Combat03 = true,
    P_Combat05 = true,
    P_Combat06 = true,
    P_Combat07 = true,
    P_Combat08 = true,
    P_Combat09 = true,
    P_Combat10 = true,
    P_Combat11 = true,
    P_Combat12 = true,
    P_Combat13 = true,
    P_Combat14 = true,
    P_Combat15 = true,
    P_Combat16 = true,
    P_Combat17 = true,
    P_Combat18 = true,
    P_Combat19 = true,
}

local function option(key, label, opts)
    opts = opts or {}
    local rewardDoorCount = opts.rewardDoorCount
    if rewardDoorCount == nil then
        rewardDoorCount = opts.exitCount
    end
    return {
        key = key,
        label = label,
        exitCount = opts.exitCount,
        rewardDoorCount = rewardDoorCount,
        tags = opts.tags,
        nextRoomTags = opts.nextRoomTags,
        features = opts.features,
        availability = opts.availability,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost,
        maxCreationsThisRun = opts.maxCreationsThisRun,
        maxAppearancesThisBiome = opts.maxAppearancesThisBiome,
    }
end

local function combat(roomKey, opts)
    opts = opts or {}
    local tags = opts.tags or {}
    local tagLabel = table.concat(tags, "/")
    if tagLabel ~= "" then
        tagLabel = " (" .. tagLabel .. ")"
    end
    local exitCount = opts.exitCount or 2
    return option(roomKey, "C" .. string.sub(roomKey, -2) .. tagLabel, {
        exitCount = exitCount,
        tags = opts.tags,
        features = opts.features or (SURFACE_SHOP_COMBAT_ROOMS[roomKey] and CHAOS_SURFACE_FEATURES or CHAOS_FEATURES),
        availability = opts.availability,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1,
        maxCreationsThisRun = opts.maxCreationsThisRun or 1,
        maxAppearancesThisBiome = opts.maxAppearancesThisBiome,
    })
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

layout.chaosFeatures = CHAOS_FEATURES
layout.surfaceShopFeatures = CHAOS_SURFACE_FEATURES

layout.introRoom = option("P_Intro", "Intro", {
    exitCount = 1,
    tags = OUTDOOR_TAGS,
    features = CHAOS_FEATURES,
    availability = { biomeDepthCache = { exact = 1 } },
})

layout.prebossRoom = option("P_PreBoss01", "Preboss", {
    exitCount = 1,
    tags = INDOOR_OUTDOOR_TAGS,
    availability = { biomeDepthCache = { exact = 9 } },
})

layout.combatRooms = {
    combat("P_Combat01", { tags = OUTDOOR_TAGS, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("P_Combat02", { tags = INDOOR_TAGS, availability = { biomeDepthCache = { min = 2 } } }),
    combat("P_Combat03", { tags = OUTDOOR_TAGS, availability = { biomeEncounterDepth = { max = 4 } } }),
    combat("P_Combat04", { tags = INDOOR_TAGS, availability = { biomeDepthCache = { min = 2 } } }),
    combat("P_Combat05", { tags = OUTDOOR_TAGS }),
    combat("P_Combat06", { tags = OUTDOOR_TAGS }),
    combat("P_Combat07", { tags = INDOOR_TAGS, availability = { biomeDepthCache = { min = 2 } } }),
    combat("P_Combat08", { tags = INDOOR_TAGS, availability = { biomeDepthCache = { min = 2 } } }),
    combat("P_Combat09", { tags = INDOOR_TAGS, availability = { biomeDepthCache = { min = 2 } } }),
    combat("P_Combat10", { tags = INDOOR_TAGS, availability = { biomeDepthCache = { min = 2 } } }),
    combat("P_Combat11", { tags = OUTDOOR_TAGS }),
    combat("P_Combat12", { tags = INDOOR_TAGS, availability = { biomeDepthCache = { min = 2 } } }),
    combat("P_Combat13", { tags = OUTDOOR_TAGS }),
    combat("P_Combat14", { tags = OUTDOOR_TAGS }),
    combat("P_Combat15", { tags = OUTDOOR_TAGS }),
    combat("P_Combat16", { tags = OUTDOOR_TAGS }),
    combat("P_Combat17", { tags = OUTDOOR_TAGS, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("P_Combat18", {
        tags = INDOOR_TAGS,
        availability = {
            biomeDepthCache = { min = 2 },
            biomeEncounterDepth = { min = 3 },
        },
    }),
    combat("P_Combat19", { tags = OUTDOOR_TAGS }),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.storyRooms = {
    option("P_Story01", "Dionysus", {
        exitCount = 2,
        tags = INDOOR_TAGS,
        availability = {
            biomeEncounterDepth = { minExclusive = 2 },
            biomeDepthCache = { max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.fountainRooms = {
    option("P_Reprieve01", "Fountain", {
        exitCount = 2,
        tags = INDOOR_TAGS,
        features = CHAOS_SURFACE_FEATURES,
        availability = {
            biomeDepthCache = { min = 4, max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.shopRooms = {
    option("P_Shop01", "Shop", {
        exitCount = 2,
        tags = OUTDOOR_TAGS,
        features = CHAOS_FEATURES,
        availability = {
            biomeEncounterDepth = { minExclusive = 4 },
            biomeDepthCache = { max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.minibossRooms = {
    option("P_MiniBoss01", "Talos", {
        exitCount = 2,
        tags = INDOOR_TAGS,
        biomeEncounterDepthCost = 0,
        availability = {
            biomeDepthCache = { min = 4, max = 7 },
            requiresMultipleOfferedDoors = true,
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("P_MiniBoss02", "Mega-Dracon", {
        exitCount = 1,
        tags = INDOOR_TAGS,
        nextRoomTags = OUTDOOR_TAGS,
        biomeEncounterDepthCost = 1,
        availability = {
            biomeDepthCache = { min = 4, max = 7 },
            requiresMultipleOfferedDoors = true,
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
}

return layout
