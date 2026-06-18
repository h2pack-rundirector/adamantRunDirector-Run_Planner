local lu = require("luaunit")

-- luacheck: globals TestRunPlannerFeatures
TestRunPlannerFeatures = {}

local function definitions()
    return dofile("src/mods/features/definitions.lua")
end

function TestRunPlannerFeatures.testDefinesRouteFeatureRoster()
    local featureDefs = definitions()

    lu.assertEquals(featureDefs.ordered, {
        "ChaosGate",
    })

    local chaos = featureDefs.byKey.ChaosGate
    lu.assertEquals(chaos.key, "ChaosGate")
    lu.assertEquals(chaos.label, "Chaos")
    lu.assertEquals(chaos.featureKey, "chaos")
    lu.assertEquals(chaos.plannedSpacingRooms, 10)
    lu.assertEquals(chaos.vanillaNamedRequirement, "NoRecentChaosEncounter")
    lu.assertEquals(chaos.suppressesNaturalSpawn, true)
    lu.assertEquals(chaos.biomes, {
        F = true,
        G = true,
        N = true,
        P = true,
    })
end

function TestRunPlannerFeatures.testDataLoaderExposesFeatureDefinitions()
    local data = dofile("src/mods/data.lua")
    local featureDefs = data.loadFeatures(function(path)
        return dofile("src/" .. path)
    end)

    lu.assertEquals(featureDefs.byKey.ChaosGate.featureKey, "chaos")
end
