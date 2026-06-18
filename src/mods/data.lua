local data = {}

data.PLAN_MODE_VALUES = { "Prefer", "Strict" }

function data.loadControlTemplates(importer)
    importer = importer or import
    return importer("mods/controls/templates.lua")
end

function data.loadBiomes(importer)
    importer = importer or import
    return importer("mods/data/biomes.lua").load(importer)
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

function data.buildStorage()
    return {
        { type = "bool", alias = "RoomRoutingEnabled", default = false },
        { type = "bool", alias = "RewardRoutingEnabled", default = false },
        { type = "string", alias = "PlanMode", default = "Prefer", maxLen = 16 },
    }
end

return data
