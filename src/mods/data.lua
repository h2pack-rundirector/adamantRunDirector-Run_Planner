local data = {}

function data.loadControlTemplates(route, templateDeps)
    return import("mods/controls/templates.lua", nil, {
        route = route,
        rewards = route.rewards,
        godData = templateDeps.godData,
        decorations = import("mods/ui/decorations.lua"),
    })
end

function data.loadBiomes(catalogDeps)
    return import("mods/biomes/catalog.lua").load(catalogDeps)
end

function data.loadRoutes()
    return import("mods/data/routes.lua").load()
end

function data.loadNpcs()
    return import("mods/data/npcs.lua")
end

function data.loadFeatures()
    return import("mods/data/features.lua")
end

function data.loadCatalog(catalogDeps)
    return data.loadBiomes(catalogDeps)
end

return data
