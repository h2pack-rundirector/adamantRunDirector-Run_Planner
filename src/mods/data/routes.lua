local routes = {}

local ROUTES = {
    {
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H", "I" },
    },
    {
        key = "Surface",
        label = "Surface",
        biomes = { "N", "O", "P", "Q" },
    },
}

local function copyList(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

local function copyRoute(route)
    return {
        key = route.key,
        label = route.label,
        biomes = copyList(route.biomes),
    }
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        lookup[item.key] = item
    end
    return lookup
end

function routes.load()
    local ordered = {}
    for _, route in ipairs(ROUTES) do
        ordered[#ordered + 1] = copyRoute(route)
    end
    return {
        ordered = ordered,
        lookup = indexByKey(ordered),
    }
end

return routes
