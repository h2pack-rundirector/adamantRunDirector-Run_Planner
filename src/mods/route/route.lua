local routeFactory = {}

function routeFactory.create(opts)
    opts = opts or {}

    local rewards = opts.rewards

    local routeTimeline = import("mods/route/timeline.lua")
    local routeEvents = import("mods/route/events.lua")
    local routeHistory = import("mods/route/history.lua", nil, {
        events = routeEvents,
    })
    local routeQuery = import("mods/route/query.lua", nil, {
        events = routeEvents,
        history = routeHistory,
    })
    local routePosition = import("mods/route/position.lua")
    local invalidLocations = import("mods/route/invalid_locations.lua")
    local routeMarkers = import("mods/route/markers.lua")
    local controlRequirements = import("mods/route/control_requirements.lua", nil, {
        valueStates = import("mods/route/value_states.lua"),
    })
    local rows = import("mods/route/rows.lua", nil, {
        rewards = rewards,
        timeline = routeTimeline,
        controlRequirements = controlRequirements,
        query = routeQuery,
    })
    local historySystem = import("mods/route/history/assembly.lua").create({
        rewardDomain = rewards.rewardDomain,
        selectedLegalityRules = rewards.selectedLegalityRules,
    })
    local route = {
        common = rows.common,
        availability = rows.availability,
        readCache = rows.readCache,
        valueStates = rows.valueStates,
        rowEngine = rows.engine,
        timeline = routeTimeline,
        query = routeQuery,
        events = routeEvents,
        history = routeHistory,
        markers = routeMarkers,
        controlRequirements = controlRequirements,
        invalidLocations = invalidLocations,
        rewards = rewards,
        historySystem = historySystem,
    }
    route.runContext = import("mods/route/run_context.lua", nil, {
        controls = import("mods/route/run_context/controls.lua"),
        historySystem = historySystem,
        position = routePosition,
    })
    return route
end

return routeFactory
