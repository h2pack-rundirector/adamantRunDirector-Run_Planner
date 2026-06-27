return function(deps)
    local layout = deps.layout
    local goalCombatRole = deps.goalCombatRole
    local rewardCombatRole = deps.rewardCombatRole

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
            rewardType = opts.rewardType,
            isClockworkGoal = opts.isClockworkGoal,
            eligibleRewardTypes = opts.eligibleRewardTypes,
            ineligibleRewardTypes = opts.ineligibleRewardTypes,
            offerCount = opts.offerCount or 0,
        }
    end

    local story = layout.specialExtensionRooms.story[1]
    local fountain = layout.specialExtensionRooms.fountain[1]
    local minibosses = layout.specialExtensionRooms.miniboss

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
        {
            key = "CombatGoal",
            label = "Goal Room",
            structure = goalCombatRole,
            roleKey = goalCombatRole,
            isClockworkGoal = true,
            offerCount = 0,
        },
        {
            key = "CombatReward",
            label = "Reward Combat",
            structure = rewardCombatRole,
            roleKey = rewardCombatRole,
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Boon" },
            offerCount = 1,
        },
        {
            key = "Preboss",
            label = "Preboss",
            structure = "Preboss",
            isPreboss = true,
            offerCount = 0,
        },
        roomSibling(story, "Story", {
            roleKey = "Story",
        }),
        roomSibling(fountain, "Fountain", {
            roleKey = "Fountain",
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Devotion" },
            offerCount = 1,
        }),
    }

    for _, miniboss in ipairs(minibosses) do
        options[#options + 1] = roomSibling(miniboss, "Miniboss", {
            roleKey = "Miniboss",
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
        })
    end

    return {
        topologyWindow = {
            biomeDepthCache = { min = 1, max = 12 },
        },
        siblingControlWindow = {
            biomeDepthCache = { min = 2, max = 12 },
        },
        rules = {
            {
                key = "clockworkProgressionDoor",
            },
        },
        forcedGroups = {
            {
                key = "I_Story",
                candidates = { story.key },
                generatedCapacityKind = "sourceSiblingCount",
                forceAtBiomeDepthMax = 4,
                force = story.force,
            },
            {
                key = "I_Minibosses",
                candidates = roomKeys(minibosses),
                generatedCapacityKind = "sourceSiblingCount",
                forceAtBiomeDepthMax = 7,
                force = minibosses[1].force,
                pickedCandidateBeforeDeadlineClosesGroup = true,
            },
        },
        siblingStructureControl = {
            key = "SiblingStructure",
            alias = "SiblingStructureKey",
            label = "Other Door",
            options = options,
        },
    }
end
