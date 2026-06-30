local routeFactory = {}

function routeFactory.create(opts)
    opts = opts or {}

    local rewards = opts.rewards

    local routeTimeline = import("mods/route/timeline.lua")
    local routePosition = import("mods/route/position.lua")
    local invalidLocations = import("mods/route/invalid_locations.lua")
    local controlRequirements = import("mods/route/control_requirements.lua", nil, {
        valueStates = import("mods/route/value_states.lua"),
    })
    local rows = import("mods/route/rows.lua", nil, {
        rewards = rewards,
        timeline = routeTimeline,
        controlRequirements = controlRequirements,
    })
    local historySystem = import("mods/route/history/assembly.lua").create({
        rewardDomain = rewards.rewardDomain,
        selectedLegalityRules = rewards.selectedLegalityRules,
    })
    local route = {
        common = rows.common,
        readCache = rows.readCache,
        valueStates = rows.valueStates,
        rowEngine = rows.engine,
        timeline = routeTimeline,
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
