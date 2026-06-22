return function(_, deps)
    local rewards = deps.rewards

    return {
        prebossShop = rewards.shop("Q_WorldShop", {
            rewardGeneration = {
                effectTiming = "afterNextRow",
            },
            uniqueOfferGroups = {
                {
                    slots = { "Group1Offer1", "Group1Offer2" },
                    code = "duplicate_shop_group_option",
                    message = "Offers 1 and 2 share one vanilla shop group and cannot duplicate the same reward",
                },
            },
        }),
    }
end
