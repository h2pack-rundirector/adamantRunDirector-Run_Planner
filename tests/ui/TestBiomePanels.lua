-- luacheck: globals TestBiomePanels

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")
local fakeImgui = dofile("tests/support/fake_imgui.lua")

TestBiomePanels = {}

local function lineSink()
    return fakeImgui.lineSink()
end

local function createState()
    local data = h.testImport("mods/data.lua")
    local plannerState = h.testImport("mods/ui/planner/state.lua")
    return plannerState.create({
        catalog = data.loadCatalog(),
    })
end

function TestBiomePanels.testRegistryDrawsFErebusPanel()
    h.withTestImport(function()
        local registry = h.testImport("mods/ui/biomes/registry.lua")
        local state = createState()
        local route = state.catalog.routes.lookup.Underworld
        local lines, ctx = lineSink()

        registry.draw(state, ctx, route, "F", state.ensureEvaluation())

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Erebus (F)", 1, true))
        lu.assertNotNil(combined:find("Room 1 - Opening 1 (F_Opening01)", 1, true))
        lu.assertNil(combined:find("Placeholder biome panel", 1, true))
    end)
end

function TestBiomePanels.testRegistryDrawsPlaceholderForUnimplementedBiome()
    h.withTestImport(function()
        local registry = h.testImport("mods/ui/biomes/registry.lua")
        local state = createState()
        local route = state.catalog.routes.lookup.Surface
        local lines, ctx = lineSink()

        registry.draw(state, ctx, route, "N", state.ensureEvaluation())

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Placeholder biome panel", 1, true))
        lu.assertNotNil(combined:find("Route: Surface", 1, true))
        lu.assertNotNil(combined:find("Biome: N", 1, true))
        lu.assertNil(combined:find("Room 1 - Opening 1 (F_Opening01)", 1, true))
    end)
end

function TestBiomePanels.testRegistryCreateUsesInjectedPanels()
    h.withTestImport(function()
        local registry = h.testImport("mods/ui/biomes/registry.lua")
        local calls = {}
        local panels = registry.create({
            fErebusPanel = {
                draw = function(_, _, opts)
                    calls[#calls + 1] = {
                        kind = "F",
                        title = opts.title,
                        hideStatus = opts.hideStatus,
                    }
                end,
            },
            placeholderPanel = {
                draw = function(_, _, route, biomeKey)
                    calls[#calls + 1] = {
                        kind = "placeholder",
                        routeKey = route.key,
                        biomeKey = biomeKey,
                    }
                end,
            },
        })
        local state = createState()

        panels.draw(state, {}, state.catalog.routes.lookup.Underworld, "F", {
            state = "valid",
        })
        panels.draw(state, {}, state.catalog.routes.lookup.Surface, "N", {
            state = "valid",
        })

        lu.assertEquals(calls, {
            {
                kind = "F",
                title = "Erebus (F)",
                hideStatus = true,
            },
            {
                kind = "placeholder",
                routeKey = "Surface",
                biomeKey = "N",
            },
        })
    end)
end
