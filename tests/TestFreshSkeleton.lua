-- luacheck: globals TestFreshSkeleton

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

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
        local lines = {}
        local ctx = {
            draw = {
                imgui = {
                    Text = function(text)
                        lines[#lines + 1] = text
                    end,
                    Spacing = function()
                    end,
                },
            },
        }

        ui.drawTab(nil, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Run Planner", 1, true))
        lu.assertNotNil(combined:find("Erebus (F)", 1, true))
        lu.assertNil(combined:find("debug harness", 1, true))
    end)
end
