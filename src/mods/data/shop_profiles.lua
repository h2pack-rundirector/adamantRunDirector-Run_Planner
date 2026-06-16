local profiles = {}

local function slot(key, label, storeGroup, offerIndex)
    return {
        key = key,
        label = label,
        storeGroup = storeGroup,
        offerIndex = offerIndex,
    }
end

profiles.WorldShop = {
    key = "WorldShop",
    storeDataName = "WorldShop",
    optionSlots = {
        slot("Boon", "Boon", 1, 1),
        slot("MajorNonBoon", "Major Non-Boon", 2, 1),
        slot("Minor", "Minor", 3, 1),
    },
}

profiles.I_WorldShop = {
    key = "I_WorldShop",
    storeDataName = "I_WorldShop",
    optionSlots = {
        slot("Group1Offer1", "Priority Power", 1, 1),
        slot("Group2Offer1", "Mixed Reward", 2, 1),
        slot("Group3Offer1", "Survival", 3, 1),
        slot("Group4Offer1", "Major Power", 4, 1),
        slot("Group5Offer1", "Resource", 5, 1),
    },
}

profiles.Q_WorldShop = {
    key = "Q_WorldShop",
    storeDataName = "Q_WorldShop",
    optionSlots = {
        slot("Group1Offer1", "Primary Power A", 1, 1),
        slot("Group1Offer2", "Primary Power B", 1, 2),
        slot("Group2Offer1", "Secondary Reward", 2, 1),
        slot("Group3Offer1", "Survival", 3, 1),
        slot("Group4Offer1", "Major Power", 4, 1),
        slot("Group5Offer1", "Resource", 5, 1),
    },
}

return profiles
