local feedback = {}

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

local function selectedNpcSnapshot(context, routeKey)
    local controlName = context.routeNpcsControlName and context:routeNpcsControlName(routeKey) or nil
    local control = controlName ~= nil and context:controlByName(controlName, routeKey) or nil
    if control == nil or control.read == nil then
        return nil
    end
    return control:read("selectedNpcSnapshot")
end

local function applyRouteFeedback(context, historySystem, route, routeFeedback, EMPTY_LIST)
    local generation = context:routeGeneration(route.key)
    for routeBiomeIndex, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
        if routeBiomeIndex > context:configuredBiomeCount(route.key) then
            break
        end
        local control = context:controlForBiome(route.key, biomeKey)
        if control ~= nil and control.applyRouteFeedback ~= nil then
            control:applyRouteFeedback(
                historySystem.feedback.forBiome(routeFeedback, biomeKey),
                generation
            )
        end
    end
end

local function applyNpcFeedback(context, routeKey, npcFeedback, generation)
    local controlName = context.routeNpcsControlName and context:routeNpcsControlName(routeKey) or nil
    local control = controlName ~= nil and context:controlByName(controlName, routeKey) or nil
    if control ~= nil and control.applyRouteFeedback ~= nil then
        control:applyRouteFeedback(npcFeedback, generation)
    end
end

function feedback.install(context, deps)
    local state = deps.state
    local historySystem = deps.historySystem
    local EMPTY_LIST = deps.EMPTY_LIST

    function context:controlCompletionReport(routeKey, biomeKey)
        local reports = state.routeCompletionCache(self, routeKey)
        if reports[biomeKey] ~= nil then
            return reports[biomeKey]
        end

        local control = self:controlForBiome(routeKey, biomeKey)
        local report = control ~= nil and control.read ~= nil and control:read("completion") or nil
        reports[biomeKey] = report or false
        return report
    end

    function context:historyFeedback(routeKey)
        local feedbackState = state.routeHistoryFeedbackState(self, routeKey)
        if feedbackState.dirty or feedbackState.feedback == nil then
            local route = self.configuredRoute and self:configuredRoute(routeKey)
                or self.routes.lookup and self.routes.lookup[routeKey]
                or nil
            local result = {
                valid = true,
                invalids = {},
                findings = {},
            }
            local routeFeedback
            if route ~= nil then
                local history = historySystem.builder.build({
                    route = route,
                    biomeLookup = self.biomeLookup,
                    snapshotForBiome = function(_, biomeKey)
                        return selectedRowsSnapshot(self, route.key, biomeKey)
                    end,
                })
                local npcTargets = historySystem.npcCandidates.build({
                    route = route,
                    history = history,
                    npcs = self.npcs,
                    biomeLookup = self.biomeLookup,
                })
                local npcSnapshot = self:isLayerConfigured(route.key, "npcs")
                    and selectedNpcSnapshot(self, route.key)
                    or nil
                result = historySystem.validator.validate({
                    route = route,
                    history = history,
                    biomeLookup = self.biomeLookup,
                    npcSnapshot = npcSnapshot,
                    npcTargets = npcTargets,
                    npcs = self.npcs,
                })
                routeFeedback = historySystem.feedback.fromResult({
                    route = route,
                    history = history,
                    biomeLookup = self.biomeLookup,
                    findings = result.findings,
                    invalids = result.invalids,
                })
                feedbackState.npcTargets = npcTargets
                feedbackState.npcFeedback = historySystem.npcFeedback.fromResult({
                    findings = result.findings,
                    invalids = result.invalids,
                })
                local generation = self:routeGeneration(route.key)
                applyRouteFeedback(self, historySystem, route, routeFeedback, EMPTY_LIST)
                applyNpcFeedback(self, route.key, feedbackState.npcFeedback, generation)
            end
            feedbackState.result = result
            feedbackState.feedback = routeFeedback
            feedbackState.dirty = false
        end
        return feedbackState.feedback, feedbackState.result
    end

    function context.routeNpcsControlName(_, routeKey)
        return deps.routeNpcsControlName(routeKey)
    end

    function context:npcTargetsForSlot(routeKey, npcKey, fixedBiomeKey)
        self:historyFeedback(routeKey)
        local feedbackState = state.routeHistoryFeedbackState(self, routeKey)
        local targets = feedbackState.npcTargets or {}
        if fixedBiomeKey ~= nil then
            return targets.byNpcBiome
                and targets.byNpcBiome[npcKey]
                and targets.byNpcBiome[npcKey][fixedBiomeKey]
                or nil
        end
        return targets.byNpc and targets.byNpc[npcKey] or nil
    end

    function context:historyValueStates(routeKey, biomeKey, rowIndex, controlAlias, rewardAddress)
        local routeFeedback = self:historyFeedback(routeKey)
        return historySystem.feedback.valueStatesForControl(
            routeFeedback,
            biomeKey,
            rowIndex,
            controlAlias,
            rewardAddress
        )
    end

    function context:historyRowInactive(routeKey, biomeKey, rowIndex)
        local routeFeedback = self:historyFeedback(routeKey)
        return historySystem.feedback.rowInactive(routeFeedback, biomeKey, rowIndex)
    end
end

return feedback
