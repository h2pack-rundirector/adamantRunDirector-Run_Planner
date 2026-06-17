local data = import("mods/controls/FixedLinearRoute/data.lua")
local rewardCatalogFactory = import("mods/rewards/catalog.lua")
local rewardSurfaces = import("mods/rewards/surfaces.lua")
local rewardCatalog = rewardCatalogFactory.create(rewardSurfaces)
local rewardRuntime = import("mods/rewards/runtime.lua", nil, {
    catalog = rewardCatalog,
})
local runtime = import("mods/controls/FixedLinearRoute/runtime.lua", nil, {
    data = data,
    rewardRuntime = rewardRuntime,
})
local rewardUi = import("mods/rewards/ui.lua", nil, {
    runtime = rewardRuntime,
})
local ui = import("mods/controls/FixedLinearRoute/ui.lua", nil, {
    data = data,
    rewardRuntime = rewardRuntime,
    rewardUi = rewardUi,
    runtime = runtime,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    views = ui.views,
}
