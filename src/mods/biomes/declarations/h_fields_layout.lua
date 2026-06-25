return function()
local layout = {}

local WELL_SHOP_FEATURES = { wellShop = true }

local function option(key, label, opts)
    opts = opts or {}
    return {
        key = key,
        label = label,
        features = opts.features,
        availability = opts.availability,
        encounter = opts.encounter,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost,
        maxCageRewards = opts.maxCageRewards,
        maxCreationsThisRun = opts.maxCreationsThisRun,
        maxAppearancesThisBiome = opts.maxAppearancesThisBiome,
    }
end

local function combat(roomKey, maxCageRewards, opts)
    opts = opts or {}
    opts.maxCageRewards = maxCageRewards
    opts.features = opts.features or WELL_SHOP_FEATURES
    opts.biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1
    opts.maxCreationsThisRun = opts.maxCreationsThisRun or 1
    return option(roomKey, "C" .. string.sub(roomKey, -2) .. " (" .. tostring(maxCageRewards) .. " Slots)", opts)
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

local earlyCombatAvailability = {
    biomeDepthCache = { max = 3 },
}
local bridgeAvailability = {
    biomeDepthCache = { exact = 3 },
}
local minibossAvailability = {
    biomeDepthCache = { min = 2, max = 4 },
}

layout.wellShopFeatures = WELL_SHOP_FEATURES

layout.introRoom = option("H_Intro", "Intro", {
    availability = {
        biomeDepthCache = { min = 0, max = 1 },
    },
})

layout.prebossRoom = option("H_PreBoss01", "Preboss Shop", {
    availability = {
        routeRoomsEntered = { min = 4 },
    },
})

layout.bridgeRoom = option("H_Bridge01", "Echo", {
    availability = bridgeAvailability,
    maxCreationsThisRun = 1,
    maxAppearancesThisBiome = 1,
})

layout.cageRewardPolicy = {
    key = "H_FieldsCageRewards",
    label = "Fields Cage Rewards",
    rewardStore = "RunProgress",
    countControl = {
        key = "CageRewardCount",
        label = "Reward Count",
        min = 2,
        max = 3,
        options = {
            {
                key = "TwoRewards",
                label = "2 Rewards",
                cageRewardCount = 2,
            },
            {
                key = "ThreeRewards",
                label = "3 Rewards",
                cageRewardCount = 3,
                requiresAllOfferedRoomsSupport = 3,
            },
        },
    },
    maxDoorDepthChanceTable = {
        [1] = { maxDoorChance = 0.05 },
        [2] = { maxDoorChance = 0.20 },
        [3] = { maxDoorChance = 0.40 },
        [4] = { maxDoorChance = 0.80, ceilingCheck = true },
        [5] = { maxDoorChance = 0.10, ceilingCheck = true },
    },
    maxDoorCageCeiling = 2,
    locationModel = "VanillaRandomLootPoint",
}

layout.offerTopology = {
    rules = {
        {
            key = "matchingCombatCageRewardCount",
        },
    },
    forcedGroups = {
        {
            key = "H_Minibosses",
            candidates = { "H_MiniBoss01", "H_MiniBoss02" },
            forceAtBiomeDepthMax = 4,
            pickedCandidateBeforeDeadlineClosesGroup = true,
        },
    },
    siblingStructureControl = {
        key = "SiblingStructure",
        alias = "SiblingStructureKey",
        label = "Sibling Door",
        options = {
            {
                key = "",
                label = "Select Sibling",
            },
            {
                key = "CombatCage2",
                label = "Combat 2",
                structure = "CombatCage2",
                rewardStore = "RunProgress",
                offerCount = 2,
            },
            {
                key = "CombatCage3",
                label = "Combat 3",
                structure = "CombatCage3",
                rewardStore = "RunProgress",
                offerCount = 3,
            },
            {
                key = "H_MiniBoss01",
                label = "Vampire",
                structure = "Miniboss",
                roomKey = "H_MiniBoss01",
                availability = minibossAvailability,
                rewardStore = "RunProgress",
                eligibleRewardTypes = { "Boon" },
                offerCount = 1,
            },
            {
                key = "H_MiniBoss02",
                label = "Lamia",
                structure = "Miniboss",
                roomKey = "H_MiniBoss02",
                availability = minibossAvailability,
                rewardStore = "RunProgress",
                eligibleRewardTypes = { "Boon" },
                offerCount = 1,
            },
            {
                key = "Bridge",
                label = "Echo",
                structure = "Bridge",
                roomKey = "H_Bridge01",
                availability = bridgeAvailability,
                offerCount = 0,
            },
        },
    },
}

layout.combatRooms = {
    combat("H_Combat01", 5),
    combat("H_Combat02", 3, { availability = earlyCombatAvailability }),
    combat("H_Combat03", 3),
    combat("H_Combat04", 4),
    combat("H_Combat05", 5),
    combat("H_Combat06", 5),
    combat("H_Combat07", 3),
    combat("H_Combat08", 3),
    combat("H_Combat09", 2, { availability = earlyCombatAvailability }),
    combat("H_Combat10", 5),
    combat("H_Combat11", 5),
    combat("H_Combat12", 3),
    combat("H_Combat13", 2, { availability = earlyCombatAvailability }),
    combat("H_Combat14", 2, { availability = earlyCombatAvailability }),
    combat("H_Combat15", 3, { availability = earlyCombatAvailability }),
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

layout.minibossRooms = {
    option("H_MiniBoss01", "Vampire", {
        encounter = "MiniBossVampire",
        biomeEncounterDepthCost = 1,
        availability = minibossAvailability,
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
    option("H_MiniBoss02", "Lamia", {
        encounter = "MiniBossLamia",
        biomeEncounterDepthCost = 1,
        availability = minibossAvailability,
        maxCreationsThisRun = 1,
        maxAppearancesThisBiome = 1,
    }),
}

layout.minibossRoomsByKey = indexByKey(layout.minibossRooms)

return layout
end
