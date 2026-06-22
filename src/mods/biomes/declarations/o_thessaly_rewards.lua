return function(_, deps)
    local rewards = deps.rewards

    return {
        wheelChoice = rewards.groupedMajorMinor({
            sourceCount = 2,
            sharedRewardClass = true,
            rewardGeneration = {
                effectTiming = "afterBatch",
            },
        }),
    }
end
