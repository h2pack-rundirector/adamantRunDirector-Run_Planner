local routeSelection = {}

local EMPTY_LIST = {}
local ROUTE_BIOME_SELECTION = {
    Underworld = "SelectedUnderworldBiome",
    Surface = "SelectedSurfaceBiome",
}

local function fieldFor(data, alias)
    if data == nil or type(data.get) ~= "function" then
        return nil
    end
    local ok, field = pcall(data.get, alias)
    if ok then
        return field
    end
    return nil
end

local function readData(ctx, alias)
    local data = ctx and ctx.data or nil
    if data == nil then
        return nil
    end
    if type(data.read) == "function" then
        local ok, value = pcall(data.read, alias)
        if ok then
            return value
        end
    end
    local field = fieldFor(data, alias)
    if field ~= nil and type(field.read) == "function" then
        local ok, value = pcall(field.read, field)
        if ok then
            return value
        end
    end
    return nil
end

local function writeData(ctx, alias, value)
    local data = ctx and ctx.data or nil
    if data == nil then
        return false
    end
    if type(data.write) == "function" then
        local ok, changed = pcall(data.write, alias, value)
        if ok then
            return changed ~= false
        end
    end
    local field = fieldFor(data, alias)
    if field ~= nil and type(field.write) == "function" then
        local ok, changed = pcall(field.write, field, value)
        if ok then
            return changed ~= false
        end
    end
    return false
end

local function contains(list, value)
    for _, candidate in ipairs(list or EMPTY_LIST) do
        if candidate == value then
            return true
        end
    end
    return false
end

function routeSelection.routeDefinitions(catalog)
    return catalog and catalog.routes and catalog.routes.ordered or EMPTY_LIST
end

function routeSelection.routeLookup(catalog, routeKey)
    return catalog and catalog.routes and catalog.routes.lookup and catalog.routes.lookup[routeKey] or nil
end

function routeSelection.activeRoute(state, ctx)
    local stored = readData(ctx, "SelectedRoute")
    local route = routeSelection.routeLookup(state.catalog, stored)
    if route ~= nil then
        return route
    end
    return routeSelection.routeDefinitions(state.catalog)[1]
end

function routeSelection.activeBiomeKey(ctx, route)
    local alias = ROUTE_BIOME_SELECTION[route and route.key]
    local stored = alias and readData(ctx, alias) or nil
    if contains(route and route.biomeKeys, stored) then
        return stored
    end
    return route and route.biomeKeys and route.biomeKeys[1] or nil
end

function routeSelection.setActiveRoute(ctx, routeKey)
    return writeData(ctx, "SelectedRoute", routeKey)
end

function routeSelection.setActiveBiome(ctx, routeKey, biomeKey)
    local alias = ROUTE_BIOME_SELECTION[routeKey]
    if alias ~= nil then
        return writeData(ctx, alias, biomeKey)
    end
    return false
end

return routeSelection
