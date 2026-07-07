local fErebusPanel = import("mods/ui/biomes/f_erebus_panel.lua")
local placeholderPanel = import("mods/ui/biomes/placeholder_panel.lua")

local registry = {}

local function biomeLabel(catalog, biomeKey)
    local biome = catalog and catalog.biomes and catalog.biomes.lookup and catalog.biomes.lookup[biomeKey] or nil
    if biome ~= nil and biome.label ~= nil then
        return tostring(biome.label) .. " (" .. tostring(biomeKey) .. ")"
    end
    return tostring(biomeKey)
end

function registry.draw(state, ctx, route, biomeKey, evaluation)
    if route ~= nil and route.key == "Underworld" and biomeKey == "F" then
        return fErebusPanel.draw(state, ctx, {
            title = biomeLabel(state and state.catalog, "F"),
            hideStatus = true,
            evaluation = evaluation,
        })
    end

    return placeholderPanel.draw(state, ctx, route, biomeKey)
end

return registry
