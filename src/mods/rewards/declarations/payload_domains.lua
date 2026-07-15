return {
    BoonSource = {
        kind = "oneOf",
        values = {
            "AphroditeUpgrade", "ApolloUpgrade", "AresUpgrade", "DemeterUpgrade",
            "HephaestusUpgrade", "HeraUpgrade", "HestiaUpgrade", "PoseidonUpgrade", "ZeusUpgrade",
        },
    },
    DevotionPair = {
        kind = "distinctPair",
        valueDomain = "BoonSource",
    },
}
