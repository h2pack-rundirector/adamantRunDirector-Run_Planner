return function(deps)
    local layout = deps.layout

    local function rewardSibling(key, label, rewardStore, rewardClass)
        return {
            key = key,
            label = label,
            structure = "Combat",
            roleKey = "Combat",
            rewardStore = rewardStore,
            rewardClass = rewardClass,
            offerCount = 1,
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
            eligibleRewardTypes = opts.eligibleRewardTypes,
            offerCount = opts.offerCount or 0,
        }
    end

    local function majorMinorRoomSiblings(room, structure, roleKey)
        return {
            roomSibling(room, structure, {
                key = room.key .. "_Major",
                label = room.label .. " Major",
                roleKey = roleKey,
                rewardStore = "RunProgress",
                rewardClass = "Major",
                offerCount = 1,
            }),
            roomSibling(room, structure, {
                key = room.key .. "_Minor",
                label = room.label .. " Minor",
                roleKey = roleKey,
                rewardStore = "MetaProgress",
                rewardClass = "Minor",
                offerCount = 1,
            }),
        }
    end

    local function append(target, values)
        for _, value in ipairs(values) do
            target[#target + 1] = value
        end
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
            label = "Select Sibling",
        },
        rewardSibling("CombatMajor", "Combat Major", "RunProgress", "Major"),
        rewardSibling("CombatMinor", "Combat Minor", "MetaProgress", "Minor"),
        roomSibling(layout.storyRooms[1], "Story", {
            roleKey = "Story",
        }),
        roomSibling(layout.shopRooms[1], "Midshop", {
            roleKey = "Midshop",
        }),
    }
    append(options, majorMinorRoomSiblings(layout.fountainRooms[1], "Fountain", "Fountain"))
    for _, miniboss in ipairs(layout.minibossRooms) do
        options[#options + 1] = roomSibling(miniboss, "Miniboss", {
            roleKey = "Miniboss",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
        })
    end

    return {
        siblingStructureWindow = {
            biomeDepthCache = { min = 3, max = 7 },
        },
        rules = {
            {
                key = "matchingSiblingRewardStore",
                onlyWhenBothHaveRewardStore = true,
            },
        },
        forcedGroups = {
            {
                key = "G_Shop",
                candidates = { layout.shopRooms[1].key },
                generatedExitCountField = "rewardExitCount",
                requiredGeneratedCount = 1,
                forceAtBiomeDepthMax = 6,
                force = layout.shopRooms[1].force,
            },
            {
                key = "G_Minibosses",
                candidates = roomKeys(layout.minibossRooms),
                generatedExitCountField = "rewardExitCount",
                forceAtBiomeDepthMax = 7,
                force = layout.minibossRooms[1].force,
                pickedCandidateBeforeDeadlineClosesGroup = true,
            },
        },
        siblingStructureControl = {
            key = "SiblingStructure",
            alias = "SiblingStructureKey",
            label = "Sibling Door",
            options = options,
        },
    }
end
