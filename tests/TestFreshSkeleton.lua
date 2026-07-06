-- luacheck: globals TestFreshSkeleton

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestFreshSkeleton = {}

function TestFreshSkeleton.testSystemsCreateReturnsFreshSkeleton()
    h.withTestImport(function()
        local systems = h.testImport("mods/systems.lua").create({
            data = h.testImport("mods/data.lua"),
        })

        lu.assertEquals(systems.controlTemplates, {})
        lu.assertEquals(systems.routeControls, {})
        lu.assertEquals(systems.routeControlTabs, {})
        lu.assertNotNil(systems.catalog.routes.lookup.Underworld)
        lu.assertNotNil(systems.catalog.biomes.lookup.F)
        lu.assertIsFunction(systems.logic.attach)
        lu.assertIsFunction(systems.ui.drawTab)
    end)
end

function TestFreshSkeleton.testUiDrawsFreshStartStatus()
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
        lu.assertNotNil(combined:find("Run Planner fresh start", 1, true))
        lu.assertNotNil(combined:find("docs/system_design", 1, true))
    end)
end
