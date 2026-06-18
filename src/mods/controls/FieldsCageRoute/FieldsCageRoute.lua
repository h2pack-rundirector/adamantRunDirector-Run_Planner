local deps = ...
local data = import("mods/controls/FieldsCageRoute/data.lua", nil, deps.route)
local runtime = import("mods/controls/FieldsCageRoute/runtime.lua", nil, {
    data = data,
    common = deps.route.common,
    rewardRuntime = deps.rewards.runtime,
    rewardOfferPolicies = deps.route.rewardOfferPolicies,
    rewardOfferRules = deps.route.rewardOfferRules,
})
local ui = import("mods/controls/FieldsCageRoute/ui.lua", nil, {
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
