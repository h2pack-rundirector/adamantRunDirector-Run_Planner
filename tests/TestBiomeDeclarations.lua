local lu = require("luaunit")
local importHarness = require("tests.support.import_harness")
local withTestImport = importHarness.withTestImport

-- luacheck: globals TestRunPlannerBiomeDeclarations
TestRunPlannerBiomeDeclarations = {}

local function appendIssues(target, source)
    for _, issue in ipairs(source or {}) do
        target[#target + 1] = issue
    end
end

local function issueText(issue)
    return table.concat({
        issue.code or "?",
        issue.path or "?",
        issue.message or "?",
    }, ": ")
end

local function assertNoIssues(issues)
    if #issues == 0 then
        return
    end

    local messages = {}
    for index, issue in ipairs(issues) do
        messages[index] = issueText(issue)
    end
    lu.fail("Expected no declaration issues:\n" .. table.concat(messages, "\n"))
end

local function issueCodes(issues)
    local codes = {}
    for _, issue in ipairs(issues) do
        codes[issue.code] = true
    end
    return codes
end

local function hasValue(items, value)
    for _, item in ipairs(items or {}) do
        if item == value then
            return true
        end
    end
    return false
end

local function validatorOptions(rewardDomain)
    return {
        rewardDomain = rewardDomain,
        featureDefinitions = dofile("src/mods/data/features.lua"),
    }
end

function TestRunPlannerBiomeDeclarations.testCheckedInBiomeDeclarationsValidateStatically()
    local data = dofile("src/mods/data.lua")
    local validator = dofile("src/mods/biomes/validator.lua")
    local catalogDeps = importHarness.loadCatalogDeps()
    local rewardDomain = importHarness.loadRewardDomain(catalogDeps.godData)
    local catalog = withTestImport(function()
        return data.loadBiomes(catalogDeps)
    end)

    local issues = {}
    appendIssues(issues, validator.validateRewardDomain(rewardDomain))
    appendIssues(issues, validator.validateCatalog(catalog, validatorOptions(rewardDomain)))

    assertNoIssues(issues)
end

function TestRunPlannerBiomeDeclarations.testGodListDuplicatesStayInSync()
    local validator = dofile("src/mods/biomes/validator.lua")
    local godData = importHarness.loadGodData()
    local routeRules = importHarness.loadRouteRules(godData)
    local rewardDomain = importHarness.loadRewardDomain(godData)
    local rewardConditions = importHarness.loadRewardConditions(godData)

    assertNoIssues(validator.validateGodLists(
        godData,
        rewardDomain,
        routeRules,
        rewardConditions
    ))
end

function TestRunPlannerBiomeDeclarations.testGodDataDerivesDevotionPrerequisiteSubset()
    local gods = importHarness.loadGodData()

    lu.assertTrue(hasValue(gods.godLootNames(), "AresUpgrade"))
    lu.assertFalse(hasValue(gods.devotionPrerequisiteLootNames(), "AresUpgrade"))
end

function TestRunPlannerBiomeDeclarations.testRouteMembershipMatchesBiomeRegions()
    local data = dofile("src/mods/data.lua")
    local catalog = withTestImport(function()
        return data.loadBiomes(importHarness.loadCatalogDeps())
    end)
    local seenBiomes = {}

    for _, route in ipairs(catalog.routes.ordered or {}) do
        local seenInRoute = {}
        for _, biomeKey in ipairs(route.biomes or {}) do
            lu.assertNil(seenInRoute[biomeKey], "Duplicate biome in route: " .. tostring(biomeKey))
            lu.assertNil(seenBiomes[biomeKey], "Biome appears in multiple routes: " .. tostring(biomeKey))

            local biome = catalog.lookup[biomeKey]
            lu.assertNotNil(biome, "Route references unknown biome: " .. tostring(biomeKey))
            lu.assertEquals(biome.region, route.key)

            seenInRoute[biomeKey] = true
            seenBiomes[biomeKey] = route.key
        end
    end

    for _, biome in ipairs(catalog.ordered or {}) do
        lu.assertNotNil(seenBiomes[biome.key], "Biome missing from routes: " .. tostring(biome.key))
    end
end

function TestRunPlannerBiomeDeclarations.testValidatorReportsMalformedStaticDeclarations()
    local validator = dofile("src/mods/biomes/validator.lua")
    local rewardDomain = importHarness.loadRewardDomain()
    local malformed = {
        key = "X",
        label = "Broken",
        region = "Test",
        adapter = "fixedLinear",
        slotLayout = {
            routeStartOrdinal = 3,
            routeEndOrdinal = 2,
            depthRange = { min = 4, max = 1 },
            special = {
                [1] = {
                    key = "Special",
                    label = "Special",
                    roleKey = "MissingRole",
                },
            },
        },
        roles = {
            {
                key = "Combat",
                label = "Combat",
                reward = {
                    kind = "roomStore",
                    rewardStore = "MissingStore",
                },
                mapOptions = {
                    {
                        key = "X_Combat01",
                        availability = {
                            biomeDepthCache = { min = 8, max = 4 },
                        },
                    },
                },
            },
            {
                key = "Story",
                label = "Story",
            },
        },
    }

    local codes = issueCodes(validator.validateBiome(malformed, validatorOptions(rewardDomain)))

    lu.assertTrue(codes.unknown_role)
    lu.assertTrue(codes.unknown_reward_store)
end
