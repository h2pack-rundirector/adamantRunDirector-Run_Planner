local deps = ... or {}
local routeTimeline = deps.timeline
local biomeLookup = deps.biomeLookup or {}

local executionPlan = {}

local EMPTY_LIST = {}
local VANILLA_ROLE_KEY = "Vanilla"

local function copyList(source)
    local copy = {}
    for index, value in ipairs(source or EMPTY_LIST) do
        copy[index] = value
    end
    return copy
end

local function copyMap(source)
    if source == nil then
        return nil
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function copyTree(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = copyTree(value)
    end
    return copy
end

local function compactRewardPicks(source)
    local picks = {}
    for index, pick in ipairs(source or EMPTY_LIST) do
        picks[index] = {
            key = pick.key,
            kind = pick.kind,
            alias = pick.alias,
            storageAlias = pick.storageAlias,
            value = pick.value,
            rewardStore = pick.rewardStore,
        }
    end
    return picks
end

local function compactRewardItem(item)
    return {
        address = item.address,
        sourceKind = item.sourceKind,
        sourceIndex = item.sourceIndex,
        rowIndex = item.rowIndex,
        routeOrdinal = item.routeOrdinal,
        kind = item.rewardKind or "vanilla",
        rewards = copyList(item.rewards),
        loot = copyList(item.rewardLoot),
        picks = compactRewardPicks(item.rewardPicks),
        fixedRewardType = item.fixedRewardType,
        rewardStore = item.rewardStore,
        shopProfile = item.shopProfile,
        rewardSourceCount = item.rewardSourceCount,
        valid = item.valid,
        rewardChoiceGroup = item.rewardChoiceGroup,
        rewardAliasOffset = item.rewardAliasOffset,
    }
end

local function hasConfiguredRoom(row)
    return row ~= nil
        and row.valid ~= false
        and row.roleKey ~= nil
        and row.roleKey ~= ""
        and row.roleKey ~= VANILLA_ROLE_KEY
        and row.roomKey ~= nil
        and row.roomKey ~= ""
end

local function isRoutableRoom(row)
    local kind = row and row.slotKind
    return kind == "biomeRow"
        or kind == "preboss"
end

local function compactRewardItems(source)
    local items = {}
    for index, item in ipairs(source or EMPTY_LIST) do
        items[index] = compactRewardItem(item)
    end
    return items
end

local function compactSideRoom(entry)
    return {
        rowIndex = entry.rowIndex,
        routeOrdinal = entry.routeOrdinal,
        biomeDepthCache = entry.biomeDepthCache,
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepth = entry.biomeEncounterDepth,
        biomeEncounterDepthMin = entry.biomeEncounterDepthMin,
        biomeEncounterDepthMax = entry.biomeEncounterDepthMax,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
        biomeEncounterDepthCostMin = entry.biomeEncounterDepthCostMin,
        biomeEncounterDepthCostMax = entry.biomeEncounterDepthCostMax,
        legIndex = entry.legIndex,
        cageIndex = entry.cageIndex,
        sideIndex = entry.sideIndex,
        roomKey = entry.roomKey,
        doorId = entry.doorId,
        modeKey = entry.modeKey,
        enabled = entry.enabled,
        rewardStore = entry.rewardStore,
        features = copyMap(entry.features),
    }
end

local function compactSideRooms(source)
    local entries = {}
    for index, entry in ipairs(source or EMPTY_LIST) do
        entries[index] = compactSideRoom(entry)
    end
    return entries
end

local function compactRoomRow(row)
    return {
        rowIndex = row.rowIndex,
        routeOrdinal = row.routeOrdinal,
        roomHistoryOrdinal = row.roomHistoryOrdinal,
        runDepthCache = row.runDepthCache,
        runEncounterDepth = row.runEncounterDepth,
        runEncounterDepthMin = row.runEncounterDepthMin,
        runEncounterDepthMax = row.runEncounterDepthMax,
        biomeDepthCache = row.biomeDepthCache,
        biomeDepthCacheCost = row.biomeDepthCacheCost,
        biomeEncounterDepth = row.biomeEncounterDepth,
        biomeEncounterDepthMin = row.biomeEncounterDepthMin,
        biomeEncounterDepthMax = row.biomeEncounterDepthMax,
        biomeEncounterDepthCost = row.biomeEncounterDepthCost,
        biomeEncounterDepthCostMin = row.biomeEncounterDepthCostMin,
        biomeEncounterDepthCostMax = row.biomeEncounterDepthCostMax,
        slotKind = row.slotKind,
        isBiomeEntry = row.isBiomeEntry == true,
        roomKey = row.roomKey,
        roomOfferCount = row.roomOfferCount,
        hubDoorId = row.hubDoorId,
        roleKey = row.roleKey,
        optionKey = row.optionKey,
        variantKey = row.variantKey,
        cageRewardCount = row.cageRewardCount,
        encounterPolicyKey = row.encounterPolicyKey,
        realCombatCount = row.realCombatCount,
        roomHistoryCost = row.roomHistoryCost,
        roomHistoryIdentity = row.roomHistoryIdentity,
        countsGoalReward = row.countsGoalReward,
        countsNonGoalReward = row.countsNonGoalReward,
        offerTopology = copyTree(row.offerTopology),
        features = copyMap(row.features),
        rewardItems = compactRewardItems(row.rewardItems),
        sideRooms = compactSideRooms(row.sideRooms),
    }
end

local function rowsByBiome(snapshot)
    local byBiome = {}
    for _, biomeSnapshot in ipairs(snapshot and snapshot.biomes or EMPTY_LIST) do
        if biomeSnapshot.biomeKey ~= nil then
            byBiome[biomeSnapshot.biomeKey] = biomeSnapshot
        end
    end
    return byBiome
end

local function routeForSnapshot(snapshot)
    local biomes = {}
    for _, biomeSnapshot in ipairs(snapshot and snapshot.biomes or EMPTY_LIST) do
        if biomeSnapshot.biomeKey ~= nil then
            biomes[#biomes + 1] = biomeSnapshot.biomeKey
        end
    end
    return {
        key = snapshot and snapshot.routeKey or nil,
        biomes = biomes,
    }
end

local function annotateRouteCounters(snapshot)
    if routeTimeline == nil then
        return
    end

    local snapshotByBiome = rowsByBiome(snapshot)
    routeTimeline.walkRoute(routeForSnapshot(snapshot), {
        biomeLookup = biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return snapshotByBiome[biomeKey]
        end,
        onRow = function(context)
            local row = context.row
            if row ~= nil then
                row.roomHistoryOrdinal = context.roomHistoryOrdinal
                row.runDepthCache = context.runDepthCache
                row.runEncounterDepth = context.runEncounterDepth
                row.runEncounterDepthMin = context.runEncounterDepthMin
                row.runEncounterDepthMax = context.runEncounterDepthMax
            end
        end,
    })
end

local function biomeDepthCacheBucket(biome, biomeDepthCache)
    local bucket = biome.plannedByBiomeDepthCache[biomeDepthCache]
    if bucket == nil then
        bucket = {
            biomeDepthCache = biomeDepthCache,
            rows = {},
            byRowIndex = {},
            byRoomKey = {},
            primary = nil,
        }
        biome.plannedByBiomeDepthCache[biomeDepthCache] = bucket
    end
    return bucket
end

local function routableBiomeDepthCacheBucket(biome, biomeDepthCache)
    local bucket = biome.plannedRoutableByBiomeDepthCache[biomeDepthCache]
    if bucket == nil then
        bucket = {
            biomeDepthCache = biomeDepthCache,
            rows = {},
            byRowIndex = {},
            byRoomKey = {},
            primary = nil,
        }
        biome.plannedRoutableByBiomeDepthCache[biomeDepthCache] = bucket
    end
    return bucket
end

local function roomBucket(biome, roomKey)
    local bucket = biome.plannedByRoomKey[roomKey]
    if bucket == nil then
        bucket = {
            roomKey = roomKey,
            rows = {},
            byRowIndex = {},
            primary = nil,
        }
        biome.plannedByRoomKey[roomKey] = bucket
        biome.reservedRoomKeys[roomKey] = bucket
    end
    return bucket
end

local function routeOrdinalRoomBucket(bucket, roomKey)
    local room = bucket.byRoomKey[roomKey]
    if room == nil then
        room = {
            roomKey = roomKey,
            rows = {},
            byRowIndex = {},
            primary = nil,
        }
        bucket.byRoomKey[roomKey] = room
    end
    return room
end

local function addPlannedToBucket(bucket, planned)
    if bucket.primary == nil then
        bucket.primary = planned
    end
    bucket.rows[#bucket.rows + 1] = planned
    bucket.byRowIndex[planned.rowIndex] = planned
end

local function reservationBucket(globalReservations, roomKey)
    local bucket = globalReservations[roomKey]
    if bucket == nil then
        bucket = {
            roomKey = roomKey,
            entries = {},
            primary = nil,
        }
        globalReservations[roomKey] = bucket
    end
    return bucket
end

local function addGlobalReservation(globalReservations, biomeKey, planned)
    local bucket = reservationBucket(globalReservations, planned.roomKey)
    local entry = {
        biomeKey = biomeKey,
        rowIndex = planned.rowIndex,
        routeOrdinal = planned.routeOrdinal,
        biomeDepthCache = planned.biomeDepthCache,
        roomKey = planned.roomKey,
        slotKind = planned.slotKind,
        roleKey = planned.roleKey,
        optionKey = planned.optionKey,
    }
    if bucket.primary == nil then
        bucket.primary = entry
    end
    bucket.entries[#bucket.entries + 1] = entry
end

local function addPlannedRoom(biome, globalReservations, row)
    local planned = compactRoomRow(row)
    biome.plannedRows[#biome.plannedRows + 1] = planned
    biome.plannedByRowIndex[planned.rowIndex] = planned
    if planned.biomeDepthCache ~= nil then
        local bucket = biomeDepthCacheBucket(biome, planned.biomeDepthCache)
        addPlannedToBucket(bucket, planned)
        addPlannedToBucket(routeOrdinalRoomBucket(bucket, planned.roomKey), planned)
        if isRoutableRoom(planned) then
            local routeBucket = routableBiomeDepthCacheBucket(biome, planned.biomeDepthCache)
            addPlannedToBucket(routeBucket, planned)
            addPlannedToBucket(routeOrdinalRoomBucket(routeBucket, planned.roomKey), planned)
        end
    end
    if planned.isBiomeEntry and biome.plannedEntryRoom == nil then
        biome.plannedEntryRoom = planned
    end

    addPlannedToBucket(roomBucket(biome, planned.roomKey), planned)
    addGlobalReservation(globalReservations, biome.biomeKey, planned)
end

local function compileBiome(snapshot, globalReservations)
    local biome = {
        biomeKey = snapshot.biomeKey,
        adapter = snapshot.adapter,
        plannedRows = {},
        plannedByRowIndex = {},
        plannedByBiomeDepthCache = {},
        plannedRoutableByBiomeDepthCache = {},
        plannedEntryRoom = nil,
        plannedByRoomKey = {},
        reservedRoomKeys = {},
    }

    for _, row in ipairs(snapshot.rows or EMPTY_LIST) do
        if hasConfiguredRoom(row) then
            addPlannedRoom(biome, globalReservations, row)
        end
    end
    return biome
end

local function compactTarget(target)
    if target == nil then
        return nil
    end

    return {
        key = target.key,
        slotKey = target.slotKey,
        featureKey = target.featureKey,
        npcKey = target.npcKey,
        biomeKey = target.biomeKey,
        biomeRouteIndex = target.biomeRouteIndex,
        rowIndex = target.rowIndex,
        targetRowIndex = target.targetRowIndex,
        routeOrdinal = target.routeOrdinal,
        roomHistoryOrdinal = target.roomHistoryOrdinal,
        roomHistoryDepth = target.roomHistoryDepth,
        roomKey = target.roomKey,
        parentRoomKey = target.parentRoomKey,
        sideIndex = target.sideIndex,
        variantKey = target.variantKey,
        encounterName = target.encounterName,
    }
end

local function compactNpcRow(row)
    return {
        rowIndex = row.rowIndex,
        slotKey = row.slotKey,
        npcKey = row.npcKey,
        groupKey = row.groupKey,
        disabled = row.disabled == true,
        mode = row.mode,
        biomeKey = row.biomeKey,
        targetRowIndex = row.targetRowIndex,
        variantKey = row.variantKey,
        targetKey = row.targetKey,
        target = compactTarget(row.target),
    }
end

local function compactFeatureRow(row)
    return {
        rowIndex = row.rowIndex,
        slotKey = row.slotKey,
        featureKey = row.featureKey,
        biomeKey = row.biomeKey,
        targetRowIndex = row.targetRowIndex,
        targetKey = row.targetKey,
        target = compactTarget(row.target),
    }
end

local function hasSelectedTarget(row)
    return row ~= nil
        and row.valid ~= false
        and row.targetKey ~= nil
        and row.targetKey ~= ""
end

local function hasDisabledRow(row)
    return row ~= nil
        and row.valid ~= false
        and row.disabled == true
end

local function compileRows(rows, compactRow)
    local compiled = {}
    local bySlotKey = {}
    for _, row in ipairs(rows or EMPTY_LIST) do
        if hasSelectedTarget(row) or hasDisabledRow(row) then
            local item = compactRow(row)
            compiled[#compiled + 1] = item
            if item.slotKey ~= nil then
                bySlotKey[item.slotKey] = item
            end
        end
    end
    return {
        rows = compiled,
        bySlotKey = bySlotKey,
    }
end

local function compileFeatures(featureSnapshots)
    local features = {
        byFeatureKey = {},
    }
    for _, snapshot in ipairs(featureSnapshots or EMPTY_LIST) do
        local featureKey = nil
        local compiled = compileRows(snapshot and snapshot.rows or EMPTY_LIST, compactFeatureRow)
        if compiled.rows[1] ~= nil then
            featureKey = compiled.rows[1].featureKey
        end
        if featureKey ~= nil then
            features.byFeatureKey[featureKey] = compiled
        end
    end
    return features
end

function executionPlan.compile(snapshot, opts)
    opts = opts or {}
    annotateRouteCounters(snapshot)

    local plan = {
        routeKey = snapshot.routeKey,
        label = snapshot.label,
        layers = opts.layers or {},
        biomeOrder = {},
        biomes = {},
        reservedRoomKeys = {},
        npcs = compileRows(snapshot.npcs and snapshot.npcs.rows or EMPTY_LIST, compactNpcRow),
        features = compileFeatures(snapshot.features),
    }

    for _, biomeSnapshot in ipairs(snapshot.biomes or EMPTY_LIST) do
        if biomeSnapshot ~= nil and biomeSnapshot.biomeKey ~= nil then
            local biome = compileBiome(biomeSnapshot, plan.reservedRoomKeys)
            plan.biomeOrder[#plan.biomeOrder + 1] = biome.biomeKey
            plan.biomes[biome.biomeKey] = biome
        end
    end
    return plan
end

executionPlan.hasConfiguredRoom = hasConfiguredRoom

return executionPlan
