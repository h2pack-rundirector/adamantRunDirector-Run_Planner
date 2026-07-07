-- luacheck: globals TestRouteShell

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestRouteShell = {}

local function lineSink(extraDraw)
    local lines = {}
    local draw = extraDraw or {}
    draw.imgui = draw.imgui or {}
    draw.imgui.Text = draw.imgui.Text or function(text)
        lines[#lines + 1] = text
    end
    draw.imgui.Separator = draw.imgui.Separator or function()
    end

    return lines, {
        draw = draw,
    }
end

local function createState()
    local data = h.testImport("mods/data.lua")
    local plannerState = h.testImport("mods/ui/planner/state.lua")
    return plannerState.create({
        catalog = data.loadCatalog(),
    })
end

local function copyTable(source)
    if source == nil then
        return nil
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = copyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function fakeDraftControl(draft)
    local control = {
        reads = 0,
        writes = {},
        draft = copyTable(draft),
    }

    function control:readDraft()
        self.reads = self.reads + 1
        return copyTable(self.draft)
    end

    function control:writeDraft(nextDraft)
        self.draft = copyTable(nextDraft)
        self.writes[#self.writes + 1] = copyTable(nextDraft)
        return true
    end

    return control
end

function TestRouteShell.testFallbackDrawsRouteStatusAndFPanel()
    h.withTestImport(function()
        local routeShell = h.testImport("mods/ui/planner/route_shell.lua")
        local state = createState()
        local lines, ctx = lineSink()

        routeShell.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Run Planner", 1, true))
        lu.assertNotNil(combined:find("State: valid", 1, true))
        lu.assertNotNil(combined:find("Route: Underworld", 1, true))
        lu.assertNotNil(combined:find("* Erebus (F)", 1, true))
        lu.assertNotNil(combined:find("Erebus (F)", 1, true))
        lu.assertNotNil(combined:find("Room 1", 1, true))
        lu.assertNil(combined:find("debug harness", 1, true))
    end)
end

function TestRouteShell.testDrawBindsPlannerDraftControlFromUiContext()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local routeShell = h.testImport("mods/ui/planner/route_shell.lua")
        local storedDraft = h.testImport("mods/forms/defaults.lua").fSampleDraft()
        storedDraft.biomes[1].rooms[1].generatedDoors.doors[1].targetRoomKey = "F_Combat02"
        local control = fakeDraftControl(storedDraft)
        local requestedControl
        local state = createState()
        local lines, ctx = lineSink()
        ctx.controls = {
            get = function(name)
                requestedControl = name
                return control
            end,
        }

        routeShell.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertEquals(requestedControl, data.PLANNER_DRAFT_CONTROL)
        lu.assertEquals(control.reads, 1)
        lu.assertNotNil(combined:find("Target##room1_door1: C02 (F_Combat02)", 1, true))
    end)
end

function TestRouteShell.testFallbackUsesStoredSurfaceSelectionForPlaceholder()
    h.withTestImport(function()
        local routeShell = h.testImport("mods/ui/planner/route_shell.lua")
        local state = createState()
        local lines, ctx = lineSink()
        ctx.data = {
            read = function(alias)
                return ({
                    SelectedRoute = "Surface",
                    SelectedSurfaceBiome = "N",
                })[alias]
            end,
        }

        routeShell.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Route: Surface", 1, true))
        lu.assertNotNil(combined:find("* N", 1, true))
        lu.assertNotNil(combined:find("Placeholder biome panel", 1, true))
        lu.assertNotNil(combined:find("Biome: N", 1, true))
        lu.assertNil(combined:find("Room 1", 1, true))
    end)
end

function TestRouteShell.testVerticalBiomeNavPersistsSelectionAndReusesTabs()
    h.withTestImport(function()
        local routeShell = h.testImport("mods/ui/planner/route_shell.lua")
        local state = createState()
        local lines, ctx = lineSink()
        local tabsSeen = {}
        ctx.draw.nav = {
            verticalTabs = function(opts)
                tabsSeen[#tabsSeen + 1] = opts.tabs
                if opts.activeKey == "F" then
                    return "G"
                end
                return opts.activeKey
            end,
        }
        local values = {
            SelectedRoute = "Underworld",
            SelectedUnderworldBiome = "F",
        }
        ctx.writes = {}
        ctx.data = {
            read = function(alias)
                return values[alias]
            end,
            write = function(alias, value)
                ctx.writes[#ctx.writes + 1] = {
                    alias = alias,
                    value = value,
                }
                values[alias] = value
                return true
            end,
        }

        routeShell.draw(state, ctx)
        routeShell.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertEquals(ctx.writes, {
            {
                alias = "SelectedUnderworldBiome",
                value = "G",
            },
        })
        lu.assertEquals(values.SelectedUnderworldBiome, "G")
        lu.assertIs(tabsSeen[1], tabsSeen[2])
        lu.assertNotNil(combined:find("Biome: G", 1, true))
    end)
end

function TestRouteShell.testTopRouteTabsPersistActiveRoute()
    h.withTestImport(function()
        local routeShell = h.testImport("mods/ui/planner/route_shell.lua")
        local state = createState()
        local lines, ctx = lineSink()
        ctx.draw.imgui.BeginTabBar = function()
            return true
        end
        ctx.draw.imgui.BeginTabItem = function(label)
            return label == "Surface"
        end
        ctx.draw.imgui.EndTabItem = function()
        end
        ctx.draw.imgui.EndTabBar = function()
        end
        ctx.draw.nav = {
            verticalTabs = function(opts)
                return opts.activeKey
            end,
        }
        local values = {
            SelectedRoute = "Underworld",
            SelectedSurfaceBiome = "N",
        }
        ctx.data = {
            read = function(alias)
                return values[alias]
            end,
            write = function(alias, value)
                values[alias] = value
                return true
            end,
        }

        routeShell.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertEquals(values.SelectedRoute, "Surface")
        lu.assertNotNil(combined:find("Route: Surface", 1, true))
        lu.assertNotNil(combined:find("Placeholder biome panel", 1, true))
    end)
end
