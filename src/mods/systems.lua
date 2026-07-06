local systems = {}

local function createUi(opts)
    return opts.ui or import("mods/ui.lua")
end

local function createLogic(opts)
    return opts.logic or import("mods/logic.lua")
end

function systems.create(opts)
    opts = opts or {}

    local data = opts.data or import("mods/data.lua")
    local catalog = opts.catalog or data.loadCatalog()

    return {
        data = data,
        catalog = catalog,
        controlTemplates = opts.controlTemplates or {},
        routeControls = opts.routeControls or {},
        routeControlTabs = opts.routeControlTabs or {},
        logic = createLogic(opts),
        ui = createUi(opts),
    }
end

return systems
