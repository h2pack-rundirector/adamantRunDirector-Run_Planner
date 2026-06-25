local controls = {}

local TEMPLATE_BY_ADAPTER = {
    clockworkGoal = "ClockworkGoalRoute",
    fieldsCageRoute = "FieldsCageRoute",
    fixedLinear = "FixedLinearRoute",
    hubPylon = "HubPylonRoute",
    multiEncounterFixed = "MultiEncounterFixedRoute",
    scriptedFixedLinear = "FixedLinearRoute",
}

local GLOBAL_TAB_KEY = "Global"

local function routeControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

local function routeGlobalControlName(routeKey)
    return "RouteGlobal" .. tostring(routeKey or "")
end

local function routeNpcControlName(routeKey)
    return "RouteNpcs" .. tostring(routeKey or "")
end

local function routeFeatureControlName(routeKey, featureKey)
    return "RouteFeature" .. tostring(featureKey or "") .. tostring(routeKey or "")
end

local function routeBiomeLookup(route)
    local lookup = {}
    for _, biomeKey in ipairs(route and route.biomes or {}) do
        lookup[biomeKey] = true
    end
    return lookup
end

local function routeHasFeature(routeLookup, feature)
    for biomeKey in pairs(feature and feature.biomes or {}) do
        if routeLookup[biomeKey] then
            return true
        end
    end
    return false
end

local function routeFeatureControls(catalog, route)
    local routeLookup = routeBiomeLookup(route)
    local controlNames = {}
    for _, featureKey in ipairs(catalog and catalog.features and catalog.features.ordered or {}) do
        local feature = catalog.features.byKey and catalog.features.byKey[featureKey] or nil
        if feature ~= nil and routeHasFeature(routeLookup, feature) then
            controlNames[#controlNames + 1] = routeFeatureControlName(route.key, feature.key)
        end
    end
    return controlNames
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

function controls.routeGlobalControlName(routeKey)
    return routeGlobalControlName(routeKey)
end

function controls.routeNpcControlName(routeKey)
    return routeNpcControlName(routeKey)
end

function controls.routeFeatureControlName(routeKey, featureKey)
    return routeFeatureControlName(routeKey, featureKey)
end

function controls.routeControlNames(catalog)
    local names = {}
    if catalog ~= nil and catalog.routes ~= nil and catalog.routes.ordered ~= nil then
        for _, route in ipairs(catalog.routes.ordered) do
            names[#names + 1] = routeGlobalControlName(route.key)
            for _, biomeKey in ipairs(route.biomes or {}) do
                local biome = catalog.lookup and catalog.lookup[biomeKey] or nil
                if biome ~= nil and TEMPLATE_BY_ADAPTER[biome.adapter] ~= nil then
                    names[#names + 1] = routeControlName(biome.key)
                end
            end
            names[#names + 1] = routeNpcControlName(route.key)
            for _, controlName in ipairs(routeFeatureControls(catalog, route)) do
                names[#names + 1] = controlName
            end
        end
    else
        for _, biome in ipairs(catalog and catalog.ordered or {}) do
            if TEMPLATE_BY_ADAPTER[biome.adapter] ~= nil then
                names[#names + 1] = routeControlName(biome.key)
            end
        end
    end
    return names
end

function controls.routeControlTabs(catalog)
    if catalog ~= nil and catalog.routes ~= nil and catalog.routes.ordered ~= nil then
        local tabsByRoute = {}
        for _, route in ipairs(catalog.routes.ordered) do
            local tabs = {
                {
                    key = GLOBAL_TAB_KEY,
                    label = "Global",
                    controlName = routeGlobalControlName(route.key),
                },
            }
            for _, biomeKey in ipairs(route.biomes or {}) do
                local tab = routeTabForBiome(catalog, biomeKey)
                if tab ~= nil then
                    tabs[#tabs + 1] = tab
                end
            end
            tabs[#tabs + 1] = {
                key = "NPCs",
                label = "NPCs",
                layer = "npcs",
                controlName = routeNpcControlName(route.key),
            }
            tabs[#tabs + 1] = {
                key = "Features",
                label = "Features",
                layer = "features",
                controlNames = routeFeatureControls(catalog, route),
            }
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
    if catalog ~= nil and catalog.routes ~= nil and catalog.routes.ordered ~= nil then
        for _, route in ipairs(catalog.routes.ordered) do
            instances[routeGlobalControlName(route.key)] = {
                template = "RouteGlobal",
                label = "Global",
                route = route,
                gods = catalog.gods,
                features = catalog.features,
            }
            instances[routeNpcControlName(route.key)] = {
                template = "RouteNpcs",
                label = "NPCs",
                route = route,
                npcs = catalog.npcs,
                biomeLookup = catalog.lookup,
            }
            local routeLookup = routeBiomeLookup(route)
            for _, featureKey in ipairs(catalog.features and catalog.features.ordered or {}) do
                local feature = catalog.features.byKey and catalog.features.byKey[featureKey] or nil
                if feature ~= nil and routeHasFeature(routeLookup, feature) then
                    instances[routeFeatureControlName(route.key, feature.key)] = {
                        template = "RouteFeatures",
                        label = feature.label or feature.key,
                        route = route,
                        feature = feature,
                        biomeLookup = catalog.lookup,
                    }
                end
            end
        end
    end
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
