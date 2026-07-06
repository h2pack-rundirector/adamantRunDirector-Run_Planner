local function standardExits(count)
    local exits = {}
    for index = 1, count do
        exits[index] = {
            tags = { "Standard" },
        }
    end
    return exits
end

local function room(key, label, opts)
    opts = opts or {}

    return {
        key = key,
        label = label,
        kind = opts.kind,
        roomTemplate = opts.roomTemplate,
        tags = opts.tags,
        eligibility = opts.eligibility,
        force = opts.force,
        caps = opts.caps or {},
        exits = opts.exits or standardExits(opts.exitCount or 0),
        encounterProfile = opts.encounterProfile,
        offerProfile = opts.offerProfile,
        terminal = opts.terminal,
        counters = opts.counters,
    }
end

local rooms = {
    room("F_Opening01", "Opening 1", {
        kind = "Opening",
        roomTemplate = "FixedOpening",
        tags = { "Opening" },
        exitCount = 1,
        encounterProfile = "None",
        counters = {
            roomHistoryCost = 1,
            biomeDepthCacheCost = 0,
            biomeEncounterDepthCost = 0,
        },
    }),

    room("F_Combat01", "C01", {
        kind = "Combat",
        roomTemplate = "StandardCombat",
        tags = { "Combat" },
        exitCount = 1,
        eligibility = {
            kind = "BiomeEncounterDepth",
            comparison = "<=",
            value = 5,
            code = "f_combat01_late",
            presentation = "hide",
        },
        caps = {
            maxCreationsThisRun = 1,
        },
        encounterProfile = "StandardCombat",
        offerProfile = "RunProgressMajorMinor",
        counters = {
            roomHistoryCost = 1,
            biomeDepthCacheCost = 1,
            biomeEncounterDepthCost = 1,
        },
    }),

    room("F_Combat02", "C02", {
        kind = "Combat",
        roomTemplate = "StandardCombat",
        tags = { "Combat" },
        exitCount = 2,
        eligibility = {
            kind = "BiomeEncounterDepth",
            comparison = "<=",
            value = 5,
            code = "f_combat02_late",
            presentation = "hide",
        },
        caps = {
            maxCreationsThisRun = 1,
        },
        encounterProfile = "StandardCombat",
        offerProfile = "RunProgressMajorMinor",
        counters = {
            roomHistoryCost = 1,
            biomeDepthCacheCost = 1,
            biomeEncounterDepthCost = 1,
        },
    }),

    room("F_Shop01", "Shop", {
        kind = "Shop",
        roomTemplate = "Shop",
        tags = { "Shop" },
        exitCount = 2,
        eligibility = {
            kind = "All",
            requirements = {
                {
                    kind = "BiomeDepthCache",
                    comparison = ">=",
                    value = 4,
                    code = "f_shop_too_early",
                    presentation = "invalid",
                },
                {
                    kind = "BiomeDepthCache",
                    comparison = "<=",
                    value = 6,
                    code = "f_shop_too_late",
                    presentation = "invalid",
                },
            },
        },
        force = {
            kind = "BiomeDepthWindow",
            axis = "BiomeDepthCache",
            start = 4,
            deadline = 6,
        },
        caps = {
            maxCreationsThisRun = 1,
        },
        encounterProfile = "None",
        offerProfile = "WorldShop",
        counters = {
            roomHistoryCost = 1,
            biomeDepthCacheCost = 1,
            biomeEncounterDepthCost = 0,
        },
    }),

    room("F_PreBoss01", "Preboss", {
        kind = "Preboss",
        roomTemplate = "Preboss",
        tags = { "Preboss", "Terminal" },
        terminal = true,
        exits = {},
        eligibility = {
            kind = "BiomeDepthCache",
            comparison = ">=",
            value = 10,
            code = "f_preboss_too_early",
            presentation = "hide",
        },
        force = {
            kind = "BiomeDepthWindow",
            axis = "BiomeDepthCache",
            start = 10,
            deadline = 10,
        },
        encounterProfile = "None",
        offerProfile = "PrebossShopOrFreeReward",
        counters = {
            roomHistoryCost = 1,
            biomeDepthCacheCost = 0,
            biomeEncounterDepthCost = 0,
        },
    }),
}

return {
    key = "F",
    label = "Erebus",
    routeKey = "Underworld",
    structure = {
        kind = "linear",
        startRoomKey = "F_Opening01",
        terminal = {
            prebossRoomKey = "F_PreBoss01",
        },
    },
    rooms = rooms,
}
