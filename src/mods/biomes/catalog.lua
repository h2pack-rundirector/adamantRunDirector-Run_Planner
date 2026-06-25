local biomes = {}

function biomes.load(deps)
    local gods = deps.godData
    local routeRules = deps.routeRules
    local rewardSurfaces = deps.rewards.catalogSurfaces
    local npcs = import("mods/data/npcs.lua")
    local features = import("mods/data/features.lua")
    local routes = import("mods/data/routes.lua").load()
    local assembled = import("mods/biomes/assembly.lua").load({
        routeRules = routeRules,
        rewardSurfaces = rewardSurfaces,
    })

    return {
        ordered = assembled.ordered,
        lookup = assembled.lookup,
        routes = routes,
        gods = gods.olympian(),
        npcs = npcs,
        features = features,
        rewardTypes = rewardSurfaces.rewardTypeMetadata(),
    }
end

return biomes
