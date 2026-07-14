-- luacheck: globals TestRouteShell

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")
local fakeImgui = dofile("tests/support/fake_imgui.lua")

TestRouteShell = {}

local function lineSink(extraDraw)
    return fakeImgui.lineSink(extraDraw)
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

function TestRouteShell.testDefaultDrawsRouteStatusAndFPanel()
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

function TestRouteShell.testCreateUsesInjectedRouteGraph()
    h.withTestImport(function()
        local routeShell = h.testImport("mods/ui/planner/route_shell.lua")
        local calls = {}
        local evaluation = {
            state = "valid",
        }
        local state = {
            dirty = false,
            feedbackLocationLabel = function()
            end,
            bindUiContext = function(ctxArg)
                calls[#calls + 1] = {
                    kind = "bind",
                    ctx = ctxArg,
                }
            end,
            ensureEvaluation = function()
                calls[#calls + 1] = {
                    kind = "evaluate",
                }
                return evaluation
            end,
        }
        local _, ctx = lineSink()
        local panels = {
            marker = "panels",
        }
        local shell = routeShell.create({
            routeNav = {
                draw = function(stateArg, ctxArg, evaluationArg, panelsArg)
                    calls[#calls + 1] = {
                        kind = "nav",
                        state = stateArg,
                        ctx = ctxArg,
                        evaluation = evaluationArg,
                        panels = panelsArg,
                    }
                end,
            },
            biomePanels = panels,
            widgets = {
                text = function(_, label)
                    calls[#calls + 1] = {
                        kind = "text",
                        label = label,
                    }
                end,
                status = function(_, evaluationArg)
                    calls[#calls + 1] = {
                        kind = "status",
                        evaluation = evaluationArg,
                    }
                end,
                separator = function()
                    calls[#calls + 1] = {
                        kind = "separator",
                    }
                end,
            },
        })

        shell.draw(state, ctx)

        lu.assertEquals(calls[1], {
            kind = "bind",
            ctx = ctx,
        })
        lu.assertEquals(calls[2], {
            kind = "evaluate",
        })
        lu.assertEquals(calls[3], {
            kind = "text",
            label = "Run Planner",
        })
        lu.assertEquals(calls[4].kind, "status")
        lu.assertIs(calls[4].evaluation, evaluation)
        lu.assertEquals(calls[5], {
            kind = "separator",
        })
        lu.assertEquals(calls[6].kind, "nav")
        lu.assertIs(calls[6].state, state)
        lu.assertIs(calls[6].ctx, ctx)
        lu.assertIs(calls[6].evaluation, evaluation)
        lu.assertIs(calls[6].panels, panels)
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
        lu.assertNotNil(combined:find("##routeUnderworld_biome1_room1_door1_targetRoom: C02 (F_Combat02)", 1, true))
    end)
end

function TestRouteShell.testDefaultDrawUsesStoredSurfaceSelectionForPlaceholder()
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
