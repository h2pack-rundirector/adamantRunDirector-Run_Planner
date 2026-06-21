local controls = {}

local EMPTY_LIST = {}

function controls.routeControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

function controls.routeGlobalControlName(routeKey)
    return "RouteGlobal" .. tostring(routeKey or "")
end

function controls.routeNpcControlName(routeKey)
    return "RouteNpcs" .. tostring(routeKey or "")
end

function controls.routeFeatureControlName(routeKey, featureKey)
    return "RouteFeature" .. tostring(featureKey or "") .. tostring(routeKey or "")
end

function controls.buildRouteInfo(routes)
    local routeInfoByRoute = {}
    local routeInfoByBiome = {}
    for _, route in ipairs(routes and routes.ordered or EMPTY_LIST) do
        local routeInfos = {}
        routeInfoByRoute[route.key] = routeInfos
        for index, routeBiomeKey in ipairs(route.biomes or EMPTY_LIST) do
            local info = {
                route = route,
                index = index,
                controlName = controls.routeControlName(routeBiomeKey),
            }
            routeInfos[routeBiomeKey] = info
            if routeInfoByBiome[routeBiomeKey] == nil then
                routeInfoByBiome[routeBiomeKey] = info
            end
        end
    end
    return routeInfoByRoute, routeInfoByBiome
end

local function routeBiomeLookup(route)
    local routeLookup = {}
    for _, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        routeLookup[biomeKey] = true
    end
    return routeLookup
end

local function routeHasFeature(routeLookup, feature)
    for biomeKey in pairs(feature and feature.biomes or {}) do
        if routeLookup[biomeKey] then
            return true
        end
    end
    return false
end

function controls.buildRouteFeatureKeysByRoute(routes, features)
    local byRoute = {}
    for _, route in ipairs(routes and routes.ordered or EMPTY_LIST) do
        local routeLookup = routeBiomeLookup(route)
        local keys = {}
        for _, featureKey in ipairs(features and features.ordered or EMPTY_LIST) do
            local feature = features.byKey and features.byKey[featureKey] or nil
            if feature ~= nil and routeHasFeature(routeLookup, feature) then
                keys[#keys + 1] = feature.key
            end
        end
        byRoute[route.key] = keys
    end
    return byRoute
end

function controls.routeFeatureKeys(context, route)
    return context.routeFeatureKeysByRoute[route.key] or EMPTY_LIST
end

return controls
