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

local function buildOrDefault(explicit, builder)
    if explicit ~= nil then
        return explicit
    end
    if type(builder) == "function" then
        return builder()
    end
    return {}
end

function systems.create(opts)
    opts = opts or {}

    local data = opts.data or import("mods/data.lua")
    local catalog = opts.catalog or data.loadCatalog()
    local storage = buildOrDefault(opts.storage, data.buildStorage)
    local controlTemplates = buildOrDefault(opts.controlTemplates, data.buildControlTemplates)
    local routeControls = buildOrDefault(opts.routeControls, data.buildControls)

    return {
        data = data,
        catalog = catalog,
        storage = storage,
        controlTemplates = controlTemplates,
        routeControls = routeControls,
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
