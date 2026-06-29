local deps = ... or {}
local routeControls = deps.controls
local routeRewards = deps.rewards
local routePosition = deps.position
local historySystem = deps.historySystem

local runContext = {}
local EMPTY_LIST = {}

local routeControlName = routeControls.routeControlName
local routeGlobalControlName = routeControls.routeGlobalControlName
local buildRouteInfo = routeControls.buildRouteInfo

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

local function routeCompletionCache(context, routeKey)
    local reports = context.completionByRoute[routeKey]
    if reports == nil then
        reports = {}
        context.completionByRoute[routeKey] = reports
    end
    return reports
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

local function routeHistoryFeedbackState(context, routeKey)
    local state = context.historyFeedbackByRoute[routeKey]
    if state == nil then
        state = {
            dirty = true,
            feedback = nil,
            result = nil,
        }
        context.historyFeedbackByRoute[routeKey] = state
    end
    return state
end

local function applyRouteFeedback(context, route, feedback)
    local generation = context:routeGeneration(route.key)
    for routeBiomeIndex, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
        if routeBiomeIndex > context:configuredBiomeCount(route.key) then
            break
        end
        local control = context:controlForBiome(route.key, biomeKey)
        if control ~= nil and control.applyRouteFeedback ~= nil then
            control:applyRouteFeedback(
                historySystem.feedback.forBiome(feedback, biomeKey),
                generation
            )
        end
    end
end

local function controlCompletionReport(context, routeKey, biomeKey)
    local reports = routeCompletionCache(context, routeKey)
    if reports[biomeKey] ~= nil then
        return reports[biomeKey]
    end

    local control = context:controlForBiome(routeKey, biomeKey)
    local report = control ~= nil and control.read ~= nil and control:read("completion") or nil
    reports[biomeKey] = report or false
    return report
end

local function legacyRowsReport(context, routeKey, biomeKey)
    local control = context:controlForBiome(routeKey, biomeKey)
    if control == nil or control.rowSnapshot == nil or control.rowCount == nil then
        return nil
    end

    local rows = {}
    for rowIndex = 1, control:rowCount() do
        rows[#rows + 1] = control:rowSnapshot(rowIndex)
    end
    local completion = controlCompletionReport(context, routeKey, biomeKey)
    return {
        controlName = completion and completion.controlName or nil,
        biomeKey = biomeKey,
        adapter = completion and completion.adapter or nil,
        rows = rows,
    }
end

local function selectedRowsSnapshot(context, routeKey, biomeKey)
    local control = context:controlForBiome(routeKey, biomeKey)
    if control == nil or control.read == nil then
        return nil
    end
    local selected = control:read("selectedRowsSnapshot")
    if selected ~= nil then
        return selected
    end
    return nil
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

local function firstCompletionInvalid(routeBiomeIndex, biomeKey, completion)
    local invalid = completion and completion.completionInvalidRows and completion.completionInvalidRows[1] or nil
    if invalid == nil then
        return nil
    end
    return copyInvalidRow(invalid, {
        biomeKey = biomeKey,
        routeBiomeIndex = routeBiomeIndex,
        controlName = completion.controlName or routeControlName(biomeKey),
    })
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

local function layerForInvalid(invalid)
    if invalid.layer ~= nil then
        return invalid.layer
    end
    return "route"
end

local function blockingHorizon(context, route, invalid)
    if invalid == nil then
        return nil
    end

    local horizon = copyInvalidRow(invalid, {
        layer = layerForInvalid(invalid),
        routeKey = route.key,
    })
    if horizon.routeBiomeIndex == nil and horizon.biomeKey ~= nil then
        local info = context:routeInfo(route.key, horizon.biomeKey)
        horizon.routeBiomeIndex = info and info.index or nil
    end
    return horizon
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
        controlResolver = opts.controlResolver,
        controls = opts.controls,
        completionByRoute = {},
        overviewByRoute = {},
        rewardLegalityByRoute = {},
        historyFeedbackByRoute = {},
        godSourceByRoute = {},
        generationByRoute = {},
    }
    context.rewardState = routeRewards.create({
        rewardLegality = opts.rewardLegality,
        routeControlName = routeControlName,
    })

    function context:beginPass(controls)
        self.controls = controls or self.controls
        clearMap(self.completionByRoute)
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
        clearMap(self.completionByRoute)
        clearMap(self.rewardLegalityByRoute)
        clearMap(self.historyFeedbackByRoute)
    end

    function context:markRoutesForBiome(biomeKey)
        local marked = false
        for routeKey, routeInfos in pairs(self.routeInfoByRoute) do
            if routeInfos[biomeKey] ~= nil then
                routeOverviewState(self, routeKey).dirty = true
                bumpRouteGeneration(self, routeKey)
                self.completionByRoute[routeKey] = nil
                self.rewardLegalityByRoute[routeKey] = nil
                self.historyFeedbackByRoute[routeKey] = nil
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
            self.completionByRoute[routeKey] = nil
            self.rewardLegalityByRoute[routeKey] = nil
            self.historyFeedbackByRoute[routeKey] = nil
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

    function context:controlCompletionReport(routeKey, biomeKey)
        return controlCompletionReport(self, routeKey, biomeKey)
    end

    function context:legacyRowsReport(routeKey, biomeKey)
        return legacyRowsReport(self, routeKey, biomeKey)
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

    function context:isControlConfigured(routeKey, controlName)
        if controlName == routeGlobalControlName(routeKey) then
            return true
        end
        local biomeKey = biomeKeyForControl(self, routeKey, controlName)
        if biomeKey ~= nil then
            return self:isBiomeInConfiguredScope(routeKey, biomeKey)
        end
        return true
    end

    function context:attachControls()
        for _, route in ipairs(self.routes.ordered or EMPTY_LIST) do
            self:godSourceForRoute(route.key)
            for _, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
                self:controlForBiome(route.key, biomeKey)
            end
        end
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
        local states = self.rewardState.valueStates(
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
        local historyStates = self:historyValueStates(routeKey, biomeKey, rowIndex, controlAlias)
        if historyStates == nil then
            return states
        elseif states == nil then
            return historyStates
        end
        for value, state in pairs(historyStates) do
            states[value] = state
        end
        return states
    end

    function context:historyFeedback(routeKey)
        local state = routeHistoryFeedbackState(self, routeKey)
        if state.dirty or state.feedback == nil then
            local route = self.configuredRoute and self:configuredRoute(routeKey)
                or self.routes.lookup and self.routes.lookup[routeKey]
                or nil
            local result = {
                valid = true,
                invalids = {},
                findings = {},
            }
            local feedback
            if route ~= nil then
                local history = historySystem.builder.build({
                    route = route,
                    biomeLookup = self.biomeLookup,
                    snapshotForBiome = function(_, biomeKey)
                        return selectedRowsSnapshot(self, route.key, biomeKey)
                    end,
                })
                result = historySystem.validator.validate({
                    route = route,
                    history = history,
                    biomeLookup = self.biomeLookup,
                })
                feedback = historySystem.feedback.fromResult({
                    route = route,
                    biomeLookup = self.biomeLookup,
                    findings = result.findings,
                    invalids = result.invalids,
                })
                applyRouteFeedback(self, route, feedback)
            end
            state.result = result
            state.feedback = feedback
            state.dirty = false
        end
        return state.feedback, state.result
    end

    function context:historyValueStates(routeKey, biomeKey, rowIndex, controlAlias)
        local feedback = self:historyFeedback(routeKey)
        return historySystem.feedback.valueStatesForControl(
            feedback,
            biomeKey,
            rowIndex,
            controlAlias
        )
    end

    function context:historyRowInactive(routeKey, biomeKey, rowIndex)
        local feedback = self:historyFeedback(routeKey)
        return historySystem.feedback.rowInactive(feedback, biomeKey, rowIndex)
    end

    function context:snapshot(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local snapshots = {}
        local invalidRows = {}
        local missingInvalid
        local layerStatus = {
            route = {
                canDecorate = true,
                evaluated = false,
                valid = nil,
            },
        }
        if route == nil then
            local invalid = { code = "unknown_route", message = "Unknown route: " .. tostring(routeKey) }
            local routeFeedback = {
                valid = false,
                primary = invalid,
                related = {},
                markers = { invalid },
            }
            return {
                routeKey = routeKey,
                valid = false,
                disabled = true,
                invalidRows = { invalid },
                routeFeedback = routeFeedback,
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

        local previousCompletionBuilding = self.completionBuilding
        self.completionBuilding = true
        local configuredBiomeCount = self:configuredBiomeCount(route.key)
        local completionInvalid = nil
        for routeBiomeIndex, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
            if routeBiomeIndex > configuredBiomeCount then
                break
            end
            local completion = controlCompletionReport(self, route.key, biomeKey)
            snapshots[#snapshots + 1] = completion
            if missingInvalid == nil and not completion then
                missingInvalid = missingControlInvalid(self, routeBiomeIndex, biomeKey)
            end
            if completionInvalid == nil and completion then
                completionInvalid = firstCompletionInvalid(routeBiomeIndex, biomeKey, completion)
            end
        end
        self.completionBuilding = previousCompletionBuilding

        local routeFeedback
        if missingInvalid ~= nil then
            routeFeedback = {
                valid = false,
                primary = missingInvalid,
                related = {},
                markers = { missingInvalid },
            }
        elseif completionInvalid == nil then
            local historyFeedback = self:historyFeedback(route.key)
            routeFeedback = historyFeedback and historyFeedback.route or nil
        else
            routeFeedback = {
                valid = false,
                primary = completionInvalid,
                related = {},
                markers = { completionInvalid },
            }
        end

        routeFeedback = routeFeedback or {
            valid = true,
            primary = nil,
            related = {},
            markers = {},
        }

        for _, marker in ipairs(routeFeedback.markers or EMPTY_LIST) do
            invalidRows[#invalidRows + 1] = marker
        end

        local routeValid = routeFeedback.valid == true
        layerStatus.route.evaluated = true
        layerStatus.route.valid = routeValid

        return {
            routeKey = route.key,
            label = route.label,
            configuredBiomeCount = configuredBiomeCount,
            valid = routeValid,
            disabled = not routeValid,
            incomplete = completionInvalid ~= nil,
            incompleteBiomeKey = completionInvalid and completionInvalid.biomeKey or nil,
            incompleteControlName = completionInvalid and completionInvalid.controlName or nil,
            incompleteMessage = completionInvalid
                    and ("Data entry incomplete: finish " .. biomeLabel(self, completionInvalid.biomeKey))
                or nil,
            invalidRows = invalidRows,
            routeFeedback = routeFeedback,
            blockingHorizon = blockingHorizon(self, route, routeFeedback.primary),
            layerStatus = layerStatus,
            biomes = snapshots,
        }
    end

    function context:blockingHorizon(routeKey)
        local overview = self:overview(routeKey)
        return overview and overview.blockingHorizon or nil
    end

    function context:canUseEnrichmentColors(routeKey)
        local overview = self:overview(routeKey)
        return overview ~= nil and overview.valid == true
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

    function context:isNavTabInactive(routeKey, tab)
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
