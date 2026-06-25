local lu = require("luaunit")
local importHarness = require("tests.support.import_harness")
local withTestImport = importHarness.withTestImport

-- luacheck: globals TestRunPlannerNpcs
TestRunPlannerNpcs = {}

local function definitions()
    return dofile("src/mods/data/npcs.lua")
end

local function sortedKeys(map)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function variantNames(entry)
    local names = {}
    for _, variant in ipairs(entry and entry.variants or {}) do
        names[#names + 1] = variant.encounterName
    end
    return names
end

local function variantByKey(entry, key)
    for _, variant in ipairs(entry and entry.variants or {}) do
        if variant.key == key then
            return variant
        end
    end
    return nil
end

function TestRunPlannerNpcs.testDefinesRouteNpcRoster()
    local npcDefs = definitions()

    lu.assertEquals(npcDefs.ordered, {
        "Artemis",
        "Nemesis",
        "Heracles",
        "Icarus",
        "Athena",
        "Arachne",
    })
    local expectedGroups = {
        Artemis = "FieldNpc",
        Nemesis = "FieldNpc",
        Heracles = "FieldNpc",
        Icarus = "FieldNpc",
        Athena = "FieldNpc",
        Arachne = "ArachneCombat",
    }
    local expectedMaxSelectionsPerRun = {
        Artemis = 1,
        Nemesis = 1,
        Heracles = 1,
        Icarus = 1,
        Athena = 1,
    }
    for _, key in ipairs(npcDefs.ordered) do
        local npc = npcDefs.byKey[key]
        lu.assertEquals(npc.key, key)
        lu.assertEquals(npc.routeGroup, expectedGroups[key])
        lu.assertEquals(npc.maxSelectionsPerRun, expectedMaxSelectionsPerRun[key])
        lu.assertNil(npc.personalGroup, key)
    end
end

function TestRunPlannerNpcs.testDefinesBiomeCoverage()
    local npcs = definitions().byKey

    lu.assertEquals(sortedKeys(npcs.Artemis.biomes), { "F", "G", "N" })
    lu.assertEquals(sortedKeys(npcs.Nemesis.biomes), { "F", "G", "H", "I" })
    lu.assertEquals(sortedKeys(npcs.Heracles.biomes), { "N", "O", "P" })
    lu.assertEquals(sortedKeys(npcs.Icarus.biomes), { "O", "P" })
    lu.assertEquals(sortedKeys(npcs.Athena.biomes), { "P" })
    lu.assertEquals(sortedKeys(npcs.Arachne.biomes), { "F", "G" })
end

function TestRunPlannerNpcs.testDefinesEncounterVariants()
    local npcs = definitions().byKey

    lu.assertEquals(variantNames(npcs.Artemis.biomes.F), {
        "ArtemisCombatF",
    })
    lu.assertEquals(variantNames(npcs.Nemesis.biomes.F), {
        "NemesisCombatF",
        "NemesisRandomEvent",
    })
    lu.assertEquals(variantNames(npcs.Nemesis.biomes.G), {
        "NemesisCombatG",
        "NemesisRandomEvent",
    })
    lu.assertEquals(variantNames(npcs.Nemesis.biomes.I), {
        "NemesisCombatI",
    })
    lu.assertEquals(variantNames(npcs.Heracles.biomes.O), {
        "HeraclesCombatO",
    })
    lu.assertEquals(variantNames(npcs.Icarus.biomes.O), {
        "IcarusCombatO",
    })
    lu.assertEquals(variantNames(npcs.Athena.biomes.P), {
        "AthenaCombatP",
    })
    lu.assertEquals(variantNames(npcs.Arachne.biomes.F), {
        "ArachneCombatF",
    })
    lu.assertEquals(variantNames(npcs.Arachne.biomes.G), {
        "ArachneCombatG",
    })
end

function TestRunPlannerNpcs.testDefinesNemesisRandomEventAsCombatSlotVariant()
    local nemesis = definitions().byKey.Nemesis
    local randomF = variantByKey(nemesis.biomes.F, "Random")
    local combatF = variantByKey(nemesis.biomes.F, "Combat")

    lu.assertEquals(combatF.encounterName, "NemesisCombatF")
    lu.assertEquals(combatF.targetKind, "combatSlot")
    lu.assertEquals(combatF.rewardBehavior, "roomReward")
    lu.assertEquals(randomF.encounterName, "NemesisRandomEvent")
    lu.assertEquals(randomF.targetKind, "combatSlot")
    lu.assertEquals(randomF.encounterType, "NonCombat")
    lu.assertEquals(randomF.rewardBehavior, "nemesisRandomEvent")
    lu.assertEquals(randomF.biomeDepthCache.min, 4)
    lu.assertEquals(randomF.disallowDreamRun, true)
    lu.assertNil(variantByKey(nemesis.biomes.H, "Random"))
    lu.assertNil(variantByKey(nemesis.biomes.I, "Random"))
end

function TestRunPlannerNpcs.testDefinesRouteMajorNpcGroup()
    local groups = definitions().groups

    lu.assertNil(groups.Nemesis)
    lu.assertNil(groups.Heracles)
    lu.assertNil(groups.FieldNpc.maxSelectionsPerRun)
    lu.assertEquals(groups.FieldNpc.plannedSpacingRooms, 6)
    lu.assertEquals(groups.FieldNpc.vanillaNamedRequirement, "NoRecentFieldNPCEncounter")
    lu.assertItemsEquals(groups.FieldNpc.encounterNames, {
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
    })
end

function TestRunPlannerNpcs.testDefinesArachneCocoonCombatGroup()
    local groups = definitions().groups

    lu.assertEquals(groups.ArachneCombat.maxSelectionsPerBiome, 1)
    lu.assertEquals(groups.ArachneCombat.plannedSpacingRooms, 5)
    lu.assertEquals(groups.ArachneCombat.vanillaNamedRequirement, "NoRecentArachneEncounter")
    lu.assertItemsEquals(groups.ArachneCombat.encounterNames, {
        "ArachneCombatF",
        "ArachneCombatG",
    })
end

function TestRunPlannerNpcs.testOmitsMetaProgressionAndChanceBoostVariants()
    local npcDefs = definitions()

    for _, npc in pairs(npcDefs.byKey) do
        for _, biome in pairs(npc.biomes) do
            for _, variant in ipairs(biome.variants or {}) do
                lu.assertNil(variant.encounterName:match("Intro"), variant.encounterName)
                lu.assertNil(variant.encounterName:match("%d$"), variant.encounterName)
            end
        end
    end
    for _, group in pairs(npcDefs.groups) do
        for _, encounterName in ipairs(group.encounterNames or {}) do
            lu.assertNil(encounterName:match("Intro"), encounterName)
            lu.assertNil(encounterName:match("%d$"), encounterName)
        end
    end
end

function TestRunPlannerNpcs.testDefinesDepthAndLegRequirements()
    local npcs = definitions().byKey

    lu.assertEquals(npcs.Artemis.biomes.F.variants[1].biomeDepthCache.min, 4)
    lu.assertEquals(npcs.Nemesis.biomes.H.variants[1].biomeEncounterDepth.min, 1)
    lu.assertEquals(npcs.Icarus.biomes.O.encounterLeg, "main")
    lu.assertEquals(npcs.Heracles.biomes.O.encounterLeg, "intro")
    lu.assertEquals(npcs.Heracles.biomes.P.requiredRoomTag, "Indoor")
    lu.assertEquals(npcs.Icarus.biomes.P.requiredRoomTag, "Outdoor")
    lu.assertEquals(npcs.Arachne.biomes.F.variants[1].biomeDepthCache.min, 4)
    lu.assertEquals(npcs.Arachne.biomes.F.variants[1].biomeDepthCache.max, 8)
    lu.assertNil(npcs.Arachne.biomes.F.variants[1].requiresCompletedRuns)
    lu.assertNil(npcs.Arachne.biomes.F.variants[1].requiresCompletedEncountersAny)
    lu.assertNil(npcs.Arachne.biomes.G.variants[1].requiresCompletedEncounter)
end

function TestRunPlannerNpcs.testDefinesRewardBanSets()
    local npcDefs = definitions()

    lu.assertEquals(npcDefs.rewardBanSets.FieldNpcMajor, {
        "Boon",
        "SpellDrop",
        "Devotion",
        "HermesUpgrade",
        "WeaponUpgrade",
    })
    lu.assertEquals(npcDefs.rewardBanSets.NemesisMajor, {
        "Boon",
        "SpellDrop",
        "Devotion",
        "HermesUpgrade",
        "WeaponUpgrade",
        "StackUpgrade",
        "TalentDrop",
    })
    lu.assertEquals(npcDefs.rewardBanSets.ArachneMajor, {
        "Boon",
        "SpellDrop",
        "Devotion",
        "HermesUpgrade",
        "WeaponUpgrade",
        "StackUpgrade",
        "TalentDrop",
    })
    lu.assertEquals(npcDefs.rewardBanSets.Heracles, {
        "Devotion",
    })

    lu.assertEquals(npcDefs.byKey.Artemis.rewardBanSet, "FieldNpcMajor")
    lu.assertEquals(npcDefs.byKey.Nemesis.rewardBanSet, "NemesisMajor")
    lu.assertEquals(npcDefs.byKey.Heracles.rewardBanSet, "Heracles")
    lu.assertEquals(npcDefs.byKey.Arachne.rewardBanSet, "ArachneMajor")
end

function TestRunPlannerNpcs.testDoesNotModelKeepsakeSpecialCases()
    local npcDefs = definitions()

    for _, npc in pairs(npcDefs.byKey) do
        lu.assertNil(npc.expiresKeepsake, npc.key)
        lu.assertNil(npc.blocksKeepsakes, npc.key)
    end
end

function TestRunPlannerNpcs.testDataLoaderExposesNpcDefinitions()
    local data = dofile("src/mods/data.lua")
    local npcDefs = withTestImport(function()
        return data.loadNpcs()
    end)

    lu.assertEquals(npcDefs.byKey.Athena.biomes.P.variants[1].encounterName, "AthenaCombatP")
end
