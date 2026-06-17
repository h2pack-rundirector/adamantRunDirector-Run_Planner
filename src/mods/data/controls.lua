local controls = {}

local TEMPLATE_BY_ADAPTER = {
    clockworkGoal = "ClockworkGoalRoute",
    fieldsCageRoute = "FieldsCageRoute",
    fixedLinear = "FixedLinearRoute",
    hubPylon = "HubPylonRoute",
    multiEncounterFixed = "MultiEncounterFixedRoute",
    scriptedFixedLinear = "FixedLinearRoute",
}

local function routeControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

local function routeTabForBiome(catalog, biomeKey)
    local biome = catalog.lookup and catalog.lookup[biomeKey] or nil
    local template = biome and TEMPLATE_BY_ADAPTER[biome.adapter] or nil
    if template == nil then
        return nil
    end
    return {
        key = biome.key,
        label = biome.label,
        controlName = routeControlName(biome.key),
    }
end

function controls.routeControlName(biomeKey)
    return routeControlName(biomeKey)
end

function controls.routeControlNames(catalog)
    local names = {}
    for _, biome in ipairs(catalog and catalog.ordered or {}) do
        if TEMPLATE_BY_ADAPTER[biome.adapter] ~= nil then
            names[#names + 1] = routeControlName(biome.key)
        end
    end
    return names
end

function controls.routeControlTabs(catalog)
    if catalog ~= nil and catalog.routes ~= nil and catalog.routes.ordered ~= nil then
        local tabsByRoute = {}
        for _, route in ipairs(catalog.routes.ordered) do
            local tabs = {}
            for _, biomeKey in ipairs(route.biomes or {}) do
                local tab = routeTabForBiome(catalog, biomeKey)
                if tab ~= nil then
                    tabs[#tabs + 1] = tab
                end
            end
            tabsByRoute[route.key] = tabs
        end
        return tabsByRoute
    end

    local tabsByRegion = {}
    for _, biome in ipairs(catalog and catalog.ordered or {}) do
        if TEMPLATE_BY_ADAPTER[biome.adapter] ~= nil then
            local region = biome.region or "Other"
            local tabs = tabsByRegion[region]
            if tabs == nil then
                tabs = {}
                tabsByRegion[region] = tabs
            end
            tabs[#tabs + 1] = {
                key = biome.key,
                label = biome.label,
                controlName = routeControlName(biome.key),
            }
        end
    end
    return tabsByRegion
end

function controls.build(catalog)
    local instances = {}
    for _, biome in ipairs(catalog and catalog.ordered or {}) do
        local template = TEMPLATE_BY_ADAPTER[biome.adapter]
        if template ~= nil then
            instances[routeControlName(biome.key)] = {
                template = template,
                label = biome.label,
                biome = biome,
            }
        end
    end
    return instances
end

return controls
