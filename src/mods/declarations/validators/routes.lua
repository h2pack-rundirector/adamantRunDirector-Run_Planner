local guard = import("mods/declarations/guard.lua")
local common = import("mods/declarations/common.lua")

local routesValidator = {}

local function validateRoute(route, context)
    guard.expectTable(route, context)
    guard.expectString(route.key, context .. ".key")
    guard.expectString(route.label, context .. ".label")
    guard.expectNonEmptyArray(route.biomeKeys, context .. ".biomeKeys")
    for index, biomeKey in ipairs(route.biomeKeys) do
        guard.expectString(biomeKey, context .. ".biomeKeys[" .. tostring(index) .. "]")
    end
end

function routesValidator.validate(routes)
    guard.expectNonEmptyArray(routes, "routes")
    for index, route in ipairs(routes) do
        validateRoute(route, "routes[" .. tostring(index) .. "]")
    end
    return common.packageOrderedMap(routes, "routes")
end

function routesValidator.withImplementedBiomes(routesCatalog, biomesCatalog)
    local normalizedRoutes = {}

    for routeIndex, route in ipairs(routesCatalog.ordered) do
        local normalized = common.shallowCopy(route)
        normalized.implementedBiomeKeys = {}
        normalized.missingBiomeKeys = {}

        for _, biomeKey in ipairs(route.biomeKeys) do
            if biomesCatalog.lookup[biomeKey] ~= nil then
                normalized.implementedBiomeKeys[#normalized.implementedBiomeKeys + 1] = biomeKey
            else
                normalized.missingBiomeKeys[#normalized.missingBiomeKeys + 1] = biomeKey
            end
        end

        normalizedRoutes[routeIndex] = normalized
    end

    return common.packageOrderedMap(normalizedRoutes, "routes")
end

return routesValidator
