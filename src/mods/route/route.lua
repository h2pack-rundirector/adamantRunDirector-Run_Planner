local routeFactory = {}

function routeFactory.create(opts)
    opts = opts or {}

    local rewards = opts.rewards

    local routeTimeline = import("mods/route/timeline.lua")
    local routePosition = import("mods/route/position.lua")
    local invalidLocations = import("mods/route/invalid_locations.lua")
    local controlForm = import("mods/controls/form.lua", nil, {
        rewards = rewards,
        valueStates = import("mods/route/value_states.lua"),
    })
    local historySystem = import("mods/route/history/assembly.lua").create({
        rewardDomain = rewards.rewardDomain,
        selectedLegalityRules = rewards.selectedLegalityRules,
    })
    local route = {
        timeline = routeTimeline,
        controlForm = controlForm,
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
