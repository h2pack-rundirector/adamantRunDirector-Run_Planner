return function(deps)
    local rewards = deps.rewards

    return {
        kind = "shipCombat",
        combatEncounterPolicy = {
            key = "O_CombatData",
            label = "Ship Combat",
            wheelOfferControl = {
                key = "WheelOfferCount",
                label = "Wheel Choices",
                aliasPrefix = "WheelOffer",
                options = {
                    {
                        key = "",
                        label = "Select Wheel",
                    },
                    {
                        key = "OneChoice",
                        label = "1 Choice",
                        wheelOfferCount = 1,
                    },
                    {
                        key = "TwoChoices",
                        label = "2 Choices",
                        wheelOfferCount = 2,
                    },
                },
            },
            countControl = {
                key = "CombatCount",
                label = "Combat Count",
                options = {
                    {
                        key = "TwoCombats",
                        label = "2 Combats",
                        realCombatCount = 2,
                        biomeEncounterDepthCost = 1,
                    },
                    {
                        key = "ThreeCombats",
                        label = "3 Combats",
                        realCombatCount = 3,
                        biomeEncounterDepthCost = 2,
                        availableAtBiomeEncounterDepth = { min = 2, max = 5 },
                    },
                },
            },
            legs = {
                {
                    key = "Intro",
                    label = "Intro",
                    reward = rewards.none(),
                    hasReward = false,
                    countsForRoomEncounterDepth = false,
                },
                {
                    key = "Encounter1",
                    label = "1st Encounter",
                    reward = rewards.majorMinor(),
                    hasReward = true,
                    required = true,
                },
                {
                    key = "Encounter2",
                    label = "2nd Encounter",
                    reward = rewards.majorMinor(),
                    hasReward = true,
                    required = false,
                    vanillaChance = 0.6,
                    availableAtBiomeEncounterDepth = { min = 2, max = 5 },
                },
            },
        },
    }
end
