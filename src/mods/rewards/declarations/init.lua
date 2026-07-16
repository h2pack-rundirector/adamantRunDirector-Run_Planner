return {
    primitives = import("mods/rewards/declarations/primitives.lua"),
    payloadDomains = import("mods/rewards/declarations/payload_domains.lua"),
    bags = import("mods/rewards/declarations/bags.lua"),
    shops = import("mods/rewards/declarations/shops.lua"),
    batchConstraints = {
        NHubUniqueNonBoon = { kind = "uniqueRewardTypes", allowDuplicates = { Boon = true } },
        UniqueNonBoonRewardTypes = { kind = "uniqueRewardTypes", allowDuplicates = { Boon = true } },
        UniqueBoonSources = { kind = "uniqueBoonSources" },
        DevotionPairDistinct = { kind = "distinctPayloadValues" },
        QWorldShopPrimaryUnique = { kind = "uniqueRewardTypes", slotGroup = "Primary" },
    },
}
