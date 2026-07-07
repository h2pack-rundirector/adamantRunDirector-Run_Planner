local widgets = import("mods/ui/planner/widgets.lua")

local placeholderPanel = {}

local function biomeLabel(catalog, biomeKey)
    local biome = catalog and catalog.biomes and catalog.biomes.lookup and catalog.biomes.lookup[biomeKey] or nil
    if biome ~= nil and biome.label ~= nil then
        return tostring(biome.label) .. " (" .. tostring(biomeKey) .. ")"
    end
    return tostring(biomeKey)
end

local function routeLabel(route)
    return tostring((route and route.label) or (route and route.key) or "Route")
end

function placeholderPanel.draw(state, ctx, route, biomeKey)
    local imgui = ctx.draw.imgui
    widgets.section(imgui, biomeLabel(state and state.catalog, biomeKey))
    widgets.text(imgui, "Placeholder biome panel")
    widgets.text(imgui, "Route: " .. routeLabel(route))
    widgets.text(imgui, "Biome: " .. tostring(biomeKey))
    widgets.text(imgui, "This biome does not emit a planner snapshot yet.")
end

return placeholderPanel
