return {
    None = { kind = "none" },
    FixedStory = { kind = "fixed", rewardType = "Story" },
    RunProgressMinorMajor = { kind = "storeChoice", storeKeys = { "RunProgress", "MetaProgress" } },
    RunProgressNoDevotion = {
        kind = "storeChoice",
        storeKeys = { "RunProgress" },
        ineligibleRewardTypes = { "Devotion" },
    },
    RunProgressBoonOnly = {
        kind = "storeChoice",
        storeKeys = { "RunProgress" },
        eligibleRewardTypes = { "Boon" },
    },
    OpeningReward = {
        kind = "storeChoice",
        storeKeys = { "RunProgress" },
        ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop", "MaxHealthDrop", "MaxManaDrop" },
    },
    WorldShop = { kind = "shop", shopProfileKey = "WorldShop" },
    TartarusShop = { kind = "shop", shopProfileKey = "I_WorldShop" },
    SummitShop = { kind = "shop", shopProfileKey = "Q_WorldShop" },
    PrebossFreeReward = {
        kind = "storeChoice",
        storeKeys = { "RunProgress" },
        ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
    },
    FieldsCages = {
        kind = "localSlots",
        storeKeys = { "RunProgress" },
        maxSlots = 3,
        constraints = { "UniqueNonBoonRewardTypes", "UniqueBoonSources" },
    },
    ClockworkGoalOrTartarus = {
        kind = "incomingKind",
        kinds = {
            { key = "Goal", rewardType = "ClockworkGoal" },
            { key = "NonGoal", storeKeys = { "TartarusRewards" } },
        },
    },
    TartarusNoDevotion = {
        kind = "storeChoice",
        storeKeys = { "TartarusRewards" },
        ineligibleRewardTypes = { "Devotion" },
    },
    HubReward = { kind = "storeChoice", storeKeys = { "HubRewards" }, batchConstraint = "NHubUniqueNonBoon" },
    HubRewardNoHammerHermes = {
        kind = "storeChoice",
        storeKeys = { "HubRewards" },
        ineligibleRewardTypes = { "WeaponUpgrade", "HermesUpgrade" },
        batchConstraint = "NHubUniqueNonBoon",
    },
    SubRoomReward = { kind = "storeChoice", storeKeys = { "SubRoomRewards" } },
    SubRoomHardReward = { kind = "storeChoice", storeKeys = { "SubRoomRewardsHard" } },
    ShipWheel = { kind = "storeChoice", storeKeys = { "RunProgress", "MetaProgress" } },
    ForcedDevotion = {
        kind = "fixed",
        rewardType = "Devotion",
        constraints = { "DevotionPairDistinct" },
    },
    TyphonBossReward = { kind = "storeChoice", storeKeys = { "TyphonBossRewards" } },
}
