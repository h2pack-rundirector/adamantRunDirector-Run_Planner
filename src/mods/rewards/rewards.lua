local rewardSystem = {}

local function historyValueStates(instance, surfaceControl, _rewardFields, sourceContext)
    if instance.routeContext ~= nil and instance.routeContext.historyValueStates ~= nil then
        local rewardAddress = surfaceControl and surfaceControl.rewardAddress
            or sourceContext and sourceContext.address
        return instance.routeContext:historyValueStates(
            instance.routeKey,
            instance.biomeKey,
            sourceContext and sourceContext.rowIndex,
            surfaceControl and surfaceControl.alias,
            rewardAddress
        )
    end
    return nil
end

local function historyValueStatesForControl(instance)
    if instance.routeContext == nil or instance.routeContext.historyValueStates == nil then
        return nil
    end
    if instance.historyValueStatesForControl == nil then
        instance.historyValueStatesForControl = function(surfaceControl, rewardFields, sourceContext)
            return historyValueStates(instance, surfaceControl, rewardFields, sourceContext)
        end
    end
    return instance.historyValueStatesForControl
end

function rewardSystem.create(opts)
    opts = opts or {}

    local storage = import("mods/rewards/storage.lua")
    local decorations = opts.decorations
    local parts = import("mods/rewards/assembly.lua").create(opts)
    local surfaceRegistry = import("mods/rewards/surfaces/registry.lua").create(
        parts.rewardDomain
    )
    local runtime = import("mods/rewards/runtime.lua", nil, {
        catalog = surfaceRegistry,
    })
    local ui = import("mods/rewards/ui.lua", nil, {
        runtime = runtime,
        decorations = decorations,
    })

    return {
        SLOT_COUNT = storage.SLOT_COUNT,
        PREBOSS_BRANCH_ALIAS = storage.PREBOSS_BRANCH_ALIAS,
        buildRows = storage.buildRows,
        fields = storage.fields,
        isAlias = storage.isAlias,
        lootAlias = storage.lootAlias,
        readRewardLoot = storage.readRewardLoot,
        readRewardStates = storage.readRewardStates,
        readRewards = storage.readRewards,
        resetRows = storage.resetRows,
        rewardAlias = storage.rewardAlias,
        stateAlias = storage.stateAlias,

        catalogSurfaces = parts.catalogSurfaces,
        rewardDomain = parts.rewardDomain,
        selectedLegalityRules = parts.selectedLegalityRules,

        draw = ui.draw,
        hasControls = runtime.hasControls,
        hasDisplay = runtime.hasDisplay,
        snapshot = runtime.snapshot,
        surfaceFor = runtime.surfaceFor,

        godLootOptions = surfaceRegistry.godLootOptions,
        historyValueStatesForControl = historyValueStatesForControl,
    }
end

return rewardSystem
