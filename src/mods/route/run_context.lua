local deps = ... or {}
local routeControls = deps.controls
local routeTargets = deps.targets
local routeRewards = deps.rewards
if routeControls == nil then
    error("run_context requires route controls")
end
if routeTargets == nil then
    error("run_context requires route targets")
end
if routeRewards == nil then
    error("run_context requires route rewards")
end

local runContext = {}
local EMPTY_LIST = {}

local routeControlName = routeControls.routeControlName
local routeGlobalControlName = routeControls.routeGlobalControlName
local routeNpcControlName = routeControls.routeNpcControlName
local routeFeatureControlName = routeControls.routeFeatureControlName
local buildRouteInfo = routeControls.buildRouteInfo
local buildRouteFeatureKeysByRoute = routeControls.buildRouteFeatureKeysByRoute
local routeFeatureKeys = routeControls.routeFeatureKeys

local function biomeLabel(context, biomeKey)
    local biome = context and context.biomeLookup and context.biomeLookup[biomeKey] or nil
    return tostring(biome and (biome.label or biome.key) or biomeKey or "Route")
end

local function appendInvalidRow(invalidRows, invalidRow, extras)
    local copied = {}
    for key, value in pairs(invalidRow or {}) do
        copied[key] = value
    end
    for key, value in pairs(extras or {}) do
        copied[key] = value
    end
    invalidRows[#invalidRows + 1] = copied
    return copied
end

local function routeSnapshotCache(context, routeKey)
    local snapshots = context.snapshotByRoute[routeKey]
    if snapshots == nil then
        snapshots = {}
        context.snapshotByRoute[routeKey] = snapshots
    end
    return snapshots
end

local function routeOverviewState(context, routeKey)
    local state = context.overviewByRoute[routeKey]
    if state == nil then
        state = {
            dirty = true,
            snapshot = nil,
        }
        context.overviewByRoute[routeKey] = state
    end
    return state
end

local function routeNpcTargetsState(context, routeKey)
    local state = context.npcTargetsByRoute[routeKey]
    if state == nil then
        state = {
            dirty = true,
            targets = nil,
        }
        context.npcTargetsByRoute[routeKey] = state
    end
    return state
end

local function routeFeatureTargetsState(context, routeKey)
    local state = context.featureTargetsByRoute[routeKey]
    if state == nil then
        state = {
            dirty = true,
            targets = nil,
        }
        context.featureTargetsByRoute[routeKey] = state
    end
    return state
end

local function controlSnapshot(context, routeKey, biomeKey)
    local snapshots = routeSnapshotCache(context, routeKey)
    if snapshots[biomeKey] ~= nil then
        return snapshots[biomeKey]
    end

    local control = context:controlForBiome(routeKey, biomeKey)
    local snapshot = control ~= nil and control.read ~= nil and control:read("snapshot") or nil
    snapshots[biomeKey] = snapshot or false
    return snapshot
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

function runContext.create(opts)
    opts = opts or {}
    local routeInfoByRoute, routeInfoByBiome = buildRouteInfo(opts.routes)
    local context = {
        routes = opts.routes or {},
        routeInfoByRoute = routeInfoByRoute,
        routeInfoByBiome = routeInfoByBiome,
        biomeLookup = opts.biomes or {},
        npcs = opts.npcs or {},
        features = opts.features or {},
        controlResolver = opts.controlResolver,
        controls = opts.controls,
        routeFeatureKeysByRoute = buildRouteFeatureKeysByRoute(opts.routes, opts.features),
        snapshotByRoute = {},
        overviewByRoute = {},
        npcTargetsByRoute = {},
        featureTargetsByRoute = {},
        rewardLegalityByRoute = {},
        godSourceByRoute = {},
    }
    context.rewardState = routeRewards.create({
        rewardLegality = opts.rewardLegality,
        routeControlName = routeControlName,
    })

    function context:beginPass(controls)
        self.controls = controls or self.controls
        clearMap(self.snapshotByRoute)
    end

    function context:bindControl(control, routeKey)
        if control ~= nil and control.setRouteContext ~= nil then
            control:setRouteContext(self, routeKey)
        end
        return control
    end

    function context:routeInfo(routeKey, biomeKey)
        if biomeKey == nil then
            biomeKey = routeKey
            routeKey = nil
        end

        if routeKey ~= nil and self.routeInfoByRoute[routeKey] ~= nil then
            return self.routeInfoByRoute[routeKey][biomeKey]
        end
        return self.routeInfoByBiome[biomeKey]
    end

    function context:markAllDirty()
        for _, route in ipairs(self.routes.ordered or EMPTY_LIST) do
            routeOverviewState(self, route.key).dirty = true
        end
        clearMap(self.snapshotByRoute)
        clearMap(self.npcTargetsByRoute)
        clearMap(self.featureTargetsByRoute)
        clearMap(self.rewardLegalityByRoute)
    end

    function context:markRoutesForBiome(biomeKey)
        local marked = false
        for routeKey, routeInfos in pairs(self.routeInfoByRoute) do
            if routeInfos[biomeKey] ~= nil then
                routeOverviewState(self, routeKey).dirty = true
                self.snapshotByRoute[routeKey] = nil
                self.npcTargetsByRoute[routeKey] = nil
                self.featureTargetsByRoute[routeKey] = nil
                self.rewardLegalityByRoute[routeKey] = nil
                marked = true
            end
        end
        if not marked then
            self:markAllDirty()
        end
    end

    function context:markDirty(routeKey, biomeKey)
        if routeKey ~= nil then
            routeOverviewState(self, routeKey).dirty = true
            self.snapshotByRoute[routeKey] = nil
            self.npcTargetsByRoute[routeKey] = nil
            self.featureTargetsByRoute[routeKey] = nil
            self.rewardLegalityByRoute[routeKey] = nil
            return
        end
        if biomeKey ~= nil then
            self:markRoutesForBiome(biomeKey)
            return
        end
        self:markAllDirty()
    end

    function context:controlForBiome(routeKey, biomeKey)
        local info = self:routeInfo(routeKey, biomeKey)
        if info == nil then
            return nil
        end
        if self.controlResolver ~= nil then
            return self:bindControl(self.controlResolver(info.controlName, biomeKey, info.route.key), info.route.key)
        end
        if self.controls ~= nil and self.controls.get ~= nil then
            return self:bindControl(self.controls.get(info.controlName), info.route.key)
        end
        return nil
    end

    function context:controlByName(controlName, routeKey)
        local control
        if self.controlResolver ~= nil then
            control = self.controlResolver(controlName, nil, routeKey)
        elseif self.controls ~= nil and self.controls.get ~= nil then
            control = self.controls.get(controlName)
        end
        return self:bindControl(control, routeKey)
    end

    function context:controlSnapshot(routeKey, biomeKey)
        return controlSnapshot(self, routeKey, biomeKey)
    end

    function context:godSourceForRoute(routeKey)
        if self.godSourceByRoute[routeKey] ~= nil then
            return self.godSourceByRoute[routeKey]
        end
        local control = self:controlByName(routeGlobalControlName(routeKey), routeKey)
        if control ~= nil and control.godSourceDrawOpts ~= nil then
            self.godSourceByRoute[routeKey] = control
            return control
        end
        return nil
    end

    function context:isLayerConfigured(routeKey, layer)
        local control = self:controlByName(routeGlobalControlName(routeKey), routeKey)
        if control ~= nil and control.isLayerConfigured ~= nil then
            return control:isLayerConfigured(layer) ~= false
        end
        return true
    end

    function context:attachControls()
        for _, route in ipairs(self.routes.ordered or EMPTY_LIST) do
            self:godSourceForRoute(route.key)
            self:controlByName(routeNpcControlName(route.key), route.key)
            for _, featureKey in ipairs(routeFeatureKeys(self, route)) do
                self:controlByName(routeFeatureControlName(route.key, featureKey), route.key)
            end
            for _, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
                self:controlForBiome(route.key, biomeKey)
            end
        end
    end

    function context:collectPriorGodLoot(routeKey, biomeKey, countedLookup, selections, stopAtCount)
        if type(biomeKey) == "table" then
            stopAtCount = selections
            selections = countedLookup
            countedLookup = biomeKey
            biomeKey = routeKey
            routeKey = nil
        end

        return self.rewardState.collectPriorGodLoot(self, routeKey, biomeKey, countedLookup, selections, stopAtCount)
    end

    function context:npcTargets(routeKey)
        local state = routeNpcTargetsState(self, routeKey)
        if state.dirty or state.targets == nil then
            if self:isLayerConfigured(routeKey, "npcs") then
                state.targets = routeTargets.buildNpcTargets(self, routeKey)
            else
                state.targets = routeTargets.emptyNpcTargets()
            end
            state.dirty = false
        end
        return state.targets
    end

    function context:npcTargetsForSlot(routeKey, npcKey, biomeKey)
        local targets = self:npcTargets(routeKey)
        if biomeKey ~= nil then
            return targets.byNpcBiome[npcKey] and targets.byNpcBiome[npcKey][biomeKey] or nil
        end
        return targets.byNpc[npcKey]
    end

    function context:featureTargets(routeKey)
        local state = routeFeatureTargetsState(self, routeKey)
        if state.dirty or state.targets == nil then
            if self:isLayerConfigured(routeKey, "features") then
                state.targets = routeTargets.buildFeatureTargets(self, routeKey)
            else
                state.targets = routeTargets.emptyFeatureTargets()
            end
            state.dirty = false
        end
        return state.targets
    end

    function context:featureTargetsForSlot(routeKey, featureKey, biomeKey)
        local targets = self:featureTargets(routeKey)
        if biomeKey ~= nil then
            return targets.byFeatureBiome[featureKey] and targets.byFeatureBiome[featureKey][biomeKey] or nil
        end
        return targets.byFeature[featureKey]
    end

    function context:rewardLegality(routeKey)
        return self.rewardState.legality(self, routeKey)
    end

    function context:rewardRowValidation(routeKey, biomeKey, rowIndex)
        return self.rewardState.rowValidation(self, routeKey, biomeKey, rowIndex)
    end

    function context:snapshot(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local snapshots = {}
        local invalidRows = {}
        local npcSnapshot
        local featureSnapshots = {}
        if route == nil then
            return {
                routeKey = routeKey,
                valid = false,
                disabled = true,
                invalidRows = {
                    { code = "unknown_route", message = "Unknown route: " .. tostring(routeKey) },
                },
                biomes = snapshots,
            }
        end

        local previousSnapshotBuilding = self.snapshotBuilding
        self.snapshotBuilding = true
        for _, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
            local snapshot = controlSnapshot(self, route.key, biomeKey)
            snapshots[#snapshots + 1] = snapshot
            if not snapshot then
                invalidRows[#invalidRows + 1] = {
                    biomeKey = biomeKey,
                    controlName = routeControlName(biomeKey),
                    locationLabel = biomeLabel(self, biomeKey),
                    code = "missing_control",
                    message = "Missing route control: " .. tostring(biomeKey),
                }
            else
                for _, invalidRow in ipairs(snapshot.invalidRows or EMPTY_LIST) do
                    appendInvalidRow(invalidRows, invalidRow, {
                        biomeKey = biomeKey,
                        controlName = snapshot.controlName,
                    })
                end
            end
        end
        self.snapshotBuilding = previousSnapshotBuilding

        if self:isLayerConfigured(route.key, "rewards") then
            for _, invalidRow in ipairs(self:rewardLegality(route.key).invalidRows or EMPTY_LIST) do
                invalidRows[#invalidRows + 1] = invalidRow
            end
        end

        if self:isLayerConfigured(route.key, "npcs") then
            local npcControl = self:controlByName(routeNpcControlName(route.key), route.key)
            if npcControl ~= nil and npcControl.read ~= nil then
                npcSnapshot = npcControl:read("snapshot")
                for _, invalidRow in ipairs(npcSnapshot and npcSnapshot.invalidRows or EMPTY_LIST) do
                    appendInvalidRow(invalidRows, invalidRow, {
                        controlName = npcSnapshot.controlName,
                    })
                end
            end
        end

        if self:isLayerConfigured(route.key, "features") then
            for _, featureKey in ipairs(routeFeatureKeys(self, route)) do
                local featureControl = self:controlByName(routeFeatureControlName(route.key, featureKey), route.key)
                if featureControl ~= nil and featureControl.read ~= nil then
                    local featureSnapshot = featureControl:read("snapshot")
                    featureSnapshots[#featureSnapshots + 1] = featureSnapshot
                    for _, invalidRow in ipairs(featureSnapshot and featureSnapshot.invalidRows or EMPTY_LIST) do
                        appendInvalidRow(invalidRows, invalidRow, {
                            controlName = featureSnapshot.controlName,
                        })
                    end
                end
            end
        end

        return {
            routeKey = route.key,
            label = route.label,
            valid = invalidRows[1] == nil,
            disabled = invalidRows[1] ~= nil,
            invalidRows = invalidRows,
            biomes = snapshots,
            npcs = npcSnapshot,
            features = featureSnapshots,
        }
    end

    function context:overview(routeKey)
        local state = routeOverviewState(self, routeKey)
        if state.dirty or state.snapshot == nil then
            state.snapshot = self:snapshot(routeKey)
            state.dirty = false
        end
        return state.snapshot
    end

    return context
end

runContext.collectRewardGodLoot = routeRewards.collectRewardGodLoot
runContext.collectRowGodLoot = routeRewards.collectRowGodLoot

return runContext
