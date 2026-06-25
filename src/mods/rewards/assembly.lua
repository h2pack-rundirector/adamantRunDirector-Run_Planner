local assembly = {}

local function createDefinitions(godData)
    return import("mods/rewards/declarations/definitions.lua")({
        godData = godData,
    })
end

local function createConditions(godData)
    return import("mods/rewards/declarations/conditions.lua")({
        godData = godData,
    })
end

local function createCatalogSurfaces(routeRules, constraints)
    return import("mods/rewards/declarations/surfaces.lua")({
        routeRules = routeRules,
        rewardConstraints = constraints,
    })
end

function assembly.create(opts)
    opts = opts or {}

    local constraints = opts.constraints or import("mods/rewards/declarations/constraints.lua")
    local definitions = opts.definitions or createDefinitions(opts.godData)
    local conditions = opts.conditions
    if conditions == nil and opts.godData ~= nil then
        conditions = createConditions(opts.godData)
    end

    local catalogSurfaces = opts.catalogSurfaces
    if catalogSurfaces == nil and opts.routeRules ~= nil then
        catalogSurfaces = createCatalogSurfaces(opts.routeRules, constraints)
    end

    return {
        catalogSurfaces = catalogSurfaces,
        conditions = conditions,
        definitions = definitions,
    }
end

return assembly
