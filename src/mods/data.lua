local data = {}

function data.loadCatalog()
    return import("mods/declarations/loader.lua").load()
end

return data
