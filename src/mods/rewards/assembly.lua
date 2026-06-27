local assembly = {}

local function createRewardDomain(godData, primitives, bagDefinitions, shopDefinitions)
    return {
        primitives = primitives,
        godLoot = godData.godLootNames(),
        rewardBags = bagDefinitions.rewardBags,
        rewardStores = bagDefinitions.rewardStores,
        shopOptionSets = shopDefinitions.shopOptionSets,
        shops = shopDefinitions.shops,
    }
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
    local primitives = opts.primitives or import("mods/rewards/declarations/primitives.lua")
    local bagDefinitions = opts.bagDefinitions or import("mods/rewards/declarations/bags.lua")
    local shopDefinitions = opts.shopDefinitions or import("mods/rewards/declarations/shops.lua")
    local rewardDomain = opts.rewardDomain or createRewardDomain(opts.godData, primitives, bagDefinitions, shopDefinitions)
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
        rewardDomain = rewardDomain,
    }
end

return assembly
