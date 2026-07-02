local overview = {}

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

local function appendCompletionInvalids(target, routeControlName, routeBiomeIndex, biomeKey, completion)
    for _, invalid in ipairs(completion and completion.completionInvalidRows or {}) do
        target[#target + 1] = copyInvalidRow(invalid, {
            biomeKey = biomeKey,
            routeBiomeIndex = routeBiomeIndex,
            controlName = completion.controlName or routeControlName(biomeKey),
        })
    end
end

local function feedbackFromInvalids(context, historySystem, route, invalids)
    return historySystem.feedback.fromResult({
        route = route,
        biomeLookup = context.biomeLookup,
        findings = {},
        invalids = invalids,
    })
end

local function applyBiomeFeedback(context, historySystem, route, feedbackState, EMPTY_LIST)
    local generation = context:routeGeneration(route.key)
    for routeBiomeIndex, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
        if routeBiomeIndex > context:configuredBiomeCount(route.key) then
            break
        end
        local control = context:controlForBiome(route.key, biomeKey)
        if control ~= nil and control.applyRouteFeedback ~= nil then
            control:applyRouteFeedback(
                historySystem.feedback.forBiome(feedbackState, biomeKey),
                generation
            )
        end
    end
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

function overview.install(context, deps)
    local state = deps.state
    local routeHorizon = deps.horizon
    local routeControlName = deps.routeControlName
    local historySystem = deps.historySystem
    local EMPTY_LIST = deps.EMPTY_LIST

    function context:snapshot(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local snapshots = {}
        local invalidRows = {}
        local layerStatus = {
            route = {
                canDecorate = true,
                evaluated = false,
                valid = nil,
            },
        }
        if route == nil then
            error("Route context invariant failed: unknown route " .. tostring(routeKey), 0)
        end

        local previousCompletionBuilding = self.completionBuilding
        self.completionBuilding = true
        local configuredBiomeCount = self:configuredBiomeCount(route.key)
        local completionInvalids = {}
        for routeBiomeIndex, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
            if routeBiomeIndex > configuredBiomeCount then
                break
            end
            local completion = self:controlCompletionReport(route.key, biomeKey)
            snapshots[#snapshots + 1] = completion
            appendCompletionInvalids(completionInvalids, routeControlName, routeBiomeIndex, biomeKey, completion)
        end
        self.completionBuilding = previousCompletionBuilding

        local routeFeedback
        local feedbackState
        if completionInvalids[1] ~= nil then
            feedbackState = feedbackFromInvalids(self, historySystem, route, completionInvalids)
            routeFeedback = feedbackState.route
            applyBiomeFeedback(self, historySystem, route, feedbackState, EMPTY_LIST)
        else
            local historyFeedback = self:historyFeedback(route.key)
            local historyRouteFeedback = historyFeedback and historyFeedback.route or nil
            routeFeedback = historyRouteFeedback
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
            incomplete = routeFeedback.primary ~= nil and routeFeedback.primary.completion == true,
            incompleteBiomeKey = completionInvalids[1] and completionInvalids[1].biomeKey or nil,
            incompleteControlName = completionInvalids[1] and completionInvalids[1].controlName or nil,
            invalidRows = invalidRows,
            routeFeedback = routeFeedback,
            blockingHorizon = blockingHorizon(self, route, routeFeedback.primary),
            layerStatus = layerStatus,
            biomes = snapshots,
        }
    end

    function context:blockingHorizon(routeKey)
        local routeOverview = self:overview(routeKey)
        return routeOverview and routeOverview.blockingHorizon or nil
    end

    function context:canUseEnrichmentColors(routeKey)
        local routeOverview = self:overview(routeKey)
        return routeOverview ~= nil and routeOverview.valid == true
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
        local horizonKey = routeHorizon.key({
            routeBiomeIndex = horizon.routeBiomeIndex,
            tabKey = routeHorizon.tabKeyForInvalid(horizon),
            routeOrdinal = routeHorizon.routeOrdinalForInvalid(horizon),
        })
        if horizonKey == nil then
            return self:isRouteBiomeInactive(routeKey, biomeKey)
        end
        return routeHorizon.after(
            routeHorizon.key({
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
        local routeOverview = state.routeOverviewState(self, routeKey)
        if routeOverview.dirty or routeOverview.snapshot == nil then
            routeOverview.snapshot = self:snapshot(routeKey)
            routeOverview.dirty = false
        end
        return routeOverview.snapshot
    end
end

return overview
