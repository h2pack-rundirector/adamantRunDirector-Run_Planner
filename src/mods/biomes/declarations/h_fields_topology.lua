return function(deps)
    local rooms = deps.rooms or deps.layout

    local miniboss01 = rooms.minibossRoomsByKey.H_MiniBoss01
    local miniboss02 = rooms.minibossRoomsByKey.H_MiniBoss02
    local bridge = rooms.bridgeRoom

    return {
        siblingStructureWindow = {
            biomeDepthCache = { min = 1, max = 4 },
        },
        rules = {
            {
                key = "matchingCombatCageRewardCount",
            },
        },
        forcedGroups = {
            {
                key = "H_Minibosses",
                label = "Miniboss",
                candidates = { "H_MiniBoss01", "H_MiniBoss02" },
                generatedCapacityKind = "sourceExitCount",
                forceAtBiomeDepthMax = 4,
                force = miniboss01.force,
                pickedCandidateBeforeDeadlineClosesGroup = true,
            },
        },
        siblingStructureControl = {
            key = "SiblingStructure",
            alias = "SiblingStructureKey",
            label = "Other Door",
            options = {
                {
                    key = "",
                    label = "Select Door",
                },
                {
                    key = "CombatCage2",
                    label = "Combat 2",
                    structure = "CombatCage2",
                    rewardStore = "RunProgress",
                    sameExitRewardCount = 2,
                },
                {
                    key = "CombatCage3",
                    label = "Combat 3",
                    structure = "CombatCage3",
                    rewardStore = "RunProgress",
                    sameExitRewardCount = 3,
                },
                {
                    key = miniboss01.key,
                    label = miniboss01.label,
                    structure = "Miniboss",
                    roleKey = "Miniboss",
                    optionKey = miniboss01.key,
                    roomKey = miniboss01.key,
                    availability = miniboss01.availability,
                    force = miniboss01.force,
                    rewardStore = "RunProgress",
                    eligibleRewardTypes = { "Boon" },
                    sameExitRewardCount = 1,
                },
                {
                    key = miniboss02.key,
                    label = miniboss02.label,
                    structure = "Miniboss",
                    roleKey = "Miniboss",
                    optionKey = miniboss02.key,
                    roomKey = miniboss02.key,
                    availability = miniboss02.availability,
                    force = miniboss02.force,
                    rewardStore = "RunProgress",
                    eligibleRewardTypes = { "Boon" },
                    sameExitRewardCount = 1,
                },
                {
                    key = "Bridge",
                    label = bridge.label,
                    structure = "Bridge",
                    roleKey = "Bridge",
                    optionKey = bridge.key,
                    roomKey = bridge.key,
                    availability = bridge.availability,
                    force = bridge.force,
                    sameExitRewardCount = 0,
                },
            },
        },
    }
end
