return function(deps)
    local layout = deps.layout

    local function rewardSibling(key, label)
        return {
            key = key,
            label = label,
            structure = "Combat",
            roleKey = "Combat",
            rewardBranch = "majorMinor",
            sameExitRewardCount = 1,
        }
    end

    local function roomSibling(room, structure, opts)
        opts = opts or {}
        return {
            key = opts.key or room.key,
            label = opts.label or room.label,
            structure = structure,
            roleKey = opts.roleKey,
            roomKey = room.key,
            availability = room.availability,
            force = room.force,
            rewardStore = opts.rewardStore,
            rewardClass = opts.rewardClass,
            rewardBranch = opts.rewardBranch,
            eligibleRewardTypes = opts.eligibleRewardTypes,
            sameExitRewardCount = opts.sameExitRewardCount or 0,
        }
    end

    local function roomKeys(rooms)
        local keys = {}
        for _, room in ipairs(rooms) do
            keys[#keys + 1] = room.key
        end
        return keys
    end

    local options = {
        {
            key = "",
            label = "Select Door",
        },
        rewardSibling("Combat", "Combat"),
        roomSibling(layout.storyRooms[1], "Story", {
            roleKey = "Story",
        }),
        roomSibling(layout.shopRooms[1], "Midshop", {
            roleKey = "Midshop",
        }),
        roomSibling(layout.fountainRooms[1], "Fountain", {
            roleKey = "Fountain",
            rewardBranch = "majorMinor",
            sameExitRewardCount = 1,
        }),
    }
    for _, miniboss in ipairs(layout.minibossRooms) do
        options[#options + 1] = roomSibling(miniboss, "Miniboss", {
            roleKey = "Miniboss",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            sameExitRewardCount = 1,
        })
    end

    local generatedDoorControl = {
        key = "SiblingStructure",
        alias = "SiblingStructureKey",
        label = "Other Door",
        options = options,
    }

    return {
        topologyWindow = {
            biomeDepthCache = { min = 0, max = 10 },
        },
        forcedGroups = {
            {
                key = "F_Shop",
                label = "Midshop",
                candidates = { layout.shopRooms[1].key },
                generatedCapacityKind = "sourceExitCount",
                requiredGeneratedCount = 1,
                forceAtBiomeDepthMax = 6,
                force = layout.shopRooms[1].force,
            },
            {
                key = "F_Minibosses",
                label = "Miniboss",
                candidates = roomKeys(layout.minibossRooms),
                generatedCapacityKind = "sourceExitCount",
                forceAtBiomeDepthMax = 6,
                force = layout.minibossRooms[1].force,
                pickedCandidateBeforeDeadlineClosesGroup = true,
            },
        },
        generatedDoorControl = generatedDoorControl,
        siblingStructureControl = generatedDoorControl,
    }
end
