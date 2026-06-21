local rewardSystem = {}

function rewardSystem.create(opts)
    opts = opts or {}

    local storage = import("mods/rewards/storage.lua")
    local surfaceRegistry = import("mods/rewards/surfaces/registry.lua").create(
        opts.definitions or import("mods/rewards/declarations/definitions.lua")
    )
    local runtime = import("mods/rewards/runtime.lua", nil, {
        catalog = surfaceRegistry,
    })
    local ui = import("mods/rewards/ui.lua", nil, {
        runtime = runtime,
    })

    return {
        SLOT_COUNT = storage.SLOT_COUNT,
        buildRows = storage.buildRows,
        fields = storage.fields,
        isAlias = storage.isAlias,
        lootAlias = storage.lootAlias,
        readRewardLoot = storage.readRewardLoot,
        readRewards = storage.readRewards,
        resetRows = storage.resetRows,
        rewardAlias = storage.rewardAlias,

        draw = ui.draw,
        hasControls = runtime.hasControls,
        snapshot = runtime.snapshot,
        surfaceFor = runtime.surfaceFor,
        validate = runtime.validate,

        godLootOptions = surfaceRegistry.godLootOptions,
    }
end

return rewardSystem
