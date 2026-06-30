local routeFactory = {}

function routeFactory.create(opts)
    opts = opts or {}

    local rewards = opts.rewards

    local routeHorizon = import("mods/route/run_context/horizon.lua")
    local controlForm = import("mods/controls/form.lua", nil, {
        rewards = rewards,
        valueStates = import("mods/ui/value_states.lua"),
    })
    local historySystem = import("mods/route/history/assembly.lua").create({
        rewardDomain = rewards.rewardDomain,
        selectedLegalityRules = rewards.selectedLegalityRules,
    })
    local route = {
        controlForm = controlForm,
        rewards = rewards,
        historySystem = historySystem,
    }
    route.runContext = import("mods/route/run_context.lua", nil, {
        controls = import("mods/route/run_context/controls.lua"),
        historySystem = historySystem,
        horizon = routeHorizon,
    })
    return route
end

return routeFactory
