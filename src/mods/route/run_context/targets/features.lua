local deps = ... or {}
local routeTimeline = deps.timeline
local common = deps.common

local featureTargets = {}
local EMPTY_LIST = common.EMPTY_LIST

local function featureTargetRowIndex(rowIndex, suffix)
    if suffix == nil or suffix == "" then
        return tostring(rowIndex or "")
    end
    return tostring(rowIndex or "") .. "." .. tostring(suffix)
end

local function featureTargetKey(biomeKey, rowIndex, suffix)
    if biomeKey == nil or rowIndex == nil then
        return ""
    end
    return tostring(biomeKey) .. ":" .. featureTargetRowIndex(rowIndex, suffix)
end

local function addFeatureTarget(result, candidate)
    common.addTarget(result, "byFeature", "byFeatureBiome", candidate.featureKey, candidate.biomeKey, candidate)
end

local function addFeatureBlocker(result, candidate)
    common.addBlocker(result, "byFeature", "byFeatureBiome", candidate.featureKey, candidate.biomeKey, candidate)
end

local function timelineFeatureLabel(context, biomeKey, entry)
    return common.biomeLabel(context, biomeKey)
        .. " "
        .. tostring(entry and (entry.label or entry.key) or "Timeline")
end

local function addTimelineFeatureBlockers(context, routeKey, result, entryContext)
    local biomeKey = entryContext and entryContext.biomeKey or nil
    local entry = entryContext and entryContext.entry or nil
    if result == nil or entry == nil or entry.features == nil then
        return
    end

    for featureKey, enabled in pairs(entry.features) do
        if enabled == true and context:isFeatureConfigured(routeKey, featureKey) then
            addFeatureBlocker(result, {
                key = featureTargetKey(biomeKey, "timeline-" .. tostring(entry.key or featureKey)),
                label = timelineFeatureLabel(context, biomeKey, entry),
                featureKey = featureKey,
                biomeKey = biomeKey,
                hidden = true,
                roomHistoryOrdinal = entryContext.roomHistoryOrdinal,
                runDepthCache = entryContext.runDepthCache,
            })
        end
    end
end

local function featureMatchesBiomePolicy(context, feature, biomeKey, roomHistoryDepth)
    local biome = context.biomeLookup and context.biomeLookup[biomeKey] or nil
    local policy = biome and biome.featurePolicies and biome.featurePolicies[feature.featureKey] or nil
    if policy == nil then
        return true
    end
    return common.valueInRange(policy.roomHistoryDepth, roomHistoryDepth)
end

local function featureMatchesRow(context, feature, biomeKey, row, roomHistoryDepth)
    if row == nil or row.valid == false then
        return false
    end
    if not common.rowHasConcreteRoom(row) then
        return false
    end
    if not (feature.biomes and feature.biomes[biomeKey]) then
        return false
    end
    if not (row.features and row.features[feature.featureKey] == true) then
        return false
    end
    return featureMatchesBiomePolicy(context, feature, biomeKey, roomHistoryDepth)
end

local function featureMatchesSideRoom(context, feature, biomeKey, sideRoom, sideRoomHistoryDepth)
    return sideRoom ~= nil
        and sideRoom.entered == true
        and sideRoom.roomKey ~= nil
        and feature.biomes
        and feature.biomes[biomeKey]
        and sideRoom.features
        and sideRoom.features[feature.featureKey] == true
        and featureMatchesBiomePolicy(context, feature, biomeKey, sideRoomHistoryDepth)
end

function featureTargets.emptyTargets()
    return {
        byFeature = {},
        byFeatureBiome = {},
    }
end

function featureTargets.buildTargets(context, routeKey)
    local result = featureTargets.emptyTargets()
    local route = context.configuredRoute and context:configuredRoute(routeKey)
        or context.routes.lookup and context.routes.lookup[routeKey]
        or nil
    if route == nil then
        return result
    end

    routeTimeline.walkRoute(route, {
        biomeLookup = context.biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return context:controlSnapshot(route.key, biomeKey)
        end,
        onRow = function(rowContext)
            local row = rowContext.row
            local biomeKey = rowContext.biomeKey
            for _, featureKey in ipairs(context.features.ordered or EMPTY_LIST) do
                local feature = context.features.byKey and context.features.byKey[featureKey] or nil
                if feature ~= nil
                    and context:isFeatureConfigured(routeKey, feature.key)
                    and featureMatchesRow(context, feature, biomeKey, row, rowContext.roomHistoryDepth)
                then
                    addFeatureTarget(result, {
                        key = featureTargetKey(biomeKey, row.rowIndex),
                        label = common.candidateLabel(context, biomeKey, row, nil),
                        slotKey = feature.key,
                        featureKey = feature.featureKey,
                        biomeKey = biomeKey,
                        biomeRouteIndex = rowContext.routeBiomeIndex,
                        rowIndex = row.rowIndex,
                        targetRowIndex = featureTargetRowIndex(row.rowIndex),
                        routeOrdinal = rowContext.routeOrdinal,
                        roomHistoryOrdinal = rowContext.roomHistoryOrdinal,
                        runDepthCache = rowContext.runDepthCache,
                        roomHistoryDepth = rowContext.roomHistoryDepth,
                        roomKey = row.roomKey,
                        row = row,
                    })
                end
                for _, sideRoom in ipairs(row and row.sideRooms or EMPTY_LIST) do
                    local sideRoomContext = routeTimeline.sideRoomContext(rowContext, sideRoom)
                    if feature ~= nil
                        and context:isFeatureConfigured(routeKey, feature.key)
                        and featureMatchesSideRoom(context, feature, biomeKey, sideRoom, sideRoomContext.roomHistoryDepth)
                    then
                        local sideSuffix = "side" .. tostring(sideRoom.sideIndex or "")
                        addFeatureTarget(result, {
                            key = featureTargetKey(biomeKey, row.rowIndex, sideSuffix),
                            label = common.sideRoomCandidateLabel(context, biomeKey, row, sideRoom),
                            slotKey = feature.key,
                            featureKey = feature.featureKey,
                            biomeKey = biomeKey,
                            biomeRouteIndex = rowContext.routeBiomeIndex,
                            rowIndex = row.rowIndex,
                            targetRowIndex = featureTargetRowIndex(row.rowIndex, sideSuffix),
                            routeOrdinal = rowContext.routeOrdinal,
                            roomHistoryOrdinal = sideRoomContext.roomHistoryOrdinal,
                            runDepthCache = sideRoomContext.runDepthCache,
                            roomHistoryDepth = sideRoomContext.roomHistoryDepth,
                            roomKey = sideRoom.roomKey,
                            parentRoomKey = row.roomKey,
                            row = row,
                            sideIndex = sideRoom.sideIndex,
                            sideRoom = sideRoom,
                        })
                    end
                end
            end
        end,
        onAfterBiomeEntry = function(entryContext)
            addTimelineFeatureBlockers(context, routeKey, result, entryContext)
        end,
    })
    return result
end

return featureTargets
