return function(deps)
local rewards = deps.rewards
local layout = {}

local SURFACE_SHOP_FEATURES = { surfaceShop = true }
local SURFACE_SHOP_COMBAT_ROOMS = {
    O_Combat02 = true,
    O_Combat03 = true,
    O_Combat04 = true,
    O_Combat05 = true,
    O_Combat06 = true,
    O_Combat07 = true,
    O_Combat08 = true,
    O_Combat09 = true,
    O_Combat10 = true,
    O_Combat11 = true,
    O_Combat12 = true,
    O_Combat13 = true,
    O_Combat14 = true,
    O_Combat15 = true,
}

local function option(key, label, opts)
    opts = opts or {}
    return {
        key = key,
        label = label,
        features = opts.features,
        availability = opts.availability,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost,
        maxCreationsThisRun = opts.maxCreationsThisRun,
        maxAppearancesThisBiome = opts.maxAppearancesThisBiome,
    }
end

local function combat(roomKey, opts)
    opts = opts or {}
    opts.features = opts.features or (SURFACE_SHOP_COMBAT_ROOMS[roomKey] and SURFACE_SHOP_FEATURES or nil)
    opts.biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1
    opts.maxCreationsThisRun = opts.maxCreationsThisRun or 1
    return option(roomKey, "C" .. string.sub(roomKey, -2), opts)
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

layout.surfaceShopFeatures = SURFACE_SHOP_FEATURES

layout.introRoom = option("O_Intro", "Intro", {
    availability = { biomeDepthCache = { exact = 1 } },
})

layout.prebossRoom = option("O_PreBoss01", "Preboss", {
    availability = { biomeDepthCache = { exact = 7 } },
})

layout.combatEncounterPolicy = {
    key = "O_CombatData",
    label = "Ship Combat",
    wheelOfferControl = {
        key = "WheelOfferCount",
        label = "Wheel Choices",
        aliasPrefix = "WheelOffer",
        options = {
            {
                key = "",
                label = "Select Wheel",
            },
            {
                key = "OneChoice",
                label = "1 Choice",
                wheelOfferCount = 1,
            },
            {
                key = "TwoChoices",
                label = "2 Choices",
                wheelOfferCount = 2,
            },
        },
    },
    countControl = {
        key = "CombatCount",
        label = "Combat Count",
        default = "Vanilla",
        options = {
            {
                key = "Vanilla",
                label = "Vanilla",
                biomeEncounterDepthCost = { min = 1, max = 2 },
            },
            {
                key = "TwoCombats",
                label = "2 Combats",
                realCombatCount = 2,
                biomeEncounterDepthCost = 1,
            },
            {
                key = "ThreeCombats",
                label = "3 Combats",
                realCombatCount = 3,
                biomeEncounterDepthCost = 2,
                availableAtBiomeEncounterDepth = { min = 2, max = 5 },
            },
        },
    },
    legs = {
        {
            key = "Intro",
            label = "Intro",
            reward = rewards.none(),
            hasReward = false,
            countsForRoomEncounterDepth = false,
        },
        {
            key = "Encounter1",
            label = "First Encounter",
            reward = rewards.majorMinor(),
            hasReward = true,
            required = true,
        },
        {
            key = "Encounter2",
            label = "Second Encounter",
            reward = rewards.majorMinor(),
            hasReward = true,
            required = false,
            vanillaChance = 0.6,
            availableAtBiomeEncounterDepth = { min = 2, max = 5 },
        },
    },
}

layout.combatRooms = {
    combat("O_Combat01"),
    combat("O_Combat02"),
    combat("O_Combat03"),
    combat("O_Combat04", { availability = { biomeDepthCache = { max = 3 } } }),
    combat("O_Combat05"),
    combat("O_Combat06"),
    combat("O_Combat07", { availability = { biomeDepthCache = { max = 3 } } }),
    combat("O_Combat08"),
    combat("O_Combat09"),
    combat("O_Combat10"),
    combat("O_Combat11", { availability = { biomeDepthCache = { max = 3 } } }),
    combat("O_Combat12"),
    combat("O_Combat13", { availability = { biomeDepthCache = { min = 6 } } }),
    combat("O_Combat14"),
    combat("O_Combat15", { availability = { biomeDepthCache = { max = 3 } } }),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.storyRooms = {
    option("O_Story01", "Circe", {
        availability = {
            biomeEncounterDepth = { minExclusive = 3 },
            biomeDepthCache = { max = 5 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.fountainRooms = {
    option("O_Reprieve01", "Fountain", {
        features = SURFACE_SHOP_FEATURES,
        availability = {
            biomeDepthCache = { min = 3, max = 5 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.shopRooms = {
    option("O_Shop01", "Shop", {
        availability = {
            biomeEncounterDepth = { minExclusive = 3 },
            biomeDepthCache = { max = 5 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.devotionRooms = {
    option("O_Devotion01", "Trial", {
        biomeEncounterDepthCost = 1,
        features = SURFACE_SHOP_FEATURES,
        availability = {
            biomeEncounterDepth = { min = 2 },
        },
        maxCreationsThisRun = 1,
    }),
}

layout.minibossRooms = {
    option("O_MiniBoss01", "Charybdis", {
        biomeEncounterDepthCost = 0,
        availability = {
            biomeDepthCache = { min = 3, max = 5 },
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("O_MiniBoss02", "Captain", {
        features = SURFACE_SHOP_FEATURES,
        biomeEncounterDepthCost = 1,
        availability = {
            biomeDepthCache = { min = 3, max = 5 },
        },
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
}

return layout
end
