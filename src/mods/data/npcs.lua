local definitions = {}

definitions.rewardBanSets = {
    FieldNpcMajor = {
        "Boon",
        "SpellDrop",
        "Devotion",
        "HermesUpgrade",
        "WeaponUpgrade",
    },
    NemesisMajor = {
        "Boon",
        "SpellDrop",
        "Devotion",
        "HermesUpgrade",
        "WeaponUpgrade",
        "StackUpgrade",
        "TalentDrop",
    },
    ArachneMajor = {
        "Boon",
        "SpellDrop",
        "Devotion",
        "HermesUpgrade",
        "WeaponUpgrade",
        "StackUpgrade",
        "TalentDrop",
    },
    Heracles = {
        "Devotion",
    },
}

definitions.groups = {
    FieldNpc = {
        plannedSpacingRooms = 6,
        vanillaNamedRequirement = "NoRecentFieldNPCEncounter",
        encounterNames = {
            "ArtemisCombatF",
            "ArtemisCombatG",
            "ArtemisCombatN",
            "NemesisCombatF",
            "NemesisCombatG",
            "NemesisCombatH",
            "NemesisCombatI",
            "NemesisRandomEvent",
            "HeraclesCombatN",
            "HeraclesCombatO",
            "HeraclesCombatP",
            "IcarusCombatO",
            "IcarusCombatP",
            "AthenaCombatP",
        },
    },
    ArachneCombat = {
        maxSelectionsPerBiome = 1,
        plannedSpacingRooms = 5,
        vanillaNamedRequirement = "NoRecentArachneEncounter",
        encounterNames = {
            "ArachneCombatF",
            "ArachneCombatG",
        },
    },
}

definitions.ordered = {
    "Artemis",
    "Nemesis",
    "Heracles",
    "Icarus",
    "Athena",
    "Arachne",
}

definitions.byKey = {
    Artemis = {
        key = "Artemis",
        label = "Artemis",
        npcName = "NPC_Artemis_Field_01",
        routeGroup = "FieldNpc",
        maxSelectionsPerRun = 1,
        roleKeys = { "Combat" },
        rewardBanSet = "FieldNpcMajor",
        biomes = {
            F = {
                encounterLeg = "main",
                variants = {
                    { encounterName = "ArtemisCombatF", biomeDepthCache = { min = 4 } },
                },
            },
            G = {
                encounterLeg = "main",
                variants = {
                    { encounterName = "ArtemisCombatG", biomeDepthCache = { min = 4 } },
                },
            },
            N = {
                encounterLeg = "main",
                variants = {
                    { encounterName = "ArtemisCombatN", biomeDepthCache = { min = 4 } },
                },
            },
        },
    },
    Nemesis = {
        key = "Nemesis",
        label = "Nemesis",
        npcName = "NPC_Nemesis_01",
        routeGroup = "FieldNpc",
        maxSelectionsPerRun = 1,
        roleKeys = { "Combat" },
        rewardBanSet = "NemesisMajor",
        biomes = {
            F = {
                encounterLeg = "main",
                variants = {
                    {
                        key = "Combat",
                        label = "Combat",
                        encounterName = "NemesisCombatF",
                        targetKind = "combatSlot",
                        rewardBehavior = "roomReward",
                        biomeDepthCache = { min = 4 },
                    },
                    {
                        key = "Random",
                        label = "Random",
                        encounterName = "NemesisRandomEvent",
                        targetKind = "combatSlot",
                        encounterType = "NonCombat",
                        rewardBehavior = "nemesisRandomEvent",
                        biomeDepthCache = { min = 4 },
                        disallowDreamRun = true,
                    },
                },
            },
            G = {
                encounterLeg = "main",
                variants = {
                    {
                        key = "Combat",
                        label = "Combat",
                        encounterName = "NemesisCombatG",
                        targetKind = "combatSlot",
                        rewardBehavior = "roomReward",
                        biomeDepthCache = { min = 4 },
                    },
                    {
                        key = "Random",
                        label = "Random",
                        encounterName = "NemesisRandomEvent",
                        targetKind = "combatSlot",
                        encounterType = "NonCombat",
                        rewardBehavior = "nemesisRandomEvent",
                        biomeDepthCache = { min = 4 },
                        disallowDreamRun = true,
                    },
                },
            },
            H = {
                encounterLeg = "main",
                variants = {
                    {
                        key = "Combat",
                        label = "Combat",
                        encounterName = "NemesisCombatH",
                        targetKind = "combatSlot",
                        rewardBehavior = "roomReward",
                        biomeEncounterDepth = { min = 1 },
                    },
                },
            },
            I = {
                encounterLeg = "main",
                variants = {
                    {
                        key = "Combat",
                        label = "Combat",
                        encounterName = "NemesisCombatI",
                        targetKind = "combatSlot",
                        rewardBehavior = "roomReward",
                        biomeDepthCache = { min = 4 },
                    },
                },
            },
        },
    },
    Heracles = {
        key = "Heracles",
        label = "Heracles",
        npcName = "NPC_Heracles_01",
        routeGroup = "FieldNpc",
        maxSelectionsPerRun = 1,
        roleKeys = { "Combat" },
        rewardBanSet = "Heracles",
        biomes = {
            N = {
                encounterLeg = "main",
                variants = {
                    { encounterName = "HeraclesCombatN" },
                },
            },
            O = {
                encounterLeg = "intro",
                variants = {
                    { encounterName = "HeraclesCombatO" },
                },
            },
            P = {
                encounterLeg = "intro",
                requiredRoomTag = "Indoor",
                variants = {
                    { encounterName = "HeraclesCombatP" },
                },
            },
        },
    },
    Icarus = {
        key = "Icarus",
        label = "Icarus",
        npcName = "NPC_Icarus_01",
        routeGroup = "FieldNpc",
        maxSelectionsPerRun = 1,
        roleKeys = { "Combat" },
        rewardBanSet = "FieldNpcMajor",
        biomes = {
            O = {
                encounterLeg = "main",
                variants = {
                    { encounterName = "IcarusCombatO", biomeDepthCache = { min = 3 } },
                },
            },
            P = {
                encounterLeg = "main",
                requiredRoomTag = "Outdoor",
                variants = {
                    { encounterName = "IcarusCombatP", biomeDepthCache = { min = 3 } },
                },
            },
        },
    },
    Athena = {
        key = "Athena",
        label = "Athena",
        npcName = "NPC_Athena_01",
        routeGroup = "FieldNpc",
        maxSelectionsPerRun = 1,
        roleKeys = { "Combat" },
        rewardBanSet = "FieldNpcMajor",
        biomes = {
            P = {
                encounterLeg = "main",
                variants = {
                    { encounterName = "AthenaCombatP", biomeDepthCache = { min = 4 } },
                },
            },
        },
    },
    Arachne = {
        key = "Arachne",
        label = "Arachne",
        npcName = "NPC_Arachne_01",
        routeGroup = "ArachneCombat",
        roleKeys = { "Combat" },
        rewardBanSet = "ArachneMajor",
        biomes = {
            F = {
                encounterLeg = "main",
                variants = {
                    {
                        encounterName = "ArachneCombatF",
                        targetKind = "combatSlot",
                        rewardBehavior = "roomReward",
                        biomeDepthCache = { min = 4, max = 8 },
                    },
                },
            },
            G = {
                encounterLeg = "main",
                variants = {
                    {
                        encounterName = "ArachneCombatG",
                        targetKind = "combatSlot",
                        rewardBehavior = "roomReward",
                    },
                },
            },
        },
    },
}

return definitions
