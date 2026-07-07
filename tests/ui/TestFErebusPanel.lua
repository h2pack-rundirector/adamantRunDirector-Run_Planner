-- luacheck: globals TestFErebusPanel

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestFErebusPanel = {}

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

function TestFErebusPanel.testDrawsPlannerStateThroughForms()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("F / Erebus", 1, true))
        lu.assertNil(combined:find("debug harness", 1, true))
        lu.assertNotNil(combined:find("State: valid", 1, true))
        lu.assertNotNil(combined:find("Room 1 - Opening 1 (F_Opening01)", 1, true))
        lu.assertNotNil(combined:find("Room identity", 1, true))
        lu.assertNotNil(combined:find("Generated door batch", 1, true))
        lu.assertNotNil(combined:find("Generated reward offer", 1, true))
        lu.assertNotNil(combined:find("Reward##room1_door1", 1, true))
    end)
end

function TestFErebusPanel.testDrawsFirstBlockingIssueMarker()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setDoorTarget(2, 1, "F_PreBoss01")
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find(
            "First issue: f_preboss_too_early at Room 2 (F_Combat01) door 1 (room.generate_next)",
            1,
            true
        ))
        lu.assertNotNil(combined:find("Route blocker: f_preboss_too_early", 1, true))
    end)
end

function TestFErebusPanel.testDrawsDownstreamRoomsInactiveAfterFirstIssue()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setDoorTarget(2, 1, "F_PreBoss01")
        state.appendSelectedTarget()
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Inactive after route blocker", 1, true))
        lu.assertNotNil(combined:find("Room 3", 1, true))
    end)
end

function TestFErebusPanel.testDrawsRoomLocalOfferInsideRoomUnit()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setDoorTarget(1, 1, "F_Shop01")
        state.setRoomKey(2, "F_Shop01")
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Room 2 - Shop (F_Shop01)", 1, true))
        lu.assertNotNil(combined:find("Room-local offers", 1, true))
        lu.assertNotNil(combined:find("Room offer 1 / shop", 1, true))
        lu.assertNotNil(combined:find("Room reward##room2", 1, true))
    end)
end
