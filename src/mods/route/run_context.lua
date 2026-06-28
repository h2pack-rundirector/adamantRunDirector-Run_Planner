local deps = ... or {}
local routeControls = deps.controls
local routeTargets = deps.targets
local routeRewards = deps.rewards
local routePosition = deps.position

local runContext = {}
local EMPTY_LIST = {}

local routeControlName = routeControls.routeControlName
local routeGlobalControlName = routeControls.routeGlobalControlName
local routeNpcControlName = routeControls.routeNpcControlName
local routeFeatureControlName = routeControls.routeFeatureControlName
local buildRouteInfo = routeControls.buildRouteInfo
local buildRouteFeatureKeysByRoute = routeControls.buildRouteFeatureKeysByRoute
local routeFeatureKeys = routeControls.routeFeatureKeys

local LAYER_ORDER = {
    route = 1,
    npcs = 2,
    features = 3,
}

local function biomeLabel(context, biomeKey)
    local biome = context and context.biomeLookup and context.biomeLookup[biomeKey] or nil
    return tostring(biome and (biome.label or biome.key) or biomeKey or "Route")
end

local function copyInvalidRow(invalidRow, extras)
    local copied = {}
    for key, value in pairs(invalidRow or {}) do
        copied[key] = value
    end
    for key, value in pairs(extras or {}) do
        copied[key] = value
    end
    return copied
end

local function appendInvalidRow(invalidRows, invalidRow, extras)
    local copied = copyInvalidRow(invalidRow, extras)
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

local function bumpRouteGeneration(context, routeKey)
    context.generationByRoute[routeKey] = (context.generationByRoute[routeKey] or 0) + 1
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

local function missingControlInvalid(context, routeBiomeIndex, biomeKey)
    return {
        biomeKey = biomeKey,
        routeBiomeIndex = routeBiomeIndex,
        controlName = routeControlName(biomeKey),
        locationLabel = biomeLabel(context, biomeKey),
        code = "missing_control",
        message = "Missing route control: " .. tostring(biomeKey),
    }
end

local function firstLocalInvalid(snapshot, biomeKey, routeBiomeIndex)
    local invalid = snapshot and snapshot.invalidRows and snapshot.invalidRows[1] or nil
    if invalid == nil then
        return nil
    end
    return copyInvalidRow(invalid, {
        biomeKey = biomeKey,
        routeBiomeIndex = routeBiomeIndex,
        controlName = snapshot.controlName,
    })
end

local function appendFirstInvalid(invalidRows, invalid)
    if invalid ~= nil and invalidRows[1] == nil then
        invalidRows[1] = invalid
    end
end

local function appendInvalidRows(invalidRows, source)
    for _, invalid in ipairs(source or EMPTY_LIST) do
        appendInvalidRow(invalidRows, invalid)
    end
end

local function rewardBoundaryForInvalid(invalid)
    if invalid == nil then
        return nil
    end
    if invalid.routeOrdinal ~= nil then
        return {
            stopBeforeRouteOrdinal = invalid.routeOrdinal,
        }
    end
    if invalid.routeBiomeIndex ~= nil then
        return {
            stopBeforeBiomeIndex = invalid.routeBiomeIndex,
        }
    end
    return nil
end

local function featureControlIndex(context, route, controlName)
    for index, featureKey in ipairs(routeFeatureKeys(context, route)) do
        if controlName == routeFeatureControlName(route.key, featureKey) then
            return index
        end
    end
    return nil
end

local function featureKeyForControl(context, route, controlName)
    for _, featureKey in ipairs(routeFeatureKeys(context, route)) do
        if controlName == routeFeatureControlName(route.key, featureKey) then
            return featureKey
        end
    end
    return nil
end

local function featureDefinitionForKey(context, route, featureKey)
    for _, routeFeatureKey in ipairs(routeFeatureKeys(context, route)) do
        local feature = context.features.byKey and context.features.byKey[routeFeatureKey] or nil
        if feature ~= nil and (feature.key == featureKey or feature.featureKey == featureKey) then
            return feature
        end
    end
    return nil
end

local function routeBiomeCount(route)
    return #(route and route.biomes or EMPTY_LIST)
end

local function clampBiomeCount(value, route)
    local maxCount = routeBiomeCount(route)
    if maxCount <= 0 then
        return 0
    end
    local count = math.floor(tonumber(value) or maxCount)
    if count < 1 then
        return 1
    end
    if count > maxCount then
        return maxCount
    end
    return count
end

local function biomeKeyForControl(context, routeKey, controlName)
    for biomeKey, info in pairs(context.routeInfoByRoute[routeKey] or {}) do
        if info.controlName == controlName then
            return biomeKey
        end
    end
    return nil
end

local function featureInConfiguredScope(context, routeKey, feature)
    local route = context.routes.lookup and context.routes.lookup[routeKey] or nil
    local configuredCount = context:configuredBiomeCount(routeKey)
    for routeBiomeIndex, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        if routeBiomeIndex > configuredCount then
            break
        end
        if feature and feature.biomes and feature.biomes[biomeKey] then
            return true
        end
    end
    return false
end

local function layerControlIndex(context, route, layer, controlName)
    if layer == "npcs" then
        return controlName == routeNpcControlName(route.key) and 1 or nil
    elseif layer == "features" then
        return featureControlIndex(context, route, controlName)
    end
    return nil
end

local function layerForInvalid(context, route, invalid)
    if invalid.layer ~= nil then
        return invalid.layer
    end
    if invalid.controlName == routeNpcControlName(route.key) then
        return "npcs"
    end
    if featureControlIndex(context, route, invalid.controlName) ~= nil then
        return "features"
    end
    return "route"
end

local function blockingHorizon(context, route, invalid)
    if invalid == nil then
        return nil
    end

    local horizon = copyInvalidRow(invalid, {
        layer = layerForInvalid(context, route, invalid),
        routeKey = route.key,
    })
    if horizon.routeBiomeIndex == nil and horizon.biomeKey ~= nil then
        local info = context:routeInfo(route.key, horizon.biomeKey)
        horizon.routeBiomeIndex = info and info.index or nil
    end
    return horizon
end

local function layerInactive(horizon, layer)
    local horizonOrder = horizon and LAYER_ORDER[horizon.layer] or nil
    local layerOrder = LAYER_ORDER[layer]
    return horizonOrder ~= nil and layerOrder ~= nil and layerOrder > horizonOrder
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
        generationByRoute = {},
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
            bumpRouteGeneration(self, route.key)
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
                bumpRouteGeneration(self, routeKey)
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
            bumpRouteGeneration(self, routeKey)
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

    function context:routeGeneration(routeKey)
        return self.generationByRoute[routeKey] or 0
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

    function context:configuredBiomeCount(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local control = self:controlByName(routeGlobalControlName(routeKey), routeKey)
        local count = control ~= nil
            and control.configuredBiomeCount ~= nil
            and control:configuredBiomeCount()
            or nil
        return clampBiomeCount(count, route)
    end

    function context:isBiomeInConfiguredScope(routeKey, biomeKeyOrIndex)
        if type(biomeKeyOrIndex) == "number" then
            return biomeKeyOrIndex <= self:configuredBiomeCount(routeKey)
        end
        local info = self:routeInfo(routeKey, biomeKeyOrIndex)
        return info ~= nil and info.index <= self:configuredBiomeCount(routeKey)
    end

    function context:configuredRoute(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        if route == nil then
            return nil
        end

        local configuredCount = self:configuredBiomeCount(routeKey)
        if configuredCount >= routeBiomeCount(route) then
            return route
        end

        local biomes = {}
        for index = 1, configuredCount do
            biomes[index] = route.biomes[index]
        end
        return {
            key = route.key,
            label = route.label,
            biomes = biomes,
        }
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

    function context:isFeatureConfigured(routeKey, featureKey)
        if not self:isLayerConfigured(routeKey, "features") then
            return false
        end
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local feature = route ~= nil and featureDefinitionForKey(self, route, featureKey) or nil
        if feature == nil then
            return true
        end
        if not featureInConfiguredScope(self, routeKey, feature) then
            return false
        end
        local control = self:controlByName(routeGlobalControlName(routeKey), routeKey)
        if control ~= nil and control.isFeatureConfigured ~= nil then
            return control:isFeatureConfigured(feature.key) ~= false
        end
        return true
    end

    function context:hasConfiguredFeatures(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        if route == nil or not self:isLayerConfigured(routeKey, "features") then
            return false
        end
        for _, featureKey in ipairs(routeFeatureKeys(self, route)) do
            if self:isFeatureConfigured(routeKey, featureKey) then
                return true
            end
        end
        return false
    end

    function context:isControlConfigured(routeKey, controlName)
        if controlName == routeGlobalControlName(routeKey) then
            return true
        end
        if controlName == routeNpcControlName(routeKey) then
            return self:isLayerConfigured(routeKey, "npcs")
        end
        local biomeKey = biomeKeyForControl(self, routeKey, controlName)
        if biomeKey ~= nil then
            return self:isBiomeInConfiguredScope(routeKey, biomeKey)
        end
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local featureKey = route ~= nil and featureKeyForControl(self, route, controlName) or nil
        if featureKey ~= nil then
            return self:isFeatureConfigured(routeKey, featureKey)
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
        if not self:isFeatureConfigured(routeKey, featureKey) then
            return nil
        end
        local targets = self:featureTargets(routeKey)
        if biomeKey ~= nil then
            return targets.byFeatureBiome[featureKey] and targets.byFeatureBiome[featureKey][biomeKey] or nil
        end
        return targets.byFeature[featureKey]
    end

    function context:rewardLegality(routeKey, rewardOpts)
        return self.rewardState.legality(self, routeKey, rewardOpts)
    end

    function context:rewardRowValidation(routeKey, biomeKey, rowIndex)
        return self.rewardState.rowValidation(self, routeKey, biomeKey, rowIndex)
    end

    function context:rewardValueStates(
        routeKey,
        biomeKey,
        rowIndex,
        rewardAddress,
        controlAlias,
        control,
        fields,
        rewardContext
    )
        return self.rewardState.valueStates(
            self,
            routeKey,
            biomeKey,
            rowIndex,
            rewardAddress,
            controlAlias,
            control,
            fields,
            rewardContext
        )
    end

    function context:snapshot(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local snapshots = {}
        local invalidRows = {}
        local routeLocalInvalid
        local npcSnapshot
        local featureSnapshots = {}
        local layerStatus = {
            route = {
                canDecorate = true,
                evaluated = false,
                valid = nil,
            },
            npcs = {
                canDecorate = false,
                evaluated = false,
                valid = nil,
            },
            features = {
                canDecorate = false,
                evaluated = false,
                valid = nil,
            },
        }
        if route == nil then
            local invalid = { code = "unknown_route", message = "Unknown route: " .. tostring(routeKey) }
            return {
                routeKey = routeKey,
                valid = false,
                disabled = true,
                invalidRows = { invalid },
                blockingHorizon = {
                    layer = "route",
                    routeKey = routeKey,
                    code = invalid.code,
                    message = invalid.message,
                },
                layerStatus = layerStatus,
                biomes = snapshots,
            }
        end

        local previousSnapshotBuilding = self.snapshotBuilding
        self.snapshotBuilding = true
        local configuredBiomeCount = self:configuredBiomeCount(route.key)
        for routeBiomeIndex, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
            if routeBiomeIndex > configuredBiomeCount then
                break
            end
            local snapshot = controlSnapshot(self, route.key, biomeKey)
            snapshots[#snapshots + 1] = snapshot
            if routeLocalInvalid == nil then
                if not snapshot then
                    routeLocalInvalid = missingControlInvalid(self, routeBiomeIndex, biomeKey)
                else
                    routeLocalInvalid = firstLocalInvalid(snapshot, biomeKey, routeBiomeIndex)
                end
            end
        end
        self.snapshotBuilding = previousSnapshotBuilding

        if self:isLayerConfigured(route.key, "rewards") then
            local rewardInvalidRows = self:rewardLegality(route.key, rewardBoundaryForInvalid(routeLocalInvalid)).invalidRows
            if rewardInvalidRows[1] ~= nil then
                appendInvalidRows(invalidRows, rewardInvalidRows)
            else
                appendFirstInvalid(invalidRows, routeLocalInvalid)
            end
        else
            appendFirstInvalid(invalidRows, routeLocalInvalid)
        end

        local routeValid = invalidRows[1] == nil
        local npcsConfigured = self:isLayerConfigured(route.key, "npcs")
        layerStatus.route.evaluated = true
        layerStatus.route.valid = routeValid
        layerStatus.npcs.canDecorate = routeValid

        if routeValid and npcsConfigured then
            local npcControl = self:controlByName(routeNpcControlName(route.key), route.key)
            if npcControl ~= nil and npcControl.read ~= nil then
                layerStatus.npcs.evaluated = true
                npcSnapshot = npcControl:read("snapshot")
                local invalidRow = npcSnapshot and npcSnapshot.invalidRows and npcSnapshot.invalidRows[1] or nil
                if invalidRow ~= nil then
                    appendInvalidRows(invalidRows, npcSnapshot.invalidRows)
                end
            end
        end

        local npcsValid = not npcsConfigured or invalidRows[1] == nil
        local featuresConfigured = self:hasConfiguredFeatures(route.key)
        layerStatus.npcs.valid = npcsValid
        layerStatus.features.canDecorate = routeValid and npcsValid

        if routeValid and npcsValid and featuresConfigured then
            for _, featureKey in ipairs(routeFeatureKeys(self, route)) do
                if self:isFeatureConfigured(route.key, featureKey) then
                    local featureControl = self:controlByName(routeFeatureControlName(route.key, featureKey), route.key)
                    if featureControl ~= nil and featureControl.read ~= nil then
                        layerStatus.features.evaluated = true
                        local featureSnapshot = featureControl:read("snapshot")
                        featureSnapshots[#featureSnapshots + 1] = featureSnapshot
                        local invalidRow = featureSnapshot and featureSnapshot.invalidRows and featureSnapshot.invalidRows[1] or nil
                        if invalidRow ~= nil then
                            appendInvalidRows(invalidRows, featureSnapshot.invalidRows)
                            break
                        end
                    end
                end
            end
        end
        layerStatus.features.valid = not featuresConfigured or invalidRows[1] == nil

        return {
            routeKey = route.key,
            label = route.label,
            configuredBiomeCount = configuredBiomeCount,
            valid = invalidRows[1] == nil,
            disabled = invalidRows[1] ~= nil,
            invalidRows = invalidRows,
            blockingHorizon = blockingHorizon(self, route, invalidRows[1]),
            layerStatus = layerStatus,
            biomes = snapshots,
            npcs = npcSnapshot,
            features = featureSnapshots,
        }
    end

    function context:blockingHorizon(routeKey)
        local snapshot = self:overview(routeKey)
        return snapshot and snapshot.blockingHorizon or nil
    end

    function context:canDecorateLayer(routeKey, layer)
        local snapshot = self:overview(routeKey)
        local status = snapshot and snapshot.layerStatus and snapshot.layerStatus[layer] or nil
        return status == nil or status.canDecorate ~= false
    end

    function context:canUseEnrichmentColors(routeKey)
        local snapshot = self:overview(routeKey)
        return snapshot ~= nil and snapshot.valid == true
    end

    function context:isLayerInactive(routeKey, layer)
        return layerInactive(self:blockingHorizon(routeKey), layer)
    end

    function context:isRouteBiomeInactive(routeKey, biomeKey)
        local horizon = self:blockingHorizon(routeKey)
        if horizon == nil or horizon.layer ~= "route" or horizon.routeBiomeIndex == nil then
            return false
        end
        local info = self:routeInfo(routeKey, biomeKey)
        return info ~= nil and info.index > horizon.routeBiomeIndex
    end

    function context:isRouteRowInactive(routeKey, biomeKey, routeOrdinal, tabKey)
        local horizon = self:blockingHorizon(routeKey)
        if horizon == nil or horizon.layer ~= "route" then
            return false
        end
        local info = self:routeInfo(routeKey, biomeKey)
        local horizonKey = routePosition.key({
            routeBiomeIndex = horizon.routeBiomeIndex,
            tabKey = routePosition.tabKeyForInvalid(horizon),
            routeOrdinal = horizon.routeOrdinal,
        })
        if horizonKey == nil then
            return self:isRouteBiomeInactive(routeKey, biomeKey)
        end
        return routePosition.after(
            routePosition.key({
                routeBiomeIndex = info and info.index or nil,
                tabKey = tabKey or "rooms",
                routeOrdinal = routeOrdinal,
            }),
            horizonKey
        )
    end

    function context:isTargetRowInactive(routeKey, layer, controlName, rowIndex)
        local allInactive, inactiveAfterRowIndex = self:targetInactiveBoundary(routeKey, layer, controlName)
        return allInactive
            or (
                inactiveAfterRowIndex ~= nil
                and rowIndex ~= nil
                and rowIndex > inactiveAfterRowIndex
            )
    end

    function context:targetInactiveBoundary(routeKey, layer, controlName)
        if self:isLayerInactive(routeKey, layer) then
            return true, nil
        end

        local horizon = self:blockingHorizon(routeKey)
        if horizon == nil or horizon.layer ~= layer then
            return false, nil
        end

        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        if route == nil then
            return false, nil
        end

        local targetIndex = layerControlIndex(self, route, layer, controlName)
        local horizonIndex = layerControlIndex(self, route, layer, horizon.controlName)
        if targetIndex == nil or horizonIndex == nil then
            return false, nil
        end
        if targetIndex ~= horizonIndex then
            return targetIndex > horizonIndex, nil
        end
        return false, horizon.rowIndex
    end

    function context:isNavTabInactive(routeKey, tab)
        if tab.layer ~= nil then
            return self:isLayerInactive(routeKey, tab.layer)
        end
        return self:isRouteBiomeInactive(routeKey, tab.key)
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

return runContext
