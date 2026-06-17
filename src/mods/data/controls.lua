local controls = {}

local TEMPLATE_BY_ADAPTER = {
    fixedLinear = "FixedLinearRoute",
    hubPylon = "HubPylonRoute",
    scriptedFixedLinear = "FixedLinearRoute",
}

local function routeControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
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
