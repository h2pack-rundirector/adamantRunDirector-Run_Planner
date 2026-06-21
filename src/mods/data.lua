local data = {}

function data.loadControlTemplates(route, importer)
    importer = importer or import
    return importer("mods/controls/templates.lua", nil, {
        route = route,
        rewards = route.rewards,
    })
end

function data.loadBiomes(importer)
    importer = importer or import
    return importer("mods/biomes/catalog.lua").load(importer)
end

function data.loadRoutes(importer)
    importer = importer or import
    return importer("mods/data/routes.lua").load()
end

function data.loadNpcs(importer)
    importer = importer or import
    return importer("mods/npcs/definitions.lua")
end

function data.loadFeatures(importer)
    importer = importer or import
    return importer("mods/features/definitions.lua")
end

function data.loadCatalog(importer)
    return data.loadBiomes(importer)
end

function data.buildControls(catalog, importer)
    importer = importer or import
    return importer("mods/data/controls.lua").build(catalog)
end

function data.routeControlNames(catalog, importer)
    importer = importer or import
    return importer("mods/data/controls.lua").routeControlNames(catalog)
end

function data.routeControlTabs(catalog, importer)
    importer = importer or import
    return importer("mods/data/controls.lua").routeControlTabs(catalog)
end

return data
