local deps = ... or {}
local defaultRewardLegality = deps.rewardLegality
local routeTimeline = deps.timeline
local rewardItems = deps.rewardItems
local semantics = deps.semantics
if routeTimeline == nil then
    error("run_context requires route timeline")
end
if rewardItems == nil then
    error("run_context requires route reward items")
end
if semantics == nil then
    error("run_context requires reward semantics")
end

local runContext = {}
local EMPTY_LIST = {}
local GOD_LOOT_SOURCE_SCRATCH = {}

local function routeControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

local function routeGlobalControlName(routeKey)
    return "RouteGlobal" .. tostring(routeKey or "")
end

local function routeNpcControlName(routeKey)
    return "RouteNpcs" .. tostring(routeKey or "")
end

local function routeFeatureControlName(routeKey, featureKey)
    return "RouteFeature" .. tostring(featureKey or "") .. tostring(routeKey or "")
end

local function buildRouteInfo(routes)
    local routeInfoByRoute = {}
    local routeInfoByBiome = {}
    for _, route in ipairs(routes and routes.ordered or EMPTY_LIST) do
        local routeInfos = {}
        routeInfoByRoute[route.key] = routeInfos
        for index, routeBiomeKey in ipairs(route.biomes or EMPTY_LIST) do
            local info = {
                route = route,
                index = index,
                controlName = routeControlName(routeBiomeKey),
            }
            routeInfos[routeBiomeKey] = info
            if routeInfoByBiome[routeBiomeKey] == nil then
                routeInfoByBiome[routeBiomeKey] = info
            end
        end
    end
    return routeInfoByRoute, routeInfoByBiome
end

local function routeBiomeLookup(route)
    local routeLookup = {}
    for _, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        routeLookup[biomeKey] = true
    end
    return routeLookup
end

local function routeHasFeature(routeLookup, feature)
    for biomeKey in pairs(feature and feature.biomes or {}) do
        if routeLookup[biomeKey] then
            return true
        end
    end
    return false
end

local function buildRouteFeatureKeysByRoute(routes, features)
    local byRoute = {}
    for _, route in ipairs(routes and routes.ordered or EMPTY_LIST) do
        local routeLookup = routeBiomeLookup(route)
        local keys = {}
        for _, featureKey in ipairs(features and features.ordered or EMPTY_LIST) do
            local feature = features.byKey and features.byKey[featureKey] or nil
            if feature ~= nil and routeHasFeature(routeLookup, feature) then
                keys[#keys + 1] = feature.key
            end
        end
        byRoute[route.key] = keys
    end
    return byRoute
end

local function routeFeatureKeys(context, route)
    return context.routeFeatureKeysByRoute[route.key] or EMPTY_LIST
end

local function addGodLootSelection(selections, countedLookup, lootName)
    if lootName ~= nil and lootName ~= "" and countedLookup[lootName] and not selections[lootName] then
        selections[lootName] = true
        return 1
    end
    return 0
end

local function selectionCount(selections)
    local count = 0
    for _ in pairs(selections) do
        count = count + 1
    end
    return count
end

local function collectRewardGodLoot(item, countedLookup, selections, sourceScratch)
    local count = 0
    for _, source in ipairs(semantics.godLootSources(item, sourceScratch or GOD_LOOT_SOURCE_SCRATCH)) do
        count = count + addGodLootSelection(selections, countedLookup, source)
    end
    return count
end

local function collectRowGodLoot(row, countedLookup, selections, itemScratch, sourceScratch)
    local count = 0
    for _, item in ipairs(rewardItems.collect(row, itemScratch)) do
        count = count + collectRewardGodLoot(item, countedLookup, selections, sourceScratch)
    end
    return count
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

local function routeRewardLegalityState(context, routeKey)
    local state = context.rewardLegalityByRoute[routeKey]
    if state == nil then
        state = {
            dirty = true,
            result = nil,
        }
        context.rewardLegalityByRoute[routeKey] = state
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

local function variantKey(variant)
    return variant and (variant.key or variant.encounterName) or ""
end

local function targetKey(biomeKey, rowIndex, variant)
    if biomeKey == nil or rowIndex == nil then
        return ""
    end
    return tostring(biomeKey) .. ":" .. tostring(rowIndex) .. ":" .. tostring(variantKey(variant))
end

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

local function newTargetBucket()
    return {
        values = { "" },
        displayValues = {
            [""] = "Vanilla",
        },
        lookup = {},
        blockers = {},
        blockerLookup = {},
    }
end

local function targetBucket(targets, npcKey, biomeKey)
    local byNpc = biomeKey == nil and targets.byNpc or targets.byNpcBiome
    local npcBucket = byNpc[npcKey]
    if npcBucket == nil then
        npcBucket = biomeKey == nil and newTargetBucket() or {}
        byNpc[npcKey] = npcBucket
    end
    if biomeKey == nil then
        return npcBucket
    end

    local bucket = npcBucket[biomeKey]
    if bucket == nil then
        bucket = newTargetBucket()
        npcBucket[biomeKey] = bucket
    end
    return bucket
end

local function addTargetToBucket(bucket, candidate)
    if bucket.lookup[candidate.key] ~= nil then
        return
    end
    bucket.values[#bucket.values + 1] = candidate.key
    bucket.displayValues[candidate.key] = candidate.label
    bucket.lookup[candidate.key] = candidate
end

local function addNpcTarget(targets, candidate)
    addTargetToBucket(targetBucket(targets, candidate.npcKey), candidate)
    addTargetToBucket(targetBucket(targets, candidate.npcKey, candidate.biomeKey), candidate)
end

local function featureTargetBucket(targets, featureKey, biomeKey)
    local byFeature = biomeKey == nil and targets.byFeature or targets.byFeatureBiome
    local featureBucket = byFeature[featureKey]
    if featureBucket == nil then
        featureBucket = biomeKey == nil and newTargetBucket() or {}
        byFeature[featureKey] = featureBucket
    end
    if biomeKey == nil then
        return featureBucket
    end

    local bucket = featureBucket[biomeKey]
    if bucket == nil then
        bucket = newTargetBucket()
        featureBucket[biomeKey] = bucket
    end
    return bucket
end

local function addFeatureTarget(targets, candidate)
    addTargetToBucket(featureTargetBucket(targets, candidate.featureKey), candidate)
    addTargetToBucket(featureTargetBucket(targets, candidate.featureKey, candidate.biomeKey), candidate)
end

local function addBlockerToBucket(bucket, candidate)
    if bucket.blockerLookup[candidate.key] ~= nil then
        return
    end
    bucket.blockerLookup[candidate.key] = candidate
    bucket.blockers[#bucket.blockers + 1] = candidate
end

local function addFeatureBlocker(targets, candidate)
    addBlockerToBucket(featureTargetBucket(targets, candidate.featureKey), candidate)
    addBlockerToBucket(featureTargetBucket(targets, candidate.featureKey, candidate.biomeKey), candidate)
end

local function buildKeyLookup(values)
    local lookup = {}
    for _, value in ipairs(values or EMPTY_LIST) do
        lookup[value] = true
    end
    return lookup
end

local function timelineFeatureLabel(context, biomeKey, entry)
    local biome = context.biomeLookup and context.biomeLookup[biomeKey] or nil
    return tostring(biome and (biome.label or biome.key) or biomeKey)
        .. " "
        .. tostring(entry and (entry.label or entry.key) or "Timeline")
end

local function addTimelineFeatureBlockers(context, targets, entryContext)
    local biomeKey = entryContext and entryContext.biomeKey or nil
    local entry = entryContext and entryContext.entry or nil
    if targets == nil or entry == nil or entry.features == nil then
        return
    end

    for featureKey, enabled in pairs(entry.features) do
        if enabled == true then
            addFeatureBlocker(targets, {
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

local function valueInRange(range, value)
    if range == nil or value == nil then
        return true
    end
    if range.exact ~= nil and value ~= range.exact then
        return false
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.minExclusive ~= nil and value <= range.minExclusive then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then
        return false
    end
    return true
end

local function hasTag(tags, expected)
    for _, tag in ipairs(tags or EMPTY_LIST) do
        if tag == expected then
            return true
        end
    end
    return false
end

local function rowMatchesRequiredTag(row, requiredTag)
    if requiredTag == nil then
        return true
    end

    local option = row and row.option or nil
    local tags = option and (option.tags or option.roomTags or option.Tags) or nil
    if tags == nil then
        return true
    end
    return hasTag(tags, requiredTag)
end

local function rowConcreteRoomKey(row)
    local option = row and row.option or nil
    if option ~= nil and option.key ~= nil and option.key ~= "" then
        return option.key
    end
    if row ~= nil and row.roomKey ~= nil and row.roomKey ~= "" then
        return row.roomKey
    end
    return nil
end

local function rowHasConcreteRoom(row)
    return rowConcreteRoomKey(row) ~= nil
end

local function roleMatches(context, npc, row)
    context.npcRoleLookups = context.npcRoleLookups or {}
    local lookup = context.npcRoleLookups[npc.key]
    if lookup == nil then
        lookup = buildKeyLookup(npc.roleKeys)
        context.npcRoleLookups[npc.key] = lookup
    end
    return lookup[row and row.roleKey or ""] == true
end

local function rewardItemsConcreteStateForSource(items, sourceKind)
    local sawSource = false
    for _, item in ipairs(items or EMPTY_LIST) do
        if item.sourceKind == sourceKind then
            sawSource = true
            if not semantics.isConcrete(item) then
                return false
            end
        end
    end
    if sawSource then
        return true
    end
    return nil
end

local function rowRewardItems(context, row)
    context.rewardItemScratch = context.rewardItemScratch or {}
    return rewardItems.collect(row, context.rewardItemScratch)
end

local function rowPrimaryRewardItem(items)
    for _, item in ipairs(items or EMPTY_LIST) do
        if item.sourceKind == "row" then
            return item
        end
    end
    return nil
end

local function rowHasConcreteNpcReward(context, row, banned)
    if banned == nil then
        return true
    end

    local items = rowRewardItems(context, row)
    local cageState = rewardItemsConcreteStateForSource(items, "cage")
    if cageState ~= nil then
        return cageState
    end
    local encounterState = rewardItemsConcreteStateForSource(items, "encounter")
    if encounterState ~= nil then
        return encounterState
    end
    return semantics.isConcrete(rowPrimaryRewardItem(items))
end

local function rowHasBannedReward(context, row, banned)
    if banned == nil then
        return false
    end

    for _, item in ipairs(rowRewardItems(context, row)) do
        if item.sourceKind ~= "side" and semantics.hasBannedValue(item, banned) then
            return true
        end
    end
    return false
end

local function npcRewardBanLookup(context, npc)
    if npc.rewardBanSet == nil then
        return nil
    end

    context.npcRewardBanLookup = context.npcRewardBanLookup or {}
    local lookup = context.npcRewardBanLookup[npc.rewardBanSet]
    if lookup == nil then
        lookup = buildKeyLookup(context.npcs.rewardBanSets and context.npcs.rewardBanSets[npc.rewardBanSet])
        context.npcRewardBanLookup[npc.rewardBanSet] = lookup
    end
    return lookup
end

local function targetKindMatches(_npc, _biomeEntry, variant, row)
    local targetKind = variant.targetKind or "combatSlot"
    if targetKind == "combatSlot" then
        return row ~= nil and row.roleKey == "Combat"
    end
    return true
end

local function variantMatchesRow(context, npc, biomeEntry, variant, row)
    if row == nil or row.valid == false then
        return false
    end
    local banned = npcRewardBanLookup(context, npc)
    return rowHasConcreteRoom(row)
        and rowHasConcreteNpcReward(context, row, banned)
        and roleMatches(context, npc, row)
        and targetKindMatches(npc, biomeEntry, variant, row)
        and valueInRange(variant.biomeDepthCache, row.biomeDepthCache)
        and valueInRange(variant.biomeEncounterDepth, row.biomeEncounterDepth)
        and rowMatchesRequiredTag(row, biomeEntry.requiredRoomTag or variant.requiredRoomTag)
end

local function featureMatchesBiomePolicy(context, feature, biomeKey, roomHistoryDepth)
    local biome = context.biomeLookup and context.biomeLookup[biomeKey] or nil
    local policy = biome and biome.featurePolicies and biome.featurePolicies[feature.featureKey] or nil
    if policy == nil then
        return true
    end
    return valueInRange(policy.roomHistoryDepth, roomHistoryDepth)
end

local function featureMatchesRow(context, feature, biomeKey, row, roomHistoryDepth)
    if row == nil or row.valid == false then
        return false
    end
    if not rowHasConcreteRoom(row) then
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
        and sideRoom.enabled == true
        and sideRoom.roomKey ~= nil
        and feature.biomes
        and feature.biomes[biomeKey]
        and sideRoom.features
        and sideRoom.features[feature.featureKey] == true
        and featureMatchesBiomePolicy(context, feature, biomeKey, sideRoomHistoryDepth)
end

local function candidateLabel(context, biomeKey, row, variant)
    local biome = context.biomeLookup and context.biomeLookup[biomeKey] or nil
    local label = tostring(biome and (biome.label or biome.key) or biomeKey)
        .. " "
        .. tostring(row.slotLabel or ("Row " .. tostring(row.rowIndex)))
    local optionLabel = row.option and (row.option.label or row.option.key) or nil
    if optionLabel ~= nil then
        label = label .. " - " .. tostring(optionLabel)
    end
    if variant ~= nil and variant.label ~= nil then
        label = label .. " [" .. tostring(variant.label) .. "]"
    end
    return label
end

local function sideRoomCandidateLabel(context, biomeKey, row, sideRoom)
    return candidateLabel(context, biomeKey, row, nil)
        .. " / Side "
        .. tostring(sideRoom.sideIndex or "")
        .. " - "
        .. tostring(sideRoom.roomKey or "")
end

local function buildNpcTargets(context, routeKey)
    local targets = {
        byNpc = {},
        byNpcBiome = {},
    }
    local route = context.routes.lookup and context.routes.lookup[routeKey] or nil
    if route == nil then
        return targets
    end

    routeTimeline.walkRoute(route, {
        biomeLookup = context.biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return controlSnapshot(context, route.key, biomeKey)
        end,
        onRow = function(rowContext)
            local row = rowContext.row
            local biomeKey = rowContext.biomeKey
            for _, npcKey in ipairs(context.npcs.ordered or EMPTY_LIST) do
                local npc = context.npcs.byKey and context.npcs.byKey[npcKey] or nil
                local biomeEntry = npc and npc.biomes and npc.biomes[biomeKey] or nil
                local banned = npcRewardBanLookup(context, npc or {})
                if biomeEntry ~= nil and not rowHasBannedReward(context, row, banned) then
                    for _, variant in ipairs(biomeEntry.variants or EMPTY_LIST) do
                        if variantMatchesRow(context, npc, biomeEntry, variant, row) then
                            addNpcTarget(targets, {
                                key = targetKey(biomeKey, row.rowIndex, variant),
                                label = candidateLabel(context, biomeKey, row, variant),
                                npcKey = npc.key,
                                biomeKey = biomeKey,
                                biomeRouteIndex = rowContext.routeBiomeIndex,
                                rowIndex = row.rowIndex,
                                routeOrdinal = rowContext.routeOrdinal,
                                roomHistoryOrdinal = rowContext.roomHistoryOrdinal,
                                runDepthCache = rowContext.runDepthCache,
                                variantKey = variantKey(variant),
                                variantLabel = variant.label or variant.key or variant.encounterName,
                                encounterName = variant.encounterName,
                                row = row,
                            })
                        end
                    end
                end
            end
        end,
    })
    return targets
end

local function buildFeatureTargets(context, routeKey)
    local targets = {
        byFeature = {},
        byFeatureBiome = {},
    }
    local route = context.routes.lookup and context.routes.lookup[routeKey] or nil
    if route == nil then
        return targets
    end

    routeTimeline.walkRoute(route, {
        biomeLookup = context.biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return controlSnapshot(context, route.key, biomeKey)
        end,
        onRow = function(rowContext)
            local row = rowContext.row
            local biomeKey = rowContext.biomeKey
            for _, featureKey in ipairs(context.features.ordered or EMPTY_LIST) do
                local feature = context.features.byKey and context.features.byKey[featureKey] or nil
                if feature ~= nil and featureMatchesRow(context, feature, biomeKey, row, rowContext.roomHistoryDepth) then
                    addFeatureTarget(targets, {
                        key = featureTargetKey(biomeKey, row.rowIndex),
                        label = candidateLabel(context, biomeKey, row, nil),
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
                        row = row,
                    })
                end
                for _, sideRoom in ipairs(row and row.sideRooms or EMPTY_LIST) do
                    local sideRoomContext = routeTimeline.sideRoomContext(rowContext, sideRoom)
                    if feature ~= nil
                        and featureMatchesSideRoom(context, feature, biomeKey, sideRoom, sideRoomContext.roomHistoryDepth)
                    then
                        local sideSuffix = "side" .. tostring(sideRoom.sideIndex or "")
                        addFeatureTarget(targets, {
                            key = featureTargetKey(biomeKey, row.rowIndex, sideSuffix),
                            label = sideRoomCandidateLabel(context, biomeKey, row, sideRoom),
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
                            row = row,
                            sideIndex = sideRoom.sideIndex,
                            sideRoom = sideRoom,
                        })
                    end
                end
            end
        end,
        onAfterBiomeEntry = function(entryContext)
            addTimelineFeatureBlockers(context, targets, entryContext)
        end,
    })
    return targets
end

local function newRewardLegalityResult()
    return {
        invalidRows = {},
        byBiomeRow = {},
    }
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
        rewardLegalityEngine = opts.rewardLegality or defaultRewardLegality,
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

        if countedLookup == nil or selections == nil then
            return selections
        end

        local info = self:routeInfo(routeKey, biomeKey)
        if info == nil then
            return selections
        end

        local count = selectionCount(selections)
        self.rewardGodLootItemScratch = self.rewardGodLootItemScratch or {}
        self.rewardGodLootSourceScratch = self.rewardGodLootSourceScratch or {}
        for index = 1, info.index - 1 do
            local snapshot = controlSnapshot(self, info.route.key, info.route.biomes[index])
            for _, row in ipairs(snapshot and snapshot.rows or EMPTY_LIST) do
                count = count + collectRowGodLoot(
                    row,
                    countedLookup,
                    selections,
                    self.rewardGodLootItemScratch,
                    self.rewardGodLootSourceScratch
                )
                if stopAtCount ~= nil and count >= stopAtCount then
                    return selections
                end
            end
        end
        return selections
    end

    function context:npcTargets(routeKey)
        local state = routeNpcTargetsState(self, routeKey)
        if state.dirty or state.targets == nil then
            if self:isLayerConfigured(routeKey, "npcs") then
                state.targets = buildNpcTargets(self, routeKey)
            else
                state.targets = {
                    byNpc = {},
                    byNpcBiome = {},
                }
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
                state.targets = buildFeatureTargets(self, routeKey)
            else
                state.targets = {
                    byFeature = {},
                    byFeatureBiome = {},
                }
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
        local state = routeRewardLegalityState(self, routeKey)
        if state.dirty or state.result == nil then
            if self:isLayerConfigured(routeKey, "rewards") and self.rewardLegalityEngine ~= nil then
                local previousRewardLegalityBuilding = self.rewardLegalityBuilding
                self.rewardLegalityBuilding = true
                state.result = self.rewardLegalityEngine.evaluate(self, routeKey, {
                    routeControlName = routeControlName,
                    snapshotForBiome = function(resolvedRouteKey, biomeKey)
                        return controlSnapshot(self, resolvedRouteKey, biomeKey)
                    end,
                })
                self.rewardLegalityBuilding = previousRewardLegalityBuilding
            else
                state.result = newRewardLegalityResult()
            end
            state.dirty = false
        end
        return state.result
    end

    function context:rewardRowValidation(routeKey, biomeKey, rowIndex)
        if self.snapshotBuilding or self.rewardLegalityBuilding then
            return nil
        end

        local result = self:rewardLegality(routeKey)
        local byRow = result.byBiomeRow[biomeKey]
        return byRow and byRow[rowIndex] or nil
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
                    code = "missing_control",
                    message = "Missing route control: " .. tostring(biomeKey),
                }
            else
                for _, invalidRow in ipairs(snapshot.invalidRows or EMPTY_LIST) do
                    invalidRows[#invalidRows + 1] = {
                        biomeKey = biomeKey,
                        controlName = snapshot.controlName,
                        rowIndex = invalidRow.rowIndex,
                        routeOrdinal = invalidRow.routeOrdinal,
                        code = invalidRow.code,
                        message = invalidRow.message,
                    }
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
                    invalidRows[#invalidRows + 1] = {
                        controlName = npcSnapshot.controlName,
                        rowIndex = invalidRow.rowIndex,
                        code = invalidRow.code,
                        message = invalidRow.message,
                    }
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
                        invalidRows[#invalidRows + 1] = {
                            controlName = featureSnapshot.controlName,
                            rowIndex = invalidRow.rowIndex,
                            code = invalidRow.code,
                            message = invalidRow.message,
                        }
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

runContext.collectRewardGodLoot = collectRewardGodLoot
runContext.collectRowGodLoot = collectRowGodLoot

return runContext
