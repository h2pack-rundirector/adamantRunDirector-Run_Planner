local layout = {}

local CHAOS_FEATURES = { chaos = true }
local CHAOS_WELL_FEATURES = { chaos = true, wellShop = true }

local function option(key, label, opts)
    opts = opts or {}
    return {
        key = key,
        label = label,
        exitCount = opts.exitCount,
        features = opts.features,
        availability = opts.availability,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost,
        maxCreationsThisRun = opts.maxCreationsThisRun,
        maxAppearancesThisBiome = opts.maxAppearancesThisBiome,
    }
end

local function combat(roomKey, opts)
    opts = opts or {}
    local exitCount = opts.exitCount or 1
    local exitLabel = exitCount == 1 and "1 Exit" or tostring(exitCount) .. " Exits"
    return option(roomKey, "C" .. string.sub(roomKey, -2) .. " (" .. exitLabel .. ")", {
        exitCount = opts.exitCount,
        features = opts.features or CHAOS_WELL_FEATURES,
        availability = opts.availability,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1,
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

local function pickByKey(lookup, keys)
    local values = {}
    for _, key in ipairs(keys) do
        values[#values + 1] = lookup[key]
    end
    return values
end

layout.chaosFeatures = CHAOS_FEATURES
layout.wellShopFeatures = CHAOS_WELL_FEATURES

layout.openingRooms = {
    option("F_Opening01", "Opening 1", { exitCount = 1, features = CHAOS_FEATURES }),
    option("F_Opening02", "Opening 2", { exitCount = 1, features = CHAOS_FEATURES }),
    option("F_Opening03", "Opening 3", { exitCount = 1, features = CHAOS_FEATURES }),
}

layout.prebossRoom = option("F_PreBoss01", "Preboss", {
    exitCount = 1,
    availability = {
        biomeDepthCache = { exact = 10 },
    },
})

layout.combatRooms = {
    combat("F_Combat01", { exitCount = 1, availability = { biomeEncounterDepth = { max = 5 } } }),
    combat("F_Combat02", { exitCount = 2, availability = { biomeEncounterDepth = { max = 5 } } }),
    combat("F_Combat03", { exitCount = 2, availability = { biomeEncounterDepth = { max = 5 } } }),
    combat("F_Combat04", { exitCount = 2, availability = { biomeEncounterDepth = { max = 5 } } }),
    combat("F_Combat05", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat06", { exitCount = 2 }),
    combat("F_Combat07", { exitCount = 2 }),
    combat("F_Combat08", { exitCount = 2, availability = { biomeEncounterDepth = { max = 5 } } }),
    combat("F_Combat09", { exitCount = 1, availability = { biomeEncounterDepth = { max = 4 } } }),
    combat("F_Combat10", { exitCount = 1, availability = { biomeEncounterDepth = { max = 5 } } }),
    combat("F_Combat11", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat12", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat13", { exitCount = 2 }),
    combat("F_Combat14", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat15", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat16", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat17", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat18", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat19", { exitCount = 2, availability = { biomeEncounterDepth = { max = 5 } } }),
    combat("F_Combat20", { exitCount = 2, availability = { biomeEncounterDepth = { min = 5 } } }),
    combat("F_Combat21", { exitCount = 2, availability = { biomeEncounterDepth = { max = 5 } } }),
    combat("F_Combat22", { exitCount = 2, availability = { biomeEncounterDepth = { max = 5 } } }),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.devotionCombatRooms = pickByKey(layout.combatRoomsByKey, {
    "F_Combat05", "F_Combat06", "F_Combat07",
    "F_Combat11", "F_Combat12", "F_Combat13",
    "F_Combat14", "F_Combat15", "F_Combat16",
    "F_Combat17", "F_Combat18", "F_Combat20",
})

layout.storyRooms = {
    option("F_Story01", "Arachne", {
        exitCount = 2,
        features = CHAOS_FEATURES,
        availability = {
            biomeDepthCache = { min = 4, max = 8 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.fountainRooms = {
    option("F_Reprieve01", "Fountain", {
        exitCount = 2,
        features = CHAOS_FEATURES,
        availability = {
            biomeDepthCache = { min = 4, max = 8 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.shopRooms = {
    option("F_Shop01", "Shop", {
        exitCount = 2,
        features = CHAOS_FEATURES,
        availability = {
            biomeDepthCache = { min = 4, max = 6 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.minibossRooms = {
    option("F_MiniBoss01", "Root-Stalker", {
        exitCount = 1,
        biomeEncounterDepthCost = 1,
        availability = { biomeDepthCache = { min = 4, max = 6 } },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("F_MiniBoss02", "Shadow-Spiller", {
        exitCount = 1,
        biomeEncounterDepthCost = 1,
        availability = {
            biomeDepthCache = { min = 4, max = 6 },
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("F_MiniBoss03", "Master-Slicer", {
        exitCount = 1,
        biomeEncounterDepthCost = 1,
        availability = {
            biomeDepthCache = { min = 4, max = 6 },
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
}

return layout
