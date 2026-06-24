local lu = require("luaunit")

-- luacheck: globals TestRunPlannerFeatures
TestRunPlannerFeatures = {}

local function definitions()
    return dofile("src/mods/features/definitions.lua")
end

function TestRunPlannerFeatures.testDefinesRouteFeatureRoster()
    local featureDefs = definitions()

    lu.assertEquals(featureDefs.ordered, {
        "StygianWell",
        "HermesShrine",
    })

    lu.assertNil(featureDefs.byKey.ChaosGate)

    local well = featureDefs.byKey.StygianWell
    lu.assertEquals(well.key, "StygianWell")
    lu.assertEquals(well.label, "Stygian Well")
    lu.assertEquals(well.featureKey, "wellShop")
    lu.assertEquals(well.plannedSpacingRooms, 4)
    lu.assertEquals(well.defaultManagedCount, 1)
    lu.assertEquals(well.maxManagedCount, 10)
    lu.assertEquals(well.suppressesNaturalSpawn, true)
    lu.assertEquals(well.biomes, {
        F = true,
        G = true,
        H = true,
        I = true,
    })

    local shrine = featureDefs.byKey.HermesShrine
    lu.assertEquals(shrine.key, "HermesShrine")
    lu.assertEquals(shrine.label, "Hermes Shrine")
    lu.assertEquals(shrine.featureKey, "surfaceShop")
    lu.assertEquals(shrine.plannedSpacingRooms, 3)
    lu.assertEquals(shrine.defaultManagedCount, 1)
    lu.assertEquals(shrine.maxManagedCount, 10)
    lu.assertEquals(shrine.suppressesNaturalSpawn, true)
    lu.assertEquals(shrine.biomes, {
        N = true,
        O = true,
        P = true,
        Q = true,
    })
end

function TestRunPlannerFeatures.testDataLoaderExposesFeatureDefinitions()
    local data = dofile("src/mods/data.lua")
    local featureDefs = data.loadFeatures(function(path)
        return dofile("src/" .. path)
    end)

    lu.assertNil(featureDefs.byKey.ChaosGate)
    lu.assertEquals(featureDefs.byKey.StygianWell.featureKey, "wellShop")
    lu.assertEquals(featureDefs.byKey.HermesShrine.featureKey, "surfaceShop")
end
