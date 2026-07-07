-- luacheck: globals TestRouteEditor

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestRouteEditor = {}

local function lineSink()
    local lines = {}
    return lines, {
        draw = {
            imgui = {
                Text = function(text)
                    lines[#lines + 1] = text
                end,
                Separator = function()
                end,
            },
        },
    }
end

function TestRouteEditor.testDrawsPlannerStateThroughForms()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local routeEditor = h.testImport("mods/ui/planner/route_editor.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        local lines, ctx = lineSink()

        routeEditor.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Run Planner debug harness", 1, true))
        lu.assertNotNil(combined:find("State: valid", 1, true))
        lu.assertNotNil(combined:find("Room 1", 1, true))
        lu.assertNotNil(combined:find("Reward##room1_door1", 1, true))
    end)
end
