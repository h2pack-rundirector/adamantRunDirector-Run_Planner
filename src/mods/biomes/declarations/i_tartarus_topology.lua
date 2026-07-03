return function(deps)
    local layout = deps.layout
    local goalCombatRole = deps.goalCombatRole
    local rewardCombatRole = deps.rewardCombatRole
    local prebossRole = deps.prebossRole or "Preboss"

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
            sameExitRewardCount = opts.sameExitRewardCount or 0,
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
            sameExitRewardCount = 0,
        },
        {
            key = "CombatReward",
            label = "Reward Combat",
            structure = rewardCombatRole,
            roleKey = rewardCombatRole,
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Boon" },
            sameExitRewardCount = 1,
        },
        {
            key = prebossRole,
            label = "Preboss",
            structure = prebossRole,
            roleKey = prebossRole,
            isPreboss = true,
            sameExitRewardCount = 0,
        },
        roomSibling(story, "Story", {
            roleKey = "Story",
        }),
        roomSibling(fountain, "Fountain", {
            roleKey = "Fountain",
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Devotion" },
            sameExitRewardCount = 1,
        }),
    }

    for _, miniboss in ipairs(minibosses) do
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
            biomeDepthCache = { min = 1, max = 12 },
        },
        siblingControlWindow = {
            biomeDepthCache = { min = 2, max = 12 },
        },
        generatedDoorControlWindow = {
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
                label = "Story",
                candidates = { story.key },
                generatedCapacityKind = "sourceSiblingCount",
                forceAtBiomeDepthMax = 4,
                force = story.force,
            },
            {
                key = "I_Minibosses",
                label = "Miniboss",
                candidates = roomKeys(minibosses),
                generatedCapacityKind = "sourceSiblingCount",
                forceAtBiomeDepthMax = 7,
                force = minibosses[1].force,
                pickedCandidateBeforeDeadlineClosesGroup = true,
            },
        },
        generatedDoorControl = generatedDoorControl,
        siblingStructureControl = generatedDoorControl,
    }
end
