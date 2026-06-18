local layout = {}

local CHAOS_FEATURES = { chaos = true }
local CHAOS_WELL_FEATURES = { chaos = true, wellShop = true }
local WELL_SHOP_COMBAT_ROOMS = {
    G_Combat01 = true,
    G_Combat02 = true,
    G_Combat03 = true,
    G_Combat07 = true,
    G_Combat08 = true,
    G_Combat09 = true,
    G_Combat10 = true,
    G_Combat11 = true,
    G_Combat12 = true,
    G_Combat13 = true,
    G_Combat14 = true,
    G_Combat15 = true,
    G_Combat16 = true,
    G_Combat17 = true,
    G_Combat18 = true,
    G_Combat19 = true,
    G_Combat20 = true,
}

local function option(key, label, opts)
    opts = opts or {}
    return {
        key = key,
        label = label,
        exitCount = opts.exitCount,
        features = opts.features,
        availability = opts.availability,
        maxCreationsThisRun = opts.maxCreationsThisRun,
        maxAppearancesThisBiome = opts.maxAppearancesThisBiome,
    }
end

local function combat(roomKey, opts)
    opts = opts or {}
    return option(roomKey, "Combat " .. string.sub(roomKey, -2), {
        exitCount = opts.exitCount,
        features = opts.features or (WELL_SHOP_COMBAT_ROOMS[roomKey] and CHAOS_WELL_FEATURES or CHAOS_FEATURES),
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

local function pickByKey(lookup, keys)
    local values = {}
    for _, key in ipairs(keys) do
        values[#values + 1] = lookup[key]
    end
    return values
end

layout.chaosFeatures = CHAOS_FEATURES
layout.wellShopFeatures = CHAOS_WELL_FEATURES

layout.introRoom = option("G_Intro", "Intro", {
    exitCount = 1,
    features = CHAOS_FEATURES,
    availability = { biomeDepth = { exact = 1 } },
})

layout.prebossRoom = option("G_PreBoss01", "Preboss", {
    exitCount = 1,
    availability = { biomeDepth = { exact = 8 } },
})

layout.combatRooms = {
    combat("G_Combat01", { exitCount = 2, availability = { biomeEncounterDepth = { max = 3 } } }),
    combat("G_Combat02", { exitCount = 3 }),
    combat("G_Combat03", { exitCount = 3, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat04", { exitCount = 2, availability = { biomeEncounterDepth = { max = 3 } } }),
    combat("G_Combat05", { exitCount = 3, availability = { biomeEncounterDepth = { max = 3 } } }),
    combat("G_Combat06", { exitCount = 2, availability = { biomeEncounterDepth = { max = 3 } } }),
    combat("G_Combat07", { exitCount = 2, availability = { biomeEncounterDepth = { max = 3 } } }),
    combat("G_Combat08", { exitCount = 2, availability = { biomeEncounterDepth = { max = 3 } } }),
    combat("G_Combat09", { exitCount = 3, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat10", { exitCount = 2, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat11", { exitCount = 2, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat12", { exitCount = 2, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat13", { exitCount = 2, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat14", { exitCount = 3, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat15", { exitCount = 3, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat16", { exitCount = 2, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat17", { exitCount = 3, availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("G_Combat18", {
        exitCount = 3,
        availability = {
            biomeEncounterDepth = { max = 2 },
            biomeDepth = { max = 3 },
        },
    }),
    combat("G_Combat19", { exitCount = 2, availability = { biomeEncounterDepth = { max = 3 } } }),
    combat("G_Combat20", { exitCount = 3, availability = { biomeEncounterDepth = { max = 3 } } }),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.trialCombatRooms = pickByKey(layout.combatRoomsByKey, {
    "G_Combat02", "G_Combat03", "G_Combat09",
    "G_Combat10", "G_Combat11", "G_Combat12",
    "G_Combat13", "G_Combat14", "G_Combat15",
    "G_Combat16", "G_Combat17",
})

layout.storyRooms = {
    option("G_Story01", "Narcissus", {
        exitCount = 1,
        features = CHAOS_FEATURES,
        availability = {
            biomeDepth = { min = 3, max = 6 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.fountainRooms = {
    option("G_Reprieve01", "Fountain", {
        exitCount = 2,
        features = CHAOS_FEATURES,
        availability = {
            biomeDepth = { min = 4, max = 6 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.shopRooms = {
    option("G_Shop01", "Shop", {
        exitCount = 2,
        features = CHAOS_FEATURES,
        availability = {
            biomeDepth = { min = 3, max = 5 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.minibossRooms = {
    option("G_MiniBoss01", "Deep Serpent", {
        exitCount = 2,
        features = CHAOS_FEATURES,
        availability = { biomeDepth = { min = 4, max = 7 } },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("G_MiniBoss02", "King Vermin", {
        exitCount = 1,
        features = CHAOS_FEATURES,
        availability = {
            biomeDepth = { min = 4, max = 7 },
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("G_MiniBoss03", "Hellifish", {
        exitCount = 2,
        features = CHAOS_FEATURES,
        availability = { biomeDepth = { min = 4, max = 7 } },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
}

return layout
