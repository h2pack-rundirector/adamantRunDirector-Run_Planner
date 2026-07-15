return {
    None = { kind = "fixed", phases = {} },
    F_Opening = {
        kind = "fixed",
        phases = {
            { key = "OpeningGeneratedF", kind = "combat", countsEncounterDepth = true },
        },
    },
    N_Opening = {
        kind = "fixed",
        phases = {
            { key = "OpeningGeneratedN", kind = "combat", countsEncounterDepth = true },
        },
    },
    FixedIntro = { kind = "fixed", phases = {} },
    FixedPreHub = {
        kind = "fixed",
        phases = {
            { key = "PreHubGeneratedN", kind = "combat", countsEncounterDepth = false },
        },
    },
    StandardCombat = {
        kind = "fixed",
        phases = {
            { key = "Combat", kind = "combat", countsEncounterDepth = true },
        },
    },
    FieldsCombat = {
        kind = "fixed",
        phases = {
            { key = "Combat", kind = "combat", countsEncounterDepth = true },
        },
    },
    ClockworkCombat = {
        kind = "fixed",
        phases = {
            { key = "Combat", kind = "combat", countsEncounterDepth = true },
        },
    },
    EphyraCombat = {
        kind = "fixed",
        phases = {
            { key = "Combat", kind = "combat", countsEncounterDepth = true },
        },
    },
    ShipCombat = {
        kind = "sequence",
        phases = {
            {
                key = "Intro",
                kind = "combat",
                baselineEncounterKey = "GeneratedO_Intro01",
                countsEncounterDepth = false,
            },
            {
                key = "Combat1",
                kind = "combat",
                baselineEncounterKey = "GeneratedO",
                countsEncounterDepth = true,
                offerPoint = {
                    key = "wheel1",
                    surfaceKey = "ShipWheel",
                    offerCount = { min = 1, max = 2 },
                    picked = "exactlyOne",
                    offerTiming = "encounterStart",
                    acquisitionTiming = "postCombat",
                },
            },
            {
                key = "Combat2",
                kind = "combat",
                baselineEncounterKey = "GeneratedO",
                countsEncounterDepth = true,
                presence = {
                    kind = "authoredOptional",
                    eligibilitySnapshot = "room.prepare_encounters",
                    requirement = {
                        kind = "CounterRange",
                        axis = "biomeEncounterDepth",
                        range = { min = 2, max = 5 },
                        code = "biome_encounter_depth_out_of_range",
                    },
                },
                offerPoint = {
                    key = "wheel2",
                    surfaceKey = "ShipWheel",
                    offerCount = { min = 1, max = 2 },
                    picked = "exactlyOne",
                    offerTiming = "encounterStart",
                    acquisitionTiming = "postCombat",
                },
            },
        },
    },
    OlympusCombat = {
        kind = "fixed",
        phases = {
            { key = "Intro", kind = "combat", countsEncounterDepth = false },
            { key = "Combat", kind = "combat", countsEncounterDepth = true },
        },
    },
    Story = {
        kind = "fixed",
        phases = {
            { key = "Story", kind = "story", countsEncounterDepth = false },
        },
    },
    HealthRestore = {
        kind = "fixed",
        phases = {
            { key = "HealthRestore", kind = "nonCombat", countsEncounterDepth = false },
        },
    },
    Shop = {
        kind = "fixed",
        phases = {
            { key = "Shop", kind = "nonCombat", countsEncounterDepth = false },
        },
    },
    FieldsBridge = {
        kind = "fixed",
        phases = {
            { key = "Bridge", kind = "nonCombat", countsEncounterDepth = false },
        },
    },
    Devotion = {
        kind = "fixed",
        phases = {
            { key = "Devotion", kind = "combat", countsEncounterDepth = true },
        },
    },
    Preboss = {
        kind = "fixed",
        phases = {
            { key = "Preboss", kind = "nonCombat", countsEncounterDepth = false },
        },
    },

    F_MiniBoss01 = {
        kind = "fixed",
        phases = {
            { key = "F_MiniBoss01", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    F_MiniBoss02 = {
        kind = "fixed",
        phases = {
            { key = "F_MiniBoss02", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    F_MiniBoss03 = {
        kind = "fixed",
        phases = {
            { key = "F_MiniBoss03", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    G_MiniBoss01 = {
        kind = "fixed",
        phases = {
            { key = "G_MiniBoss01", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    G_MiniBoss02 = {
        kind = "fixed",
        phases = {
            { key = "G_MiniBoss02", kind = "miniboss", countsEncounterDepth = false },
        },
    },
    G_MiniBoss03 = {
        kind = "fixed",
        phases = {
            { key = "G_MiniBoss03", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    H_MiniBoss01 = {
        kind = "fixed",
        phases = {
            { key = "H_MiniBoss01", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    H_MiniBoss02 = {
        kind = "fixed",
        phases = {
            { key = "H_MiniBoss02", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    I_MiniBoss01 = {
        kind = "fixed",
        phases = {
            { key = "I_MiniBoss01", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    I_MiniBoss02 = {
        kind = "fixed",
        phases = {
            { key = "I_MiniBoss02", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    MiniBossSatyrCrossbow = {
        kind = "fixed",
        phases = {
            { key = "MiniBossSatyrCrossbow", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    MiniBossBoar = {
        kind = "fixed",
        phases = {
            { key = "MiniBossBoar", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    O_MiniBoss01 = {
        kind = "fixed",
        phases = {
            { key = "O_MiniBoss01", kind = "miniboss", countsEncounterDepth = false },
        },
    },
    O_MiniBoss02 = {
        kind = "fixed",
        phases = {
            { key = "O_MiniBoss02", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    P_MiniBoss01 = {
        kind = "fixed",
        phases = {
            { key = "P_MiniBoss01", kind = "miniboss", countsEncounterDepth = false },
        },
    },
    P_MiniBoss02 = {
        kind = "fixed",
        phases = {
            { key = "P_MiniBoss02", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    MiniBossBrute = {
        kind = "fixed",
        phases = {
            { key = "MiniBossBrute", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    Q_MiniBoss03 = {
        kind = "fixed",
        phases = {
            { key = "Q_MiniBoss03", kind = "miniboss", countsEncounterDepth = true },
        },
    },
    Q_MiniBoss04 = {
        kind = "fixed",
        phases = {
            { key = "Q_MiniBoss04", kind = "miniboss", countsEncounterDepth = false },
        },
    },
    Q_MiniBoss05 = {
        kind = "fixed",
        phases = {
            { key = "Q_MiniBoss05", kind = "miniboss", countsEncounterDepth = true },
        },
    },
}
