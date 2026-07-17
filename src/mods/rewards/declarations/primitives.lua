return {
    AphroditeUpgrade = {
        label = "Aphrodite",
    },
    ApolloUpgrade = {
        label = "Apollo",
    },
    AresUpgrade = {
        label = "Ares",
    },
    DemeterUpgrade = {
        label = "Demeter",
    },
    HephaestusUpgrade = {
        label = "Hephaestus",
    },
    HeraUpgrade = {
        label = "Hera",
    },
    HermesUpgrade = {
        label = "Hermes",
    },
    HestiaUpgrade = {
        label = "Hestia",
    },
    PoseidonUpgrade = {
        label = "Poseidon",
    },
    ZeusUpgrade = {
        label = "Zeus",
    },

    Boon = {
        label = "Boon",
        payloadDomain = "BoonSource",
        defaultPayload = { source = "ApolloUpgrade" },
    },
    Devotion = {
        label = "Trial",
        payloadDomain = "DevotionPair",
        defaultPayload = { sources = { "ApolloUpgrade", "ZeusUpgrade" } },
    },
    Story = {
        label = "Story",
    },
    ClockworkGoal = {
        label = "Clockwork Goal",
    },
    RandomLoot = {
        label = "Boon",
        acquiredAs = "Boon",
        payloadDomain = "BoonSource",
        defaultPayload = { source = "ApolloUpgrade" },
    },
    BoostedRandomLoot = {
        label = "Boosted Boon",
        acquiredAs = "Boon",
        payloadDomain = "BoonSource",
        defaultPayload = { source = "ApolloUpgrade" },
    },
    BlindBoxLoot = {
        label = "Mystery Boon",
        acquiredAs = "Boon",
        payloadDomain = "BoonSource",
        defaultPayload = { source = "ApolloUpgrade" },
    },
    ShopHermesUpgrade = {
        label = "Hermes Boon",
        acquiredAs = "HermesUpgrade",
    },

    WeaponUpgrade = {
        label = "Hammer",
    },
    WeaponUpgradeDrop = {
        label = "Hammer",
        acquiredAs = "WeaponUpgrade",
    },
    ChaosWeaponUpgrade = {
        label = "Anvil",
        acquiredAs = "WeaponUpgrade",
    },
    MaxHealthDrop = {
        label = "Max Health",
    },
    MaxHealthDropSmall = {
        label = "Tiny Max Health",
        acquiredAs = "MaxHealthDrop",
    },
    MaxHealthDropBig = {
        label = "Big Max Health",
        acquiredAs = "MaxHealthDrop",
    },
    EmptyMaxHealthSmallDrop = {
        label = "Empty Max Health",
        acquiredAs = "MaxHealthDrop",
    },
    MaxManaDrop = {
        label = "Max Magick",
    },
    MaxManaDropSmall = {
        label = "Tiny Max Magick",
        acquiredAs = "MaxManaDrop",
    },
    MaxManaDropBig = {
        label = "Big Max Magick",
        acquiredAs = "MaxManaDrop",
    },
    StackUpgrade = {
        label = "Pom of Power",
    },
    StackUpgradeBig = {
        label = "Double Pom",
        acquiredAs = "StackUpgrade",
    },
    StackUpgradeTriple = {
        label = "Triple Pom",
        acquiredAs = "StackUpgrade",
    },
    StoreRewardRandomStack = {
        label = "Pom Slice",
        acquiredAs = "StackUpgrade",
    },
    RoomMoneyDrop = {
        label = "Gold",
    },
    RoomMoneyTinyDrop = {
        label = "Tiny Gold",
        acquiredAs = "RoomMoneyDrop",
    },
    RoomMoneyTripleDrop = {
        label = "Triple Gold",
        acquiredAs = "RoomMoneyDrop",
    },
    TalentDrop = {
        label = "Path of Stars",
    },
    MinorTalentDrop = {
        label = "Tiny Path",
        acquiredAs = "TalentDrop",
    },
    TalentBigDrop = {
        label = "Big Path",
        acquiredAs = "TalentDrop",
    },
    SpellDrop = {
        label = "Selene's Gift",
    },
    GiftDrop = {
        label = "Nectar",
    },
    MetaCurrencyDrop = {
        label = "Bones",
    },
    MetaCurrencyBigDrop = {
        label = "Big Bones",
        acquiredAs = "MetaCurrencyDrop",
    },
    MetaCardPointsCommonDrop = {
        label = "Ashes",
    },
    MetaCardPointsCommonBigDrop = {
        label = "Big Ashes",
        acquiredAs = "MetaCardPointsCommonDrop",
    },
    RoomRewardHealDrop = {
        label = "Heal",
    },
    HealBigDrop = {
        label = "Big Heal",
        acquiredAs = "RoomRewardHealDrop",
    },
    ArmorBoost = {
        label = "Armor",
    },
    ArmorBigBoost = {
        label = "Big Armor",
        acquiredAs = "ArmorBoost",
    },
    LastStandDrop = {
        label = "Kiss of Styx",
    },
    WeaponPointsRareDrop = {
        label = "Nightmare",
    },
    CardUpgradePointsDrop = {
        label = "Moon Dust",
    },
    CharonPointsDrop = {
        label = "Obol Points",
    },
    AirBoost = {
        label = "Air",
    },
    EarthBoost = {
        label = "Earth",
    },
    FireBoost = {
        label = "Fire",
    },
    WaterBoost = {
        label = "Water",
    },
    ElementalBoost = {
        label = "Element",
    },
}
