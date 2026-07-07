-- luacheck: globals TestRouteNav

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")
local fakeImgui = dofile("tests/support/fake_imgui.lua")

TestRouteNav = {}

function TestRouteNav.testCreateUsesInjectedSelectionAndWidgets()
    h.withTestImport(function()
        local routeNav = h.testImport("mods/ui/planner/route_nav.lua")
        local route = {
            key = "Underworld",
            label = "Underworld",
            biomeKeys = { "F", "G" },
        }
        local calls = {}
        local service = routeNav.create({
            routeSelection = {
                activeRoute = function()
                    calls[#calls + 1] = {
                        kind = "activeRoute",
                    }
                    return route
                end,
                activeBiomeKey = function(_, routeArg)
                    calls[#calls + 1] = {
                        kind = "activeBiome",
                        route = routeArg,
                    }
                    return "F"
                end,
                routeDefinitions = function()
                    return { route }
                end,
                setActiveRoute = function()
                end,
                setActiveBiome = function()
                end,
            },
            widgets = {
                text = function(_, label)
                    calls[#calls + 1] = {
                        kind = "text",
                        label = label,
                    }
                end,
                separator = function()
                    calls[#calls + 1] = {
                        kind = "separator",
                    }
                end,
            },
        })
        local panels = {
            draw = function(_, _, routeArg, biomeKey)
                calls[#calls + 1] = {
                    kind = "panel",
                    route = routeArg,
                    biomeKey = biomeKey,
                }
            end,
        }
        local _, imgui = fakeImgui.surface()

        service.draw({
            catalog = {},
        }, {
            draw = {
                imgui = imgui,
                nav = {
                    verticalTabs = function(opts)
                        calls[#calls + 1] = {
                            kind = "nav",
                            id = opts.id,
                            activeKey = opts.activeKey,
                            tabs = opts.tabs,
                        }
                        return opts.activeKey
                    end,
                },
            },
        }, {
            state = "valid",
        }, panels)

        lu.assertEquals(calls[1], {
            kind = "activeRoute",
        })
        lu.assertEquals(calls[2].kind, "activeBiome")
        lu.assertIs(calls[2].route, route)
        lu.assertEquals(calls[3], {
            kind = "text",
            label = "Route: Underworld",
        })
        lu.assertEquals(calls[4].kind, "nav")
        lu.assertEquals(calls[4].id, "RunPlannerUnderworldBiomeTabs")
        lu.assertEquals(calls[4].activeKey, "F")
        lu.assertEquals(calls[4].tabs, {
            {
                key = "F",
                label = "F",
            },
            {
                key = "G",
                label = "G",
            },
        })
        lu.assertEquals(calls[5], {
            kind = "separator",
        })
        lu.assertEquals(calls[6].kind, "panel")
        lu.assertIs(calls[6].route, route)
        lu.assertEquals(calls[6].biomeKey, "F")
    end)
end
