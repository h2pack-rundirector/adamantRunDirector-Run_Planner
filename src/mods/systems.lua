local systems = {}

local function createUi(opts, services)
    local ui = opts.ui or import("mods/ui.lua")
    if type(ui.create) == "function" then
        return ui.create(services)
    end
    return ui
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
        ui = createUi(opts, {
            data = data,
            catalog = catalog,
            pipeline = opts.pipeline,
            candidateProvider = opts.candidateProvider,
        }),
    }
end

return systems
