local layout = {}

local function option(key, label, opts)
    opts = opts or {}
    return {
        key = key,
        label = label,
        availability = opts.availability,
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

layout.introRoom = option("Q_Intro", "Intro", {
    availability = { biomeDepth = { exact = 1 } },
})

layout.prebossRoom = option("Q_PreBoss01", "Preboss", {
    availability = { biomeDepth = { exact = 7 } },
})

layout.combatRooms = {
    combat("Q_Combat01", { availability = { biomeDepth = { maxExclusive = 7 } } }),
    combat("Q_Combat02", { availability = { biomeDepth = { maxExclusive = 7 } } }),
    combat("Q_Combat03", {
        availability = {
            biomeDepth = { exact = 2 },
        },
    }),
    combat("Q_Combat04", { availability = { biomeDepth = { maxExclusive = 7 } } }),
    combat("Q_Combat05", {
        availability = {
            biomeDepth = { exact = 2 },
        },
    }),
    combat("Q_Combat06", { availability = { biomeDepth = { minExclusive = 3 } } }),
    combat("Q_Combat07"),
    combat("Q_Combat08", { availability = { biomeDepth = { maxExclusive = 7 } } }),
    combat("Q_Combat09", { availability = { biomeDepth = { minExclusive = 3 } } }),
    combat("Q_Combat10", { availability = { biomeDepth = { exact = 1 } } }),
    combat("Q_Combat11", { availability = { biomeDepth = { exact = 1 } } }),
    combat("Q_Combat12", {
        availability = {
            biomeDepth = { exact = 5 },
        },
    }),
    combat("Q_Combat13", {
        availability = {
            biomeDepth = { exact = 5 },
        },
    }),
    combat("Q_Combat14", {
        availability = {
            biomeDepth = { exact = 5 },
        },
    }),
    combat("Q_Combat15", {
        availability = {
            biomeDepth = { exact = 2 },
        },
    }),
    combat("Q_Combat16"),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.vanillaDepthHints = {
    [2] = { "Q_Combat03", "Q_Combat05", "Q_Combat15" },
    [3] = { "Q_MiniBoss02", "Q_MiniBoss05" },
    [5] = { "Q_Combat12", "Q_Combat13", "Q_Combat14" },
    [6] = { "Q_MiniBoss03", "Q_MiniBoss04" },
    [7] = { "Q_PreBoss01" },
}

layout.minibossRooms = {
    option("Q_MiniBoss02", "Brute", {
        availability = {
            biomeDepth = { exact = 3 },
        },
    }),
    option("Q_MiniBoss03", "Typhon Tail", {
        availability = {
            biomeDepth = { exact = 6 },
        },
    }),
    option("Q_MiniBoss04", "Typhon Eye", {
        availability = {
            biomeDepth = { exact = 6 },
        },
    }),
    option("Q_MiniBoss05", "Stalker", {
        availability = {
            biomeDepth = { exact = 3 },
        },
    }),
}

return layout
