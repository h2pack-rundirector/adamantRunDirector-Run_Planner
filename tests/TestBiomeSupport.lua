-- luacheck: globals TestBiomeSupport

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestBiomeSupport = {}

local function clone(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[clone(key)] = clone(child)
    end
    return result
end

local function assertFails(callback, expected)
    local ok, err = pcall(callback)
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), expected)
end

local function record(declarations, biomeStepKey)
    for _, value in ipairs(declarations) do
        if value.biomeStepKey == biomeStepKey then
            return value
        end
    end
    error("missing biome support declaration " .. biomeStepKey)
end

local function loadAssembly(declarations)
    return h.testImport("mods/composition/biome_support.lua", nil, {
        declarations = declarations,
    })
end

function TestBiomeSupport.testDeclaresAndVerifiesCurrentBiomeCapabilities()
    h.withImport(function()
        local systems = h.testImport("mods/systems.lua").create()
        local support = systems.biomeSupport

        lu.assertEquals(#support.biomes.ordered, 8)
        lu.assertTrue(support.biomes.lookup.Underworld_F.focusedRoomControls)
        lu.assertTrue(support.biomes.lookup.Underworld_G.focusedRoomControls)
        for _, biomeStepKey in ipairs({
            "Underworld_H", "Underworld_I", "Surface_N", "Surface_O", "Surface_P", "Surface_Q",
        }) do
            local biome = support.biomes.lookup[biomeStepKey]
            lu.assertFalse(biome.focusedRoomControls, biomeStepKey)
            lu.assertFalse(biome.topology, biomeStepKey)
            lu.assertFalse(biome.materialization, biomeStepKey)
            lu.assertFalse(biome.headlessPipeline, biomeStepKey)
            lu.assertFalse(biome.plannerActive, biomeStepKey)
        end
        lu.assertNil(support.routes.lookup.Underworld.maximumActivePrefix)
        lu.assertNil(support.routes.lookup.Surface.maximumActivePrefix)

        local focused = 0
        local transitional = 0
        for _, room in ipairs(systems.controls.manifest.rooms.ordered) do
            if room.implementationKind == "focused" then
                focused = focused + 1
            elseif room.implementationKind == "transitional" then
                transitional = transitional + 1
            end
            if room.biomeStepKey == "Underworld_F" or room.biomeStepKey == "Underworld_G" then
                lu.assertEquals(room.implementationKind, "focused", room.key)
            end
        end
        lu.assertEquals(focused, 106)
        lu.assertEquals(transitional, 103)
    end)
end

function TestBiomeSupport.testRejectsClaimsThatDoNotMatchAssembledEvidence()
    h.withImport(function()
        local systems = h.testImport("mods/systems.lua").create()
        local base = h.testImport("mods/composition/biome_support_declarations.lua")

        local hClaim = clone(base)
        record(hClaim, "Underworld_H").focusedRoomControls = true
        assertFails(function()
            loadAssembly(hClaim).create(systems.catalog, systems.controls.manifest)
        end, "room control 'Underworld_H_Combat01' is transitional")

        local fClaim = clone(base)
        record(fClaim, "Underworld_F").topology = true
        assertFails(function()
            loadAssembly(fClaim).create(systems.catalog, systems.controls.manifest)
        end, "biomes[1].topology: does not match assembled implementation evidence")

        local fDenial = clone(base)
        record(fDenial, "Underworld_F").focusedRoomControls = false
        assertFails(function()
            loadAssembly(fDenial).create(systems.catalog, systems.controls.manifest)
        end, "biomes[1].focusedRoomControls: does not match assembled implementation evidence")
    end)
end

function TestBiomeSupport.testRejectsMissingDependenciesAndNoncontiguousActivation()
    h.withImport(function()
        local systems = h.testImport("mods/systems.lua").create()
        local base = h.testImport("mods/composition/biome_support_declarations.lua")

        local missingDependency = clone(base)
        record(missingDependency, "Underworld_F").materialization = true
        assertFails(function()
            loadAssembly(missingDependency).create(systems.catalog, systems.controls.manifest)
        end, "materialization: requires topology")

        local noncontiguous = clone(base)
        local f = record(noncontiguous, "Underworld_F")
        local g = record(noncontiguous, "Underworld_G")
        f.topology = true
        f.materialization = true
        f.headlessPipeline = true
        g.topology = true
        g.materialization = true
        g.headlessPipeline = true
        g.plannerActive = true
        local evidence = {
            topology = { Underworld_F = true, Underworld_G = true },
            materialization = { Underworld_F = true, Underworld_G = true },
            headlessPipeline = { Underworld_F = true, Underworld_G = true },
            plannerActive = { Underworld_G = true },
        }
        assertFails(function()
            loadAssembly(noncontiguous).create(systems.catalog, systems.controls.manifest, evidence)
        end, "does not form a contiguous active prefix")
    end)
end

function TestBiomeSupport.testRejectsIncompleteOrUnknownBiomeDeclarations()
    h.withImport(function()
        local systems = h.testImport("mods/systems.lua").create()
        local base = h.testImport("mods/composition/biome_support_declarations.lua")

        local incomplete = clone(base)
        table.remove(incomplete)
        assertFails(function()
            loadAssembly(incomplete).create(systems.catalog, systems.controls.manifest)
        end, "missing declaration for biome 'Surface_Q'")

        local unknown = clone(base)
        unknown[8].biomeStepKey = "Surface_Missing"
        assertFails(function()
            loadAssembly(unknown).create(systems.catalog, systems.controls.manifest)
        end, "unknown biome 'Surface_Missing'")

        local implicit = clone(base)
        implicit[1].topology = nil
        assertFails(function()
            loadAssembly(implicit).create(systems.catalog, systems.controls.manifest)
        end, "topology: expected an explicit boolean")
    end)
end
