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

local function compactReward(row)
    return {
        kind = row.rewardKind or "vanilla",
        rewards = copyList(row.rewards),
        loot = copyList(row.rewardLoot),
        picks = compactRewardPicks(row.rewardPicks),
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
    return kind == "route"
        or kind == "preboss"
        or kind == "clockworkRoute"
        or kind == "fieldsPick"
        or kind == "pylonPick"
end

local function compactRewardEntry(entry)
    return {
        rowIndex = entry.rowIndex,
        coordinate = entry.coordinate,
        biomeDepthCache = entry.biomeDepthCache,
        biomeDepthCacheCost = entry.biomeDepthCacheCost,
        biomeEncounterDepth = entry.biomeEncounterDepth,
        biomeEncounterDepthCost = entry.biomeEncounterDepthCost,
        legIndex = entry.legIndex,
        cageIndex = entry.cageIndex,
        sideIndex = entry.sideIndex,
        roomKey = entry.roomKey,
        doorId = entry.doorId,
        modeKey = entry.modeKey,
        enabled = entry.enabled,
        rewardStore = entry.rewardStore,
        features = copyMap(entry.features),
        reward = compactReward(entry),
    }
end

local function compactRewardEntries(source)
    local entries = {}
    for index, entry in ipairs(source or EMPTY_LIST) do
        entries[index] = compactRewardEntry(entry)
    end
    return entries
end

local function compactRoomRow(row)
    return {
        rowIndex = row.rowIndex,
        coordinate = row.coordinate,
        biomeDepthCache = row.biomeDepthCache,
        biomeDepthCacheCost = row.biomeDepthCacheCost,
        biomeEncounterDepth = row.biomeEncounterDepth,
        biomeEncounterDepthCost = row.biomeEncounterDepthCost,
        slotKind = row.slotKind,
        isBiomeEntry = row.isBiomeEntry == true,
        roomKey = row.roomKey,
        branchKey = row.branchKey,
        roleKey = row.roleKey,
        optionKey = row.optionKey,
        variantKey = row.variantKey,
        encounterPolicyKey = row.encounterPolicyKey,
        realCombatCount = row.realCombatCount,
        roomHistoryCost = row.roomHistoryCost,
        roomHistoryIdentity = row.roomHistoryIdentity,
        countsGoalReward = row.countsGoalReward,
        countsNonGoalReward = row.countsNonGoalReward,
        features = copyMap(row.features),
        reward = compactReward(row),
        sideRooms = compactRewardEntries(row.sideRooms),
        cageRewards = compactRewardEntries(row.cageRewards),
        encounterRewardLegs = compactRewardEntries(row.encounterRewardLegs),
    }
end

local function biomeDepthCacheBucket(biome, biomeDepthCache)
    local bucket = biome.plannedByBiomeDepthCache[biomeDepthCache]
    if bucket == nil then
        bucket = {
            biomeDepthCache = biomeDepthCache,
            rows = {},
            byRowIndex = {},
            byRoomKey = {},
            byBranchKey = {},
            branchKeys = {},
            primary = nil,
            branchGroup = false,
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
            byBranchKey = {},
            branchKeys = {},
            primary = nil,
            branchGroup = false,
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
            byBranchKey = {},
            branchKeys = {},
            primary = nil,
        }
        biome.plannedByRoomKey[roomKey] = bucket
        biome.reservedRoomKeys[roomKey] = bucket
    end
    return bucket
end

local function coordinateRoomBucket(bucket, roomKey)
    local room = bucket.byRoomKey[roomKey]
    if room == nil then
        room = {
            roomKey = roomKey,
            rows = {},
            byRowIndex = {},
            byBranchKey = {},
            branchKeys = {},
            primary = nil,
        }
        bucket.byRoomKey[roomKey] = room
    end
    return room
end

local function addBranch(bucket, planned)
    local branchKey = planned.branchKey
    if branchKey == nil or branchKey == "" then
        return
    end
    if bucket.byBranchKey[branchKey] == nil then
        bucket.branchKeys[#bucket.branchKeys + 1] = branchKey
    end
    bucket.byBranchKey[branchKey] = planned
end

local function addPlannedToBucket(bucket, planned)
    if bucket.primary == nil then
        bucket.primary = planned
    end
    bucket.rows[#bucket.rows + 1] = planned
    bucket.byRowIndex[planned.rowIndex] = planned
    addBranch(bucket, planned)
    if #bucket.rows > 1 or planned.branchKey ~= nil then
        bucket.branchGroup = true
    end
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
        coordinate = planned.coordinate,
        biomeDepthCache = planned.biomeDepthCache,
        roomKey = planned.roomKey,
        slotKind = planned.slotKind,
        branchKey = planned.branchKey,
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
        addPlannedToBucket(coordinateRoomBucket(bucket, planned.roomKey), planned)
        if isRoutableRoom(planned) then
            local routeBucket = routableBiomeDepthCacheBucket(biome, planned.biomeDepthCache)
            addPlannedToBucket(routeBucket, planned)
            addPlannedToBucket(coordinateRoomBucket(routeBucket, planned.roomKey), planned)
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

local function compileRows(rows, compactRow)
    local compiled = {}
    local bySlotKey = {}
    for _, row in ipairs(rows or EMPTY_LIST) do
        if hasSelectedTarget(row) then
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
