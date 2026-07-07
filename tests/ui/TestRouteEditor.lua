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
        lu.assertNotNil(combined:find("F route editor", 1, true))
        lu.assertNil(combined:find("debug harness", 1, true))
        lu.assertNotNil(combined:find("State: valid", 1, true))
        lu.assertNotNil(combined:find("Room 1", 1, true))
        lu.assertNotNil(combined:find("Reward##room1_door1", 1, true))
    end)
end

function TestRouteEditor.testDrawsFirstBlockingIssueMarker()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local routeEditor = h.testImport("mods/ui/planner/route_editor.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setDoorTarget(2, 1, "F_PreBoss01")
        local lines, ctx = lineSink()

        routeEditor.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find(
            "First issue: f_preboss_too_early at Room 2 (F_Combat01) door 1 (room.generate_next)",
            1,
            true
        ))
        lu.assertNotNil(combined:find("Route blocker: f_preboss_too_early", 1, true))
    end)
end

function TestRouteEditor.testDrawsDownstreamRoomsInactiveAfterFirstIssue()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local routeEditor = h.testImport("mods/ui/planner/route_editor.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setDoorTarget(2, 1, "F_PreBoss01")
        state.appendSelectedTarget()
        local lines, ctx = lineSink()

        routeEditor.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Inactive after route blocker", 1, true))
        lu.assertNotNil(combined:find("Room 3", 1, true))
    end)
end
