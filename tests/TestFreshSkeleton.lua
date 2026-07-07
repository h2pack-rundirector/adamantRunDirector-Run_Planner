-- luacheck: globals TestFreshSkeleton

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")
local fakeImgui = dofile("tests/support/fake_imgui.lua")

TestFreshSkeleton = {}

function TestFreshSkeleton.testSystemsCreateReturnsFreshSkeleton()
    h.withTestImport(function()
        local systems = h.testImport("mods/systems.lua").create({
            data = h.testImport("mods/data.lua"),
        })

        lu.assertEquals(systems.storage[1].alias, "SelectedRoute")
        lu.assertEquals(systems.storage[1].default, "Underworld")
        lu.assertIsFunction(systems.controlTemplates.PlannerDraft.createRuntime)
        lu.assertEquals(systems.routeControls.PlannerDraft, {
            template = "PlannerDraft",
        })
        lu.assertEquals(systems.routeControlTabs, {})
        lu.assertNotNil(systems.catalog.routes.lookup.Underworld)
        lu.assertNotNil(systems.catalog.biomes.lookup.F)
        lu.assertIsFunction(systems.logic.attach)
        lu.assertIsFunction(systems.ui.drawTab)
    end)
end

function TestFreshSkeleton.testUiDrawsProductionEditorStatus()
    h.withTestImport(function()
        local ui = h.testImport("mods/ui.lua")
        local lines, ctx = fakeImgui.lineSink()

        ui.drawTab(nil, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Run Planner", 1, true))
        lu.assertNotNil(combined:find("Erebus (F)", 1, true))
        lu.assertNil(combined:find("debug harness", 1, true))
    end)
end

function TestFreshSkeleton.testUiCreateUsesInjectedStateAndRouteShell()
    h.withTestImport(function()
        local ui = h.testImport("mods/ui.lua")
        local state = {}
        local ctx = {}
        local calls = {}
        local instance = ui.create({
            state = state,
            routeShell = {
                draw = function(stateArg, ctxArg)
                    calls[#calls + 1] = {
                        state = stateArg,
                        ctx = ctxArg,
                    }
                end,
            },
        })

        instance.drawTab(nil, ctx)

        lu.assertIs(instance, state)
        lu.assertEquals(#calls, 1)
        lu.assertIs(calls[1].state, state)
        lu.assertIs(calls[1].ctx, ctx)
    end)
end
