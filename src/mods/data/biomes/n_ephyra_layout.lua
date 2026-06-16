return function(importer)
local rewards = importer("mods/data/rewards.lua")(importer)
local layout = {}

local HARD_SUBROOMS = {
    N_Sub09 = true,
    N_Sub10 = true,
    N_Sub11 = true,
    N_Sub14 = true,
}

local function combatLabel(roomKey)
    return "Combat " .. string.sub(roomKey, -2)
end

local function subroomRewardStore(roomKey)
    if HARD_SUBROOMS[roomKey] then
        return "SubRoomRewardsHard"
    end
    return "SubRoomRewards"
end

local function sideDoor(doorId, roomKey)
    return {
        doorId = doorId,
        roomKey = roomKey,
        reward = rewards.roomStore(subroomRewardStore(roomKey)),
    }
end

local function combatRoom(roomKey, hubDoorId, sideDoors)
    return {
        key = roomKey,
        label = combatLabel(roomKey),
        hubDoorId = hubDoorId,
        sideDoors = sideDoors or {},
    }
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[item.key] = item
    end
    return lookup
end

local function buildHubDoorRooms()
    local rooms = {}

    for _, room in ipairs(layout.combatRooms) do
        rooms[#rooms + 1] = {
            kind = "Combat",
            roomKey = room.key,
            doorId = room.hubDoorId,
        }
    end

    for _, room in ipairs(layout.minibossRooms) do
        rooms[#rooms + 1] = {
            kind = "Miniboss",
            roomKey = room.key,
            doorId = room.hubDoorId,
        }
    end

    for _, room in ipairs(layout.storyRooms) do
        rooms[#rooms + 1] = {
            kind = "Story",
            roomKey = room.key,
            doorId = room.hubDoorId,
        }
    end

    return rooms
end

layout.combatRooms = {
    combatRoom("N_Combat01", 617113),
    combatRoom("N_Combat02", 560725, {
        sideDoor(558353, "N_Sub01"),
        sideDoor(558352, "N_Sub03"),
    }),
    combatRoom("N_Combat03", 560702, {
        sideDoor(558353, "N_Sub04"),
    }),
    combatRoom("N_Combat04", 560707, {
        sideDoor(558834, "N_Sub02"),
        sideDoor(558410, "N_Sub06"),
    }),
    combatRoom("N_Combat05", 561337, {
        sideDoor(558354, "N_Sub02"),
        sideDoor(558378, "N_Sub07"),
        sideDoor(558379, "N_Sub03"),
    }),
    combatRoom("N_Combat06", 560708, {
        sideDoor(558378, "N_Sub10"),
        sideDoor(560794, "N_Sub05"),
    }),
    combatRoom("N_Combat07", 617138),
    combatRoom("N_Combat08", 560699),
    combatRoom("N_Combat09", 617012, {
        sideDoor(566392, "N_Sub11"),
        sideDoor(566536, "N_Sub08"),
        sideDoor(566394, "N_Sub14"),
    }),
    combatRoom("N_Combat10", 617151, {
        sideDoor(558352, "N_Sub05"),
        sideDoor(567015, "N_Sub09"),
    }),
    combatRoom("N_Combat11", 561449, {
        sideDoor(558352, "N_Sub01"),
    }),
    combatRoom("N_Combat12", 561389, {
        sideDoor(558352, "N_Sub09"),
        sideDoor(566544, "N_Sub10"),
        sideDoor(566545, "N_Sub07"),
    }),
    combatRoom("N_Combat13", 616992),
    combatRoom("N_Combat14", 561403),
    combatRoom("N_Combat15", 560705, {
        sideDoor(657623, "N_Sub03"),
    }),
    combatRoom("N_Combat16", 561354, {
        sideDoor(558352, "N_Sub04"),
    }),
    combatRoom("N_Combat17", 561424, {
        sideDoor(558352, "N_Sub11"),
    }),
    combatRoom("N_Combat18", 561374, {
        sideDoor(658853, "N_Sub12"),
    }),
    combatRoom("N_Combat19", 560620),
    combatRoom("N_Combat20", 561418, {
        sideDoor(659508, "N_Sub06"),
    }),
    combatRoom("N_Combat21", 560713),
    combatRoom("N_Combat22", 560776, {
        sideDoor(558352, "N_Sub14"),
        sideDoor(661338, "N_Sub02"),
    }),
    combatRoom("N_Combat23", 561368, {
        sideDoor(755971, "N_Sub12"),
        sideDoor(755184, "N_Sub13"),
        sideDoor(755185, "N_Sub15"),
    }),
}

layout.minibossRooms = {
    {
        key = "N_MiniBoss01",
        label = "Satyr Crossbow",
        hubDoorId = 617043,
        encounter = "MiniBossSatyrCrossbow",
    },
    {
        key = "N_MiniBoss02",
        label = "Boar",
        hubDoorId = 560889,
        encounter = "MiniBossBoar",
    },
}

layout.storyRooms = {
    {
        key = "N_Story01",
        label = "Medea",
        hubDoorId = 560848,
    },
}

layout.subroomRewardStores = {
    N_Sub01 = "SubRoomRewards",
    N_Sub02 = "SubRoomRewards",
    N_Sub03 = "SubRoomRewards",
    N_Sub04 = "SubRoomRewards",
    N_Sub05 = "SubRoomRewards",
    N_Sub06 = "SubRoomRewards",
    N_Sub07 = "SubRoomRewards",
    N_Sub08 = "SubRoomRewards",
    N_Sub09 = "SubRoomRewardsHard",
    N_Sub10 = "SubRoomRewardsHard",
    N_Sub11 = "SubRoomRewardsHard",
    N_Sub12 = "SubRoomRewards",
    N_Sub13 = "SubRoomRewards",
    N_Sub14 = "SubRoomRewardsHard",
    N_Sub15 = "SubRoomRewards",
}

layout.combatRoomsByKey = indexByKey(layout.combatRooms)
layout.minibossRoomsByKey = indexByKey(layout.minibossRooms)
layout.storyRoomsByKey = indexByKey(layout.storyRooms)
layout.hubDoorRooms = buildHubDoorRooms()

return layout
end
