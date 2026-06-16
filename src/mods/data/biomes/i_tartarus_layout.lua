return function(importer)
local rewards = importer("mods/data/rewards.lua")(importer)
local layout = {}

local function combatLabel(roomKey)
    return "Combat " .. string.sub(roomKey, -2)
end

local function combatRoom(roomKey, exitCount, opts)
    opts = opts or {}
    return {
        key = roomKey,
        label = combatLabel(roomKey),
        exitCount = exitCount,
        supportsExtensionChoice = exitCount > 1,
        reward = opts.reward or rewards.roomStore("TartarusRewards"),
        availability = opts.availability,
    }
end

local function roomOption(roomKey, label, opts)
    opts = opts or {}
    return {
        key = roomKey,
        label = label,
        reward = opts.reward,
        availability = opts.availability,
        countsNonGoalReward = opts.countsNonGoalReward,
        exitCount = opts.exitCount,
        supportsExtensionChoice = opts.exitCount ~= nil and opts.exitCount > 1,
        maxCreationsThisRun = opts.maxCreationsThisRun,
        requiresExistingIExit = opts.requiresExistingIExit,
    }
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

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
            biomeDepth = { max = 5 },
        },
    }),
}

layout.specialExtensionRooms = {
    fountain = {
        roomOption("I_Reprieve01", "Fountain", {
            reward = rewards.roomStore("TartarusRewards"),
            countsNonGoalReward = true,
            exitCount = 2,
            maxCreationsThisRun = 1,
            requiresExistingIExit = true,
            availability = {
                biomeDepth = { min = 4 },
            },
        }),
    },
    story = {
        roomOption("I_Story01", "Hades", {
            reward = rewards.none(),
            countsNonGoalReward = false,
            exitCount = 1,
            maxCreationsThisRun = 1,
            requiresExistingIExit = true,
            availability = {
                biomeDepth = { min = 2, max = 4 },
            },
        }),
    },
    miniboss = {
        roomOption("I_MiniBoss01", "Satyr Ratcatcher", {
            reward = rewards.roomStore("RunProgress", { allowedRewardTypes = { "Boon" } }),
            countsNonGoalReward = true,
            exitCount = 2,
            maxCreationsThisRun = 1,
            requiresExistingIExit = true,
            availability = {
                biomeDepth = { min = 3, max = 7 },
            },
        }),
        roomOption("I_MiniBoss02", "Gold Elemental", {
            reward = rewards.roomStore("RunProgress", { allowedRewardTypes = { "Boon" } }),
            countsNonGoalReward = true,
            exitCount = 2,
            maxCreationsThisRun = 1,
            requiresExistingIExit = true,
            availability = {
                biomeDepth = { min = 3, max = 7 },
            },
        }),
    },
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)

return layout
end
