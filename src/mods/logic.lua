local deps = ...
local logic = {}

local catalog = deps and deps.catalog or nil
local routePlan = deps and deps.routePlan or nil
local roomRouting = deps and deps.roomRouting or nil
local rewardRouting = deps and deps.rewardRouting or nil
local npcRouting = deps and deps.npcRouting or nil
local featureRouting = deps and deps.featureRouting or nil
local liveGameValidator = deps and deps.liveGameValidator or nil

local function debugModeEnabled(runtime)
    return runtime.data.read("DebugMode") == true
end

local function registerLiveValidation(moduleRef)
    moduleRef.onActivate(function(host, runtime)
        if debugModeEnabled(runtime) then
            liveGameValidator.run(catalog, {
                host = host,
            })
        end
    end)
end

function logic.defineCache(moduleRef)
    routePlan.defineCache(moduleRef)
end

function logic.registerHooks(moduleRef)
    routePlan.registerHooks(moduleRef, catalog)
    roomRouting.registerHooks(moduleRef, catalog)
    rewardRouting.registerHooks(moduleRef, catalog)
    npcRouting.registerHooks(moduleRef, catalog)
    featureRouting.registerHooks(moduleRef, catalog)
end

function logic.attach(moduleRef)
    logic.defineCache(moduleRef)
    logic.registerHooks(moduleRef)
    registerLiveValidation(moduleRef)
end

return logic
