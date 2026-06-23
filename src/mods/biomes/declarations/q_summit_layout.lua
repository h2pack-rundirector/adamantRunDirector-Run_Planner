local layout = {}

local SURFACE_SHOP_FEATURES = { surfaceShop = true }
local SURFACE_SHOP_COMBAT_ROOMS = {
    Q_Combat01 = true,
    Q_Combat02 = true,
    Q_Combat03 = true,
    Q_Combat04 = true,
    Q_Combat05 = true,
    Q_Combat06 = true,
    Q_Combat07 = true,
    Q_Combat08 = true,
    Q_Combat09 = true,
    Q_Combat10 = true,
    Q_Combat11 = true,
    Q_Combat12 = true,
    Q_Combat13 = true,
    Q_Combat16 = true,
}

local function option(key, label, opts)
    opts = opts or {}
    return {
        key = key,
        label = label,
        features = opts.features,
        availability = opts.availability,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost,
    }
end

local function combat(roomKey, opts)
    opts = opts or {}
    opts.features = opts.features or (SURFACE_SHOP_COMBAT_ROOMS[roomKey] and SURFACE_SHOP_FEATURES or nil)
    opts.biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1
    return option(roomKey, "Combat " .. string.sub(roomKey, -2), opts)
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

layout.surfaceShopFeatures = SURFACE_SHOP_FEATURES

layout.introRoom = option("Q_Intro", "Intro", {
    availability = { biomeDepthCache = { exact = 1 } },
})

layout.prebossRoom = option("Q_PreBoss01", "Preboss", {
    availability = { biomeDepthCache = { exact = 7 } },
})

layout.combatRooms = {
    combat("Q_Combat01", { availability = { biomeDepthCache = { exact = 4 } } }),
    combat("Q_Combat02", { availability = { biomeDepthCache = { exact = 4 } } }),
    combat("Q_Combat03", { availability = { biomeDepthCache = { exact = 2 } } }),
    combat("Q_Combat04", { availability = { biomeDepthCache = { exact = 4 } } }),
    combat("Q_Combat05", { availability = { biomeDepthCache = { exact = 2 } } }),
    combat("Q_Combat06", { availability = { biomeDepthCache = { exact = 4 } } }),
    combat("Q_Combat07", { availability = { biomeDepthCache = { exact = 4 } } }),
    combat("Q_Combat08", { availability = { biomeDepthCache = { exact = 4 } } }),
    combat("Q_Combat09", { availability = { biomeDepthCache = { exact = 4 } } }),
    combat("Q_Combat10", { availability = { biomeDepthCache = { exact = 1 } } }),
    combat("Q_Combat11", { availability = { biomeDepthCache = { exact = 1 } } }),
    combat("Q_Combat12", { availability = { biomeDepthCache = { exact = 5 } } }),
    combat("Q_Combat13", { availability = { biomeDepthCache = { exact = 5 } } }),
    combat("Q_Combat14", { availability = { biomeDepthCache = { exact = 5 } } }),
    combat("Q_Combat15", { availability = { biomeDepthCache = { exact = 2 } } }),
    combat("Q_Combat16", { availability = { biomeDepthCache = { exact = 4 } } }),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.minibossRooms = {
    option("Q_MiniBoss02", "Brute", {
        biomeEncounterDepthCost = 1,
        availability = {
            biomeDepthCache = { exact = 3 },
        },
    }),
    option("Q_MiniBoss03", "Typhon Tail", {
        biomeEncounterDepthCost = 1,
        availability = {
            biomeDepthCache = { exact = 6 },
        },
    }),
    option("Q_MiniBoss04", "Typhon Eye", {
        biomeEncounterDepthCost = 0,
        availability = {
            biomeDepthCache = { exact = 6 },
        },
    }),
    option("Q_MiniBoss05", "Stalker", {
        biomeEncounterDepthCost = 1,
        availability = {
            biomeDepthCache = { exact = 3 },
        },
    }),
}

return layout
