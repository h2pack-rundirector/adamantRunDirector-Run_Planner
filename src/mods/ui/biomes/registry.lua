local fErebusPanel = import("mods/ui/biomes/f_erebus_panel.lua")
local placeholderPanel = import("mods/ui/biomes/placeholder_panel.lua")

local registry = {}
local defaultInstance

local function biomeLabel(catalog, biomeKey)
    local biome = catalog and catalog.biomes and catalog.biomes.lookup and catalog.biomes.lookup[biomeKey] or nil
    if biome ~= nil and biome.label ~= nil then
        return tostring(biome.label) .. " (" .. tostring(biomeKey) .. ")"
    end
    return tostring(biomeKey)
end

local function drawPanel(service, state, ctx, route, biomeKey, evaluation)
    if route ~= nil and route.key == "Underworld" and biomeKey == "F" then
        return service.fErebusPanel.draw(state, ctx, {
            title = biomeLabel(state and state.catalog, "F"),
            hideStatus = true,
            evaluation = evaluation,
        })
    end

    return service.placeholderPanel.draw(state, ctx, route, biomeKey)
end

function registry.create(deps)
    deps = deps or {}
    local service = {
        fErebusPanel = deps.fErebusPanel or fErebusPanel,
        placeholderPanel = deps.placeholderPanel or placeholderPanel,
    }

    function service.draw(state, ctx, route, biomeKey, evaluation)
        return drawPanel(service, state, ctx, route, biomeKey, evaluation)
    end

    return service
end

function registry.draw(state, ctx, route, biomeKey, evaluation)
    if defaultInstance == nil then
        defaultInstance = registry.create()
    end
    return defaultInstance.draw(state, ctx, route, biomeKey, evaluation)
end

return registry
