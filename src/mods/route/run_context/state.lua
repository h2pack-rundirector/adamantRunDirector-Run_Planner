local state = {}

function state.clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

function state.routeCompletionCache(context, routeKey)
    local reports = context.completionByRoute[routeKey]
    if reports == nil then
        reports = {}
        context.completionByRoute[routeKey] = reports
    end
    return reports
end

function state.routeOverviewState(context, routeKey)
    local routeState = context.overviewByRoute[routeKey]
    if routeState == nil then
        routeState = {
            dirty = true,
            snapshot = nil,
        }
        context.overviewByRoute[routeKey] = routeState
    end
    return routeState
end

function state.routeHistoryFeedbackState(context, routeKey)
    local feedbackState = context.historyFeedbackByRoute[routeKey]
    if feedbackState == nil then
        feedbackState = {
            dirty = true,
            feedback = nil,
            result = nil,
        }
        context.historyFeedbackByRoute[routeKey] = feedbackState
    end
    return feedbackState
end

function state.bumpRouteGeneration(context, routeKey)
    context.generationByRoute[routeKey] = (context.generationByRoute[routeKey] or 0) + 1
end

function state.install(context, deps)
    local EMPTY_LIST = deps.EMPTY_LIST

    function context:beginPass(controls)
        self.controls = controls or self.controls
        state.clearMap(self.completionByRoute)
    end

    function context:markAllDirty()
        for _, route in ipairs(self.routes.ordered or EMPTY_LIST) do
            state.routeOverviewState(self, route.key).dirty = true
            state.bumpRouteGeneration(self, route.key)
        end
        state.clearMap(self.completionByRoute)
        state.clearMap(self.historyFeedbackByRoute)
    end

    function context:markRoutesForBiome(biomeKey)
        local marked = false
        for routeKey, routeInfos in pairs(self.routeInfoByRoute) do
            if routeInfos[biomeKey] ~= nil then
                state.routeOverviewState(self, routeKey).dirty = true
                state.bumpRouteGeneration(self, routeKey)
                self.completionByRoute[routeKey] = nil
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
            state.routeOverviewState(self, routeKey).dirty = true
            state.bumpRouteGeneration(self, routeKey)
            self.completionByRoute[routeKey] = nil
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
end

return state
