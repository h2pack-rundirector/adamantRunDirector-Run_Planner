local deps = ...
local routeContext = deps.routeContext
local executionPlan = deps.executionPlan
local runState = deps.runState

local routePlan = {}

local CACHE_NAME = "RoutePlan"
local REASON_DREAM_DIVE = "dream_dive_deferred"
local REASON_INVALID_SNAPSHOT = "invalid_route_snapshot"
local REASON_MODULE_DISABLED = "module_disabled"
local REASON_UNKNOWN_ROUTE = "unknown_route"

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function copyInto(target, source)
    clearMap(target)
    for key, value in pairs(source or {}) do
        target[key] = value
    end
    return target
end

local function inactivePlan(reason, routeKey, snapshot)
    return {
        active = false,
        valid = false,
        reason = reason,
        routeKey = routeKey,
        invalidRows = snapshot and snapshot.invalidRows or nil,
    }
end

local function activePlan(routeKey, plan)
    return {
        active = true,
        valid = true,
        reason = nil,
        routeKey = routeKey,
        executionPlan = plan,
        invalidRows = nil,
    }
end

local function controlResolver(runtime)
    return function(controlName)
        if runtime == nil or runtime.controls == nil or runtime.controls.get == nil then
            return nil
        end
        return runtime.controls.get(controlName)
    end
end

local function buildContext(catalog, runtime)
    return routeContext.create({
        routes = catalog.routes,
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        features = catalog.features,
        controlResolver = controlResolver(runtime),
    })
end

local function routeLayers(context, routeKey)
    return {
        rooms = true,
        rewards = context:isLayerConfigured(routeKey, "rewards") ~= false,
        npcs = context:isLayerConfigured(routeKey, "npcs") ~= false,
        features = context:isLayerConfigured(routeKey, "features") ~= false,
    }
end

function routePlan.cacheName()
    return CACHE_NAME
end

function routePlan.get(runtime)
    local currentRunCache = runtime
        and runtime.data
        and runtime.data.cache
        and runtime.data.cache.currentRun
        or nil
    if currentRunCache == nil or currentRunCache.get == nil then
        return nil
    end
    return currentRunCache.get(CACHE_NAME)
end

function routePlan.defineCache(moduleRef)
    moduleRef.cache.define({
        [CACHE_NAME] = {
            domain = "currentRun",
            key = "run",
            factory = function()
                return inactivePlan(REASON_UNKNOWN_ROUTE)
            end,
        },
    })
end

function routePlan.build(catalog, runtime, currentRun, args)
    if runState.isDreamRun(currentRun) then
        return inactivePlan(REASON_DREAM_DIVE)
    end

    local route = runState.routeForBiome(catalog, runState.startingBiome(currentRun, args))
    if route == nil then
        return inactivePlan(REASON_UNKNOWN_ROUTE)
    end

    local context = buildContext(catalog, runtime)
    context:attachControls()
    local snapshot = context:overview(route.key)
    if snapshot == nil or snapshot.valid ~= true then
        return inactivePlan(REASON_INVALID_SNAPSHOT, route.key, snapshot)
    end
    return activePlan(route.key, executionPlan.compile(snapshot, {
        layers = routeLayers(context, route.key),
    }))
end

function routePlan.store(runtime, plan)
    local state = routePlan.get(runtime)
    if state == nil then
        return plan
    end
    return copyInto(state, plan)
end

function routePlan.refresh(catalog, runtime, currentRun, args)
    local plan = routePlan.build(catalog, runtime, currentRun, args)
    return routePlan.store(runtime, plan)
end

function routePlan.registerHooks(moduleRef, catalog)
    moduleRef.hooks.wrap("StartNewRun", function(host, runtime, base, prevRun, args)
        local currentRun = base(prevRun, args)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            routePlan.store(runtime, inactivePlan(REASON_MODULE_DISABLED))
            return currentRun
        end

        routePlan.refresh(catalog, runtime, currentRun, args)
        return currentRun
    end)
end

routePlan.REASON_DREAM_DIVE = REASON_DREAM_DIVE
routePlan.REASON_INVALID_SNAPSHOT = REASON_INVALID_SNAPSHOT
routePlan.REASON_MODULE_DISABLED = REASON_MODULE_DISABLED
routePlan.REASON_UNKNOWN_ROUTE = REASON_UNKNOWN_ROUTE

return routePlan
