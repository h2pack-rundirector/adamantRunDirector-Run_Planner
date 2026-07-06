local data = {}

function data.loadCatalog()
    return {
        ordered = {},
        lookup = {},
        routes = {
            ordered = {},
            lookup = {},
        },
    }
end

return data
