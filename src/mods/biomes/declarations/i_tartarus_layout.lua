return function(deps)
local rewards = deps.rewards
local layout = {}

local WELL_SHOP_FEATURES = { wellShop = true }

local function combatLabel(roomKey, exitCount)
    local exitLabel = exitCount == 1 and "1 Exit" or tostring(exitCount) .. " Exits"
    return "C" .. string.sub(roomKey, -2) .. " (" .. exitLabel .. ")"
end

local function combatRoom(roomKey, exitCount, opts)
    opts = opts or {}
    return {
        key = roomKey,
        label = combatLabel(roomKey, exitCount),
        exitCount = exitCount,
        supportsExtensionChoice = exitCount > 1,
        features = opts.features or WELL_SHOP_FEATURES,
        reward = opts.reward,
        availability = opts.availability,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost or 1,
        maxCreationsThisRun = opts.maxCreationsThisRun or 1,
    }
end

local function roomOption(roomKey, label, opts)
    opts = opts or {}
    return {
        key = roomKey,
        label = label,
        reward = opts.reward,
        features = opts.features,
        availability = opts.availability,
        biomeEncounterDepthCost = opts.biomeEncounterDepthCost,
        exitCount = opts.exitCount,
        supportsExtensionChoice = opts.exitCount ~= nil and opts.exitCount > 1,
    }
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

layout.wellShopFeatures = WELL_SHOP_FEATURES

layout.combatRooms = {
    combatRoom("I_Combat01", 2),
    combatRoom("I_Combat02", 1),
    combatRoom("I_Combat03", 2),
    combatRoom("I_Combat04", 2),
    combatRoom("I_Combat05", 1),
    combatRoom("I_Combat06", 1),
    combatRoom("I_Combat07", 1),
    combatRoom("I_Combat08", 1),
    combatRoom("I_Combat09", 2),
    combatRoom("I_Combat10", 2),
    combatRoom("I_Combat11", 2),
    combatRoom("I_Combat12", 2),
    combatRoom("I_Combat13", 1),
    combatRoom("I_Combat14", 1),
    combatRoom("I_Combat15", 2),
    combatRoom("I_Combat16", 1),
    combatRoom("I_Combat17", 1),
    combatRoom("I_Combat18", 2),
    combatRoom("I_Combat19", 1),
    combatRoom("I_Combat20", 1),
    combatRoom("I_Combat21", 2),
    combatRoom("I_Combat22", 2),
    combatRoom("I_Combat23", 1),
    combatRoom("I_Combat24", 1, {
        availability = {
            biomeDepthCache = { max = 5 },
        },
    }),
}

layout.specialExtensionRooms = {
    fountain = {
        roomOption("I_Reprieve01", "Fountain", {
            reward = rewards.roomStore("TartarusRewards", { ineligibleRewardTypes = { "Devotion" } }),
            exitCount = 2,
            availability = {
                biomeDepthCache = { min = 4 },
            },
        }),
    },
    story = {
        roomOption("I_Story01", "Hades", {
            reward = rewards.none(),
            exitCount = 1,
            availability = {
                biomeDepthCache = { min = 2 },
            },
        }),
    },
    miniboss = {
        roomOption("I_MiniBoss01", "Satyr Ratcatcher", {
            reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
            features = WELL_SHOP_FEATURES,
            biomeEncounterDepthCost = 1,
            exitCount = 2,
            availability = {
                biomeDepthCache = { min = 3, max = 7 },
            },
        }),
        roomOption("I_MiniBoss02", "Gold Elemental", {
            reward = rewards.roomStore("RunProgress", { eligibleRewardTypes = { "Boon" } }),
            features = WELL_SHOP_FEATURES,
            biomeEncounterDepthCost = 1,
            exitCount = 2,
            availability = {
                biomeDepthCache = { min = 3, max = 7 },
            },
        }),
    },
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

return layout
end
