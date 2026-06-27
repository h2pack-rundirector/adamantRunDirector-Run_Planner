local deps = ...
local logic = {}

local catalog = deps.catalog
local routePlan = deps.routePlan
local roomRouting = deps.roomRouting
local rewardRouting = deps.rewardRouting
local npcRouting = deps.npcRouting
local featureRouting = deps.featureRouting
local liveGameValidator = deps.liveGameValidator
local rewards = deps.rewards

local function debugModeEnabled(runtime)
    return runtime.data.read("DebugMode") == true
end

local function registerLiveValidation(moduleRef)
    moduleRef.onActivate(function(host, runtime)
        if debugModeEnabled(runtime) then
            liveGameValidator.run(catalog, {
                host = host,
                rewardDomain = rewards.rewardDomain,
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
