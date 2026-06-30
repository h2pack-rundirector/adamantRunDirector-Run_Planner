local controls = {}

local EMPTY_LIST = {}

function controls.routeControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

function controls.routeGlobalControlName(routeKey)
    return "RouteGlobal" .. tostring(routeKey or "")
end

function controls.routeNpcsControlName(routeKey)
    return "RouteNpcs" .. tostring(routeKey or "")
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

return controls
