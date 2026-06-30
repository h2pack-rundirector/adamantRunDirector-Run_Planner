local deps = ... or {}
local routeControls = deps.controls
local routePosition = deps.position
local historySystem = deps.historySystem

local function load(path)
    if _G.import ~= nil then
        return _G.import(path)
    end
    return dofile("src/" .. path)
end

local state = load("mods/route/run_context/state.lua")
local scope = load("mods/route/run_context/scope.lua")
local feedback = load("mods/route/run_context/feedback.lua")
local overview = load("mods/route/run_context/overview.lua")

local runContext = {}
local EMPTY_LIST = {}

function runContext.create(opts)
    opts = opts or {}
    local routeInfoByRoute, routeInfoByBiome = routeControls.buildRouteInfo(opts.routes)
    local context = {
        routes = opts.routes or {},
        routeInfoByRoute = routeInfoByRoute,
        routeInfoByBiome = routeInfoByBiome,
        biomeLookup = opts.biomes or {},
        controlResolver = opts.controlResolver,
        controls = opts.controls,
        completionByRoute = {},
        overviewByRoute = {},
        historyFeedbackByRoute = {},
        godSourceByRoute = {},
        generationByRoute = {},
    }

    state.install(context, {
        EMPTY_LIST = EMPTY_LIST,
    })
    scope.install(context, {
        EMPTY_LIST = EMPTY_LIST,
        routeGlobalControlName = routeControls.routeGlobalControlName,
    })
    feedback.install(context, {
        EMPTY_LIST = EMPTY_LIST,
        historySystem = historySystem,
        state = state,
    })
    overview.install(context, {
        EMPTY_LIST = EMPTY_LIST,
        position = routePosition,
        routeControlName = routeControls.routeControlName,
        state = state,
    })

    return context
end

return runContext
