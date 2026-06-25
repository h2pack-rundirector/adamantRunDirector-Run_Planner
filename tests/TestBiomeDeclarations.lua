local lu = require("luaunit")

-- luacheck: globals TestRunPlannerBiomeDeclarations
TestRunPlannerBiomeDeclarations = {}

local function testImport(path)
    return dofile("src/" .. path)
end

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

function TestRunPlannerBiomeDeclarations.testCheckedInBiomeDeclarationsValidateStatically()
    local data = dofile("src/mods/data.lua")
    local validator = dofile("src/mods/biomes/validator.lua")
    local rewardDefinitions = dofile("src/mods/rewards/declarations/definitions.lua")
    local featureDefinitions = dofile("src/mods/features/definitions.lua")
    local catalog = data.loadBiomes(testImport)

    local issues = {}
    appendIssues(issues, validator.validateRewardDefinitions(rewardDefinitions))
    appendIssues(issues, validator.validateCatalog(catalog, {
        rewardDefinitions = rewardDefinitions,
        featureDefinitions = featureDefinitions,
    }))

    assertNoIssues(issues)
end

function TestRunPlannerBiomeDeclarations.testGodListDuplicatesStayInSync()
    local validator = dofile("src/mods/biomes/validator.lua")
    local gods = dofile("src/mods/data/gods.lua")
    local rewardDefinitions = dofile("src/mods/rewards/declarations/definitions.lua")
    local routeRules = dofile("src/mods/biomes/declaration_rules.lua")
    local rewardConditions = dofile("src/mods/rewards/declarations/conditions.lua")

    assertNoIssues(validator.validateGodLists(
        gods.olympian(),
        rewardDefinitions,
        routeRules,
        rewardConditions
    ))
end

function TestRunPlannerBiomeDeclarations.testValidatorReportsMalformedStaticDeclarations()
    local validator = dofile("src/mods/biomes/validator.lua")
    local rewardDefinitions = dofile("src/mods/rewards/declarations/definitions.lua")
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

    local codes = issueCodes(validator.validateBiome(malformed, {
        rewardDefinitions = rewardDefinitions,
    }))

    lu.assertTrue(codes.inverted_route_range)
    lu.assertTrue(codes.inverted_range)
    lu.assertTrue(codes.unknown_role)
    lu.assertTrue(codes.unknown_reward_store)
    lu.assertTrue(codes.missing_field)
end
