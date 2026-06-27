return function(deps)
    local layout = deps.layout

    local miniboss01 = layout.minibossRoomsByKey.H_MiniBoss01
    local miniboss02 = layout.minibossRoomsByKey.H_MiniBoss02
    local bridge = layout.bridgeRoom

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
                    key = miniboss01.key,
                    label = miniboss01.label,
                    structure = "Miniboss",
                    roomKey = miniboss01.key,
                    availability = miniboss01.availability,
                    force = miniboss01.force,
                    rewardStore = "RunProgress",
                    eligibleRewardTypes = { "Boon" },
                    offerCount = 1,
                },
                {
                    key = miniboss02.key,
                    label = miniboss02.label,
                    structure = "Miniboss",
                    roomKey = miniboss02.key,
                    availability = miniboss02.availability,
                    force = miniboss02.force,
                    rewardStore = "RunProgress",
                    eligibleRewardTypes = { "Boon" },
                    offerCount = 1,
                },
                {
                    key = "Bridge",
                    label = bridge.label,
                    structure = "Bridge",
                    roomKey = bridge.key,
                    availability = bridge.availability,
                    force = bridge.force,
                    offerCount = 0,
                },
            },
        },
    }
end
