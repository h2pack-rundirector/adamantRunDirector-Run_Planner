local deps = ...
local data = import("mods/controls/HubPylonRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/HubPylonRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewardRuntime = deps.rewards.runtime,
    rewardItems = deps.route.rewardItems,
    rewardOfferPolicies = deps.route.rewardOfferPolicies,
    rewardOfferRules = deps.route.rewardOfferRules,
    invalidLocations = deps.route.invalidLocations,
})
local ui = import("mods/controls/HubPylonRoute/ui.lua", nil, {
    data = data,
    rewardRuntime = deps.rewards.runtime,
    rewardUi = deps.rewards.ui,
    rewardOfferPolicies = deps.route.rewardOfferPolicies,
    rewardOfferRules = deps.route.rewardOfferRules,
    routeStatusUi = deps.routeStatusUi,
    runtime = runtime,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
