local deps = ...
local logic = {}

local catalog = deps.catalog
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

function logic.attach(moduleRef)
    registerLiveValidation(moduleRef)
end

return logic
