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

local function counters(roomHistoryCost, biomeDepthCacheCost, biomeEncounterDepthCost)
    return {
        roomHistoryCost = roomHistoryCost,
        biomeDepthCacheCost = biomeDepthCacheCost,
        biomeEncounterDepthCost = biomeEncounterDepthCost,
    }
end

local function combatDepthEligibility(code, comparison, value)
    return {
        kind = "BiomeEncounterDepth",
        comparison = comparison,
        value = value,
        code = code,
        presentation = "hide",
    }
end

local function earlyCombatEligibility(code, max)
    return combatDepthEligibility(code, "<=", max or 5)
end

local function lateCombatEligibility(code)
    return combatDepthEligibility(code, ">=", 5)
end

local function combatRoom(key, label, opts)
    opts = opts or {}
    return room(key, label, {
        kind = "Combat",
        roomTemplate = "StandardCombat",
        tags = { "Combat" },
        exitCount = opts.exitCount or 2,
        eligibility = opts.eligibility,
        caps = {
            maxCreationsThisRun = 1,
        },
        encounterProfile = "StandardCombat",
        offerProfile = "RunProgressMajorMinor",
        counters = counters(1, 1, 1),
    })
end

local function depthWindowEligibility(prefix, min, max)
    return {
        kind = "All",
        requirements = {
            {
                kind = "BiomeDepthCache",
                comparison = ">=",
                value = min,
                code = prefix .. "_too_early",
                presentation = "invalid",
            },
            {
                kind = "BiomeDepthCache",
                comparison = "<=",
                value = max,
                code = prefix .. "_too_late",
                presentation = "invalid",
            },
        },
    }
end

local rooms = {
    room("F_Opening01", "Opening 1", {
        kind = "Opening",
        roomTemplate = "FixedOpening",
        tags = { "Opening" },
        exitCount = 1,
        encounterProfile = "None",
        counters = counters(1, 0, 0),
    }),

    combatRoom("F_Combat01", "C01", {
        exitCount = 1,
        eligibility = earlyCombatEligibility("f_combat01_late"),
    }),

    combatRoom("F_Combat02", "C02", {
        exitCount = 2,
        eligibility = earlyCombatEligibility("f_combat02_late"),
    }),

    combatRoom("F_Combat03", "C03", {
        eligibility = earlyCombatEligibility("f_combat03_late"),
    }),

    combatRoom("F_Combat04", "C04", {
        eligibility = earlyCombatEligibility("f_combat04_late"),
    }),

    combatRoom("F_Combat05", "C05", {
        eligibility = lateCombatEligibility("f_combat05_early"),
    }),

    combatRoom("F_Combat06", "C06"),
    combatRoom("F_Combat07", "C07"),
    combatRoom("F_Combat08", "C08", {
        eligibility = earlyCombatEligibility("f_combat08_late"),
    }),

    combatRoom("F_Combat09", "C09", {
        exitCount = 1,
        eligibility = earlyCombatEligibility("f_combat09_late", 4),
    }),

    combatRoom("F_Combat10", "C10", {
        exitCount = 1,
        eligibility = earlyCombatEligibility("f_combat10_late"),
    }),

    combatRoom("F_Combat11", "C11", {
        eligibility = lateCombatEligibility("f_combat11_early"),
    }),

    combatRoom("F_Combat12", "C12", {
        eligibility = lateCombatEligibility("f_combat12_early"),
    }),

    combatRoom("F_Combat13", "C13"),

    combatRoom("F_Combat14", "C14", {
        eligibility = lateCombatEligibility("f_combat14_early"),
    }),

    combatRoom("F_Combat15", "C15", {
        eligibility = lateCombatEligibility("f_combat15_early"),
    }),

    combatRoom("F_Combat16", "C16", {
        eligibility = lateCombatEligibility("f_combat16_early"),
    }),

    combatRoom("F_Combat17", "C17", {
        eligibility = lateCombatEligibility("f_combat17_early"),
    }),

    combatRoom("F_Combat18", "C18", {
        eligibility = lateCombatEligibility("f_combat18_early"),
    }),

    combatRoom("F_Combat19", "C19", {
        eligibility = earlyCombatEligibility("f_combat19_late"),
    }),

    combatRoom("F_Combat20", "C20", {
        eligibility = lateCombatEligibility("f_combat20_early"),
    }),

    combatRoom("F_Combat21", "C21", {
        eligibility = earlyCombatEligibility("f_combat21_late"),
    }),

    combatRoom("F_Combat22", "C22", {
        eligibility = earlyCombatEligibility("f_combat22_late"),
    }),

    room("F_Reprieve01", "Fountain", {
        kind = "Reprieve",
        roomTemplate = "Fountain",
        tags = { "Reprieve", "Fountain" },
        exitCount = 2,
        encounterProfile = "None",
        counters = counters(1, 1, 0),
    }),

    room("F_Story01", "Arachne", {
        kind = "Story",
        roomTemplate = "Story",
        tags = { "Story", "Arachne" },
        exitCount = 2,
        eligibility = depthWindowEligibility("f_story_arachne", 4, 8),
        caps = {
            maxCreationsThisRun = 1,
        },
        encounterProfile = "Story_Arachne_01",
        counters = counters(1, 1, 0),
    }),

    room("F_Shop01", "Shop", {
        kind = "Shop",
        roomTemplate = "Shop",
        tags = { "Shop" },
        exitCount = 2,
        eligibility = depthWindowEligibility("f_shop", 4, 6),
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
        counters = counters(1, 1, 0),
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
        counters = counters(1, 0, 0),
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
