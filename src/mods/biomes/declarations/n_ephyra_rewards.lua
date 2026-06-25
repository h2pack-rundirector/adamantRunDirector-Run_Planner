return function(deps)
    local rewards = deps.rewards

    return {
        hubPylons = rewards.rewardRowGroup("N_HubPylons", {
            effectTiming = "afterGroup",
        }),
    }
end
