local layout = {}

local function option(key, label, opts)
    opts = opts or {}
    return {
        key = key,
        label = label,
        availability = opts.availability,
        maxCreationsThisRun = opts.maxCreationsThisRun,
        maxAppearancesThisBiome = opts.maxAppearancesThisBiome,
    }
end

local function combat(roomKey, opts)
    return option(roomKey, "Combat " .. string.sub(roomKey, -2), opts)
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

layout.introRoom = option("P_Intro", "Intro", {
    availability = { biomeDepth = { exact = 1 } },
})

layout.prebossRoom = option("P_PreBoss01", "Preboss", {
    availability = { biomeDepth = { exact = 9 } },
})

layout.combatRooms = {
    combat("P_Combat01", { availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("P_Combat02"),
    combat("P_Combat03", { availability = { biomeEncounterDepth = { max = 4 } } }),
    combat("P_Combat04"),
    combat("P_Combat05"),
    combat("P_Combat06"),
    combat("P_Combat07"),
    combat("P_Combat08"),
    combat("P_Combat09"),
    combat("P_Combat10"),
    combat("P_Combat11"),
    combat("P_Combat12"),
    combat("P_Combat13"),
    combat("P_Combat14"),
    combat("P_Combat15"),
    combat("P_Combat16"),
    combat("P_Combat17", { availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("P_Combat18", { availability = { biomeEncounterDepth = { min = 3 } } }),
    combat("P_Combat19"),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.storyRooms = {
    option("P_Story01", "Dionysus", {
        availability = {
            biomeEncounterDepth = { minExclusive = 2 },
            biomeDepth = { max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.fountainRooms = {
    option("P_Reprieve01", "Fountain", {
        availability = {
            biomeDepth = { min = 4, max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.shopRooms = {
    option("P_Shop01", "Shop", {
        availability = {
            biomeEncounterDepth = { minExclusive = 4 },
            biomeDepth = { max = 7 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.minibossRooms = {
    option("P_MiniBoss01", "Talos", {
        availability = {
            biomeDepth = { min = 4, max = 7 },
            requiresMultipleOfferedDoors = true,
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("P_MiniBoss02", "Mega-Dracon", {
        availability = {
            biomeDepth = { min = 4, max = 7 },
            requiresMultipleOfferedDoors = true,
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
}

return layout
