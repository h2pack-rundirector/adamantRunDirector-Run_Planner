local deps = ... or {}
local semantics = deps.semantics
local defaultRewardLegality = deps.rewardLegality
local routeTimeline = deps.timeline
local routeValueStates = deps.valueStates

local rewards = {}
local EMPTY_LIST = {}
local NO_VALUE_STATES = false
local INVALID_VALUE_STATE = routeValueStates and routeValueStates.INVALID or 2

local function routeRewardLegalityState(context, routeKey)
    local state = context.rewardLegalityByRoute[routeKey]
    if state == nil then
        state = {
            dirty = true,
            result = nil,
            stopBeforeBiomeIndex = nil,
            stopBeforeRouteOrdinal = nil,
        }
        context.rewardLegalityByRoute[routeKey] = state
    end
    return state
end

local function newRewardLegalityResult()
    return {
        invalidRows = {},
        byBiomeRow = {},
        decisionsByBiomeRowAddress = {},
        valueStatesByBiomeRow = {},
    }
end

local function defaultRouteControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

local function routeBoundaryReached(rowContext, opts)
    if opts.stopBeforeBiomeIndex ~= nil and rowContext.routeBiomeIndex >= opts.stopBeforeBiomeIndex then
        return true
    end
    if opts.stopBeforeRouteOrdinal ~= nil and rowContext.routeOrdinal >= opts.stopBeforeRouteOrdinal then
        return true
    end
    return false
end

local function rewardRowContext(rowContext, routeControlName)
    local biomeKey = rowContext.biomeKey
    return {
        biomeKey = biomeKey,
        routeBiomeIndex = rowContext.routeBiomeIndex,
        controlName = routeControlName(biomeKey),
        routeOrdinal = rowContext.routeOrdinal,
        roomHistoryOrdinal = rowContext.roomHistoryOrdinal,
        runDepthCache = rowContext.runDepthCache,
        runEncounterDepth = rowContext.runEncounterDepth,
        runEncounterDepthMin = rowContext.runEncounterDepthMin,
        runEncounterDepthMax = rowContext.runEncounterDepthMax,
        biomeDepthCache = rowContext.biomeDepthCache,
        biomeEncounterDepth = rowContext.biomeEncounterDepth,
        biomeEncounterDepthMin = rowContext.biomeEncounterDepthMin,
        biomeEncounterDepthMax = rowContext.biomeEncounterDepthMax,
        offerTopology = rowContext.row and rowContext.row.offerTopology or nil,
    }
end

local function valueStatesForBiome(result, biomeKey)
    local byBiome = result.valueStatesByBiomeRow[biomeKey]
    if byBiome == nil then
        byBiome = {}
        result.valueStatesByBiomeRow[biomeKey] = byBiome
    end
    return byBiome
end

local function valueStatesForRow(result, biomeKey, rowIndex)
    local byRow = valueStatesForBiome(result, biomeKey)
    local rowStates = byRow[rowIndex]
    if rowStates == nil then
        rowStates = {}
        byRow[rowIndex] = rowStates
    end
    return rowStates
end

local function valueStatesForAddress(result, biomeKey, rowIndex, rewardAddress)
    local rowStates = valueStatesForRow(result, biomeKey, rowIndex)
    rewardAddress = rewardAddress or "row"
    local addressStates = rowStates[rewardAddress]
    if addressStates == nil then
        addressStates = {}
        rowStates[rewardAddress] = addressStates
    end
    return addressStates
end

local function cachedControlValueStates(result, biomeKey, rowIndex, rewardAddress, controlAlias)
    local rowStates = result.valueStatesByBiomeRow[biomeKey]
    local addressStates = rowStates and rowStates[rowIndex] and rowStates[rowIndex][rewardAddress or "row"] or nil
    if addressStates == nil then
        return nil
    end
    return addressStates[controlAlias]
end

local function storeControlValueStates(result, biomeKey, rowIndex, rewardAddress, controlAlias, states)
    valueStatesForAddress(result, biomeKey, rowIndex, rewardAddress)[controlAlias] = states or NO_VALUE_STATES
end

local function decisionForAddress(result, biomeKey, rowIndex, rewardAddress)
    local byBiome = result.decisionsByBiomeRowAddress[biomeKey]
    local byRow = byBiome and byBiome[rowIndex] or nil
    return byRow and byRow[rewardAddress or "row"] or nil
end

local function setInvalidState(states, value)
    states = states or {}
    routeValueStates.set(states, value, INVALID_VALUE_STATE)
    return states
end

local function applyInvalidMarkerStates(result, biomeKey, rowIndex, rewardAddress, controlAlias, states)
    rewardAddress = rewardAddress or "row"
    for _, invalid in ipairs(result.invalidRows or EMPTY_LIST) do
        if invalid.biomeKey == biomeKey and invalid.rowIndex == rowIndex then
            for _, target in ipairs(invalid.valueTargets or EMPTY_LIST) do
                if target.address == rewardAddress
                    and target.controlAlias == controlAlias
                    and target.value ~= nil
                    and target.value ~= ""
                then
                    states = setInvalidState(states, target.value)
                end
            end
        end
    end
    return states
end

local function buildCandidateValueStates(rewardLegalityEngine, decision, rewardAddress, control)
    if rewardLegalityEngine == nil or rewardLegalityEngine.candidateInvalid == nil or decision == nil then
        return nil
    end

    local item = control ~= nil and decision.item or nil
    if item == nil then
        return nil
    end

    local rewardCtx = decision.rewardCtxBeforeDecision
    local states = nil
    for _, value in ipairs(control and control.values or EMPTY_LIST) do
        local event = semantics.candidateEventForControl(decision.row, item, control, value, rewardAddress or decision.address)
        if event ~= nil
            and rewardLegalityEngine.candidateInvalid(rewardCtx, decision.ctx, event) ~= nil
        then
            states = setInvalidState(states, value)
        end
    end
    return states
end

local function evaluateRouteLegality(context, routeKey, opts)
    opts = opts or {}
    local rewardLegalityEngine = opts.rewardLegality
    local route = context.routes.lookup and context.routes.lookup[routeKey] or nil
    local result = rewardLegalityEngine ~= nil and rewardLegalityEngine.emptyResult() or newRewardLegalityResult()
    if route == nil or rewardLegalityEngine == nil or routeTimeline == nil then
        return result
    end

    local rewardCtx = rewardLegalityEngine.beginRoute()
    local routeControlName = opts.routeControlName or defaultRouteControlName
    local scratch = {}
    local stopped = false
    routeTimeline.walkRoute(route, {
        biomeLookup = context.biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return context:controlSnapshot(route.key, biomeKey)
        end,
        onRow = function(rowContext)
            if stopped then
                return
            end
            if routeBoundaryReached(rowContext, opts) then
                stopped = true
                return
            end

            local ctx = rewardRowContext(rowContext, routeControlName)
            if rewardLegalityEngine.prepareRow ~= nil then
                local invalid = rewardLegalityEngine.prepareRow(
                    context,
                    result,
                    rewardCtx,
                    ctx,
                    rowContext.row,
                    scratch
                )
                if opts.stopAfterFirstInvalid and invalid ~= nil then
                    stopped = true
                    return
                end
            end
            local invalid = rewardLegalityEngine.evaluateRow(
                context,
                result,
                rewardCtx,
                ctx,
                rowContext.row,
                scratch
            )
            if opts.stopAfterFirstInvalid and invalid ~= nil then
                stopped = true
            end
        end,
    })
    if not stopped and rewardLegalityEngine.finishRoute ~= nil then
        rewardLegalityEngine.finishRoute(context, result, rewardCtx, scratch)
    end
    return result
end

function rewards.create(opts)
    opts = opts or {}
    local rewardLegalityEngine = opts.rewardLegality or defaultRewardLegality
    local routeControlName = opts.routeControlName or defaultRouteControlName

    local rewardState = {}

    function rewardState.legality(context, routeKey, rewardOpts)
        local state = routeRewardLegalityState(context, routeKey)
        rewardOpts = rewardOpts or {}
        local stopBeforeBiomeIndex = rewardOpts.stopBeforeBiomeIndex
        local stopBeforeRouteOrdinal = rewardOpts.stopBeforeRouteOrdinal
        if state.dirty
            or state.result == nil
            or state.stopBeforeBiomeIndex ~= stopBeforeBiomeIndex
            or state.stopBeforeRouteOrdinal ~= stopBeforeRouteOrdinal
        then
            if context:isLayerConfigured(routeKey, "rewards") and rewardLegalityEngine ~= nil then
                local previousRewardLegalityBuilding = context.rewardLegalityBuilding
                context.rewardLegalityBuilding = true
                state.result = evaluateRouteLegality(context, routeKey, {
                    rewardLegality = rewardLegalityEngine,
                    routeControlName = routeControlName,
                    stopAfterFirstInvalid = true,
                    stopBeforeBiomeIndex = stopBeforeBiomeIndex,
                    stopBeforeRouteOrdinal = stopBeforeRouteOrdinal,
                })
                context.rewardLegalityBuilding = previousRewardLegalityBuilding
            else
                state.result = newRewardLegalityResult()
            end
            state.stopBeforeBiomeIndex = stopBeforeBiomeIndex
            state.stopBeforeRouteOrdinal = stopBeforeRouteOrdinal
            state.dirty = false
        end
        return state.result
    end

    function rewardState.rowValidation(context, routeKey, biomeKey, rowIndex)
        if context.snapshotBuilding or context.rewardLegalityBuilding then
            return nil
        end

        local result = rewardState.legality(context, routeKey)
        local byRow = result.byBiomeRow[biomeKey]
        return byRow and byRow[rowIndex] or nil
    end

    function rewardState.valueStates(
        context,
        routeKey,
        biomeKey,
        rowIndex,
        rewardAddress,
        controlAlias,
        control,
        _fields,
        _rewardContext
    )
        if context.snapshotBuilding or context.rewardLegalityBuilding then
            return nil
        end
        if routeKey == nil or biomeKey == nil or rowIndex == nil or controlAlias == nil then
            return nil
        end

        local result = rewardState.legality(context, routeKey)
        local cached = cachedControlValueStates(result, biomeKey, rowIndex, rewardAddress, controlAlias)
        if cached ~= nil then
            if cached == NO_VALUE_STATES then
                return nil
            end
            return cached
        end

        local decision = decisionForAddress(result, biomeKey, rowIndex, rewardAddress)
        local states = buildCandidateValueStates(rewardLegalityEngine, decision, rewardAddress, control)
        states = applyInvalidMarkerStates(result, biomeKey, rowIndex, rewardAddress, controlAlias, states)
        storeControlValueStates(result, biomeKey, rowIndex, rewardAddress, controlAlias, states)
        return states
    end

    return rewardState
end

return rewards
