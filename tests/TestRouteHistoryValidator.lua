local lu = require("luaunit")
local h = require("tests.support.control_harness")

local historySystem = h.withTestImport(function()
    return h.testImport("mods/route/history/assembly.lua").create()
end)
local historyBuilder = historySystem.builder
local historyValidator = historySystem.validator

-- luacheck: globals TestRunPlannerRouteHistoryValidator
TestRunPlannerRouteHistoryValidator = {}

local function buildHistory(route, biomeKey, template, rows)
    local catalog = h.loadCatalog()
    local instance = template.prepare({
        name = "Route" .. biomeKey,
        biome = catalog.lookup[biomeKey],
    })
    local control = template.createRuntime(h.routeFields(rows), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()
    return historyBuilder.build({
        route = route,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, requestedBiomeKey)
            if requestedBiomeKey == biomeKey then
                return selectedSnapshot
            end
            return nil
        end,
    }), catalog
end

local function validate(route, biomeKey, template, rows)
    local history, catalog = buildHistory(route, biomeKey, template, rows)
    return historyValidator.validate({
        route = route,
        history = history,
        biomeLookup = catalog.lookup,
    })
end

function TestRunPlannerRouteHistoryValidator.testValidatorRejectsDuplicateConcreteRoom()
    local route = {
        key = "Underworld",
        biomes = { "F" },
    }
    local result = validate(route, "F", h.loadFixedLinearTemplate(), {
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxManaDrop",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "option_limit")
    lu.assertEquals(result.invalids[1].biomeKey, "F")
    lu.assertEquals(result.invalids[1].roomKey, "F_Combat02")
end

function TestRunPlannerRouteHistoryValidator.testValidatorRejectsMissingFieldsBridgeForcePressure()
    local route = {
        key = "Underworld",
        biomes = { "H" },
    }
    local result = validate(route, "H", h.loadFieldsCageTemplate(), {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "TwoRewards",
            Reward1Key = "Boon",
            Reward1LootKey = "PoseidonUpgrade",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat09",
            VariantKey = "TwoRewards",
            SiblingStructureKey = "CombatCage2",
            Reward1Key = "Boon",
            Reward1LootKey = "HestiaUpgrade",
            Reward2Key = "WeaponUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat13",
            VariantKey = "TwoRewards",
            SiblingStructureKey = "H_MiniBoss02",
            Reward1Key = "HermesUpgrade",
            Reward2Key = "StackUpgrade",
        },
    })

    lu.assertFalse(result.valid)
    lu.assertEquals(result.invalids[1].code, "forced_topology_pressure_unresolved")
    lu.assertEquals(result.invalids[1].biomeKey, "H")
    lu.assertEquals(result.invalids[1].roomKey, "H_Combat13")
end

function TestRunPlannerRouteHistoryValidator.testValidatorAcceptsGeneratedFieldsBridge()
    local route = {
        key = "Underworld",
        biomes = { "H" },
    }
    local result = validate(route, "H", h.loadFieldsCageTemplate(), {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "TwoRewards",
            Reward1Key = "Boon",
            Reward1LootKey = "PoseidonUpgrade",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat09",
            VariantKey = "TwoRewards",
            SiblingStructureKey = "CombatCage2",
            Reward1Key = "Boon",
            Reward1LootKey = "HestiaUpgrade",
            Reward2Key = "WeaponUpgrade",
        },
        {
            RoleKey = "Bridge",
            SiblingStructureKey = "H_MiniBoss02",
        },
    })

    lu.assertTrue(result.valid)
end
