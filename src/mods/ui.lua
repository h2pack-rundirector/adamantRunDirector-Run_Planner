local ui = {}

local deps = ... or {}
local routePanelFactory = deps.routePanel
    or import("mods/ui/route_panel.lua")
local decorations = deps.decorations
    or import("mods/ui/decorations.lua")
local routeStatus = deps.routeStatus
    or import("mods/ui/route_status.lua", nil, {
        decorations = decorations,
    })
local routePanel = routePanelFactory.create({
    catalog = deps.catalog,
    routes = deps.routes,
    biomes = deps.biomes,
    npcs = deps.npcs,
    features = deps.features,
    routeContext = deps.routeContext,
    routeControlTabs = deps.routeControlTabs,
    routeStatus = routeStatus,
    decorations = decorations,
})

function ui.drawTab(_, ctx)
    routePanel.drawTab(ctx)
end

return ui
