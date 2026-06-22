local rewardSystem = {}

local function rewardValueStatesForControl(instance, surfaceControl, rewardFields, sourceContext)
    if instance.routeContext ~= nil and instance.routeContext.rewardValueStates ~= nil then
        return instance.routeContext:rewardValueStates(
            instance.routeKey,
            instance.biomeKey,
            sourceContext and sourceContext.rowIndex,
            sourceContext and sourceContext.address,
            surfaceControl and surfaceControl.alias,
            surfaceControl,
            rewardFields,
            sourceContext
        )
    end
    return nil
end

local function routeValueStatesForControl(instance)
    if instance.routeContext == nil or instance.routeContext.rewardValueStates == nil then
        return nil
    end
    if instance.rewardValueStatesForControl == nil then
        instance.rewardValueStatesForControl = function(surfaceControl, rewardFields, sourceContext)
            return rewardValueStatesForControl(instance, surfaceControl, rewardFields, sourceContext)
        end
    end
    return instance.rewardValueStatesForControl
end

function rewardSystem.create(opts)
    opts = opts or {}

    local storage = import("mods/rewards/storage.lua")
    local dropdownValues = opts.dropdownValues or import("mods/ui/dropdown_values.lua")
    local surfaceRegistry = import("mods/rewards/surfaces/registry.lua").create(
        opts.definitions or import("mods/rewards/declarations/definitions.lua")
    )
    local runtime = import("mods/rewards/runtime.lua", nil, {
        catalog = surfaceRegistry,
    })
    local ui = import("mods/rewards/ui.lua", nil, {
        runtime = runtime,
        dropdownValues = dropdownValues,
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
        routeValueStatesForControl = routeValueStatesForControl,
    }
end

return rewardSystem
