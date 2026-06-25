return function(deps)
    local rewards = deps.rewards

    return {
        combatCages = rewards.fieldsCages({
            rewardStore = "RunProgress",
            ineligibleRewardTypes = { "Devotion" },
            rewardGeneration = {
                effectTiming = "afterBatch",
            },
        }),
    }
end
