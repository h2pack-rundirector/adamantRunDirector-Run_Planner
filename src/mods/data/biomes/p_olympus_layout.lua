local layout = {}

local INDOOR_TAGS = { "Indoor" }
local OUTDOOR_TAGS = { "Outdoor" }
local INDOOR_OUTDOOR_TAGS = { "Indoor", "Outdoor" }
local CHAOS_FEATURES = { chaos = true }

local function option(key, label, opts)
    opts = opts or {}
    return {
        key = key,
        label = label,
        tags = opts.tags,
        features = opts.features,
        availability = opts.availability,
        maxCreationsThisRun = opts.maxCreationsThisRun,
        maxAppearancesThisBiome = opts.maxAppearancesThisBiome,
    }
end

local function combat(roomKey, opts)
    opts = opts or {}
    return option(roomKey, "Combat " .. string.sub(roomKey, -2), {
        tags = opts.tags,
        features = opts.features or CHAOS_FEATURES,
        availability = opts.availability,
        maxCreationsThisRun = opts.maxCreationsThisRun,
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

layout.introRoom = option("P_Intro", "Intro", {
    tags = OUTDOOR_TAGS,
    features = CHAOS_FEATURES,
    availability = { biomeDepth = { exact = 1 } },
})

layout.prebossRoom = option("P_PreBoss01", "Preboss", {
    tags = INDOOR_OUTDOOR_TAGS,
    availability = { biomeDepth = { exact = 9 } },
})

layout.combatRooms = {
    combat("P_Combat01", { tags = OUTDOOR_TAGS, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("P_Combat02", { tags = INDOOR_TAGS }),
    combat("P_Combat03", { tags = OUTDOOR_TAGS, availability = { biomeEncounterDepth = { max = 4 } } }),
    combat("P_Combat04", { tags = INDOOR_TAGS }),
    combat("P_Combat05", { tags = OUTDOOR_TAGS }),
    combat("P_Combat06", { tags = OUTDOOR_TAGS }),
    combat("P_Combat07", { tags = INDOOR_TAGS }),
    combat("P_Combat08", { tags = INDOOR_TAGS }),
    combat("P_Combat09", { tags = INDOOR_TAGS }),
    combat("P_Combat10", { tags = INDOOR_TAGS }),
    combat("P_Combat11", { tags = OUTDOOR_TAGS }),
    combat("P_Combat12", { tags = INDOOR_TAGS }),
    combat("P_Combat13", { tags = OUTDOOR_TAGS }),
    combat("P_Combat14", { tags = OUTDOOR_TAGS }),
    combat("P_Combat15", { tags = OUTDOOR_TAGS }),
    combat("P_Combat16", { tags = OUTDOOR_TAGS }),
    combat("P_Combat17", { tags = OUTDOOR_TAGS, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("P_Combat18", { tags = INDOOR_TAGS, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("P_Combat19", { tags = OUTDOOR_TAGS }),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.storyRooms = {
    option("P_Story01", "Dionysus", {
        tags = INDOOR_TAGS,
        availability = {
            biomeEncounterDepth = { minExclusive = 2 },
            biomeDepth = { max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.fountainRooms = {
    option("P_Reprieve01", "Fountain", {
        tags = INDOOR_TAGS,
        features = CHAOS_FEATURES,
        availability = {
            biomeDepth = { min = 4, max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.shopRooms = {
    option("P_Shop01", "Shop", {
        tags = OUTDOOR_TAGS,
        features = CHAOS_FEATURES,
        availability = {
            biomeEncounterDepth = { minExclusive = 4 },
            biomeDepth = { max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.minibossRooms = {
    option("P_MiniBoss01", "Talos", {
        tags = INDOOR_TAGS,
        availability = {
            biomeDepth = { min = 4, max = 7 },
            requiresMultipleOfferedDoors = true,
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("P_MiniBoss02", "Mega-Dracon", {
        tags = INDOOR_TAGS,
        availability = {
            biomeDepth = { min = 4, max = 7 },
            requiresMultipleOfferedDoors = true,
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
}

return layout
