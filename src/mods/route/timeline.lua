local timeline = {}

local DEFAULT_ROOM_HISTORY_COST = 1
local BIOME_ENCOUNTER_DEPTH_START = 1
local EMPTY_LIST = {}

local function numericCost(value, fallback)
    if value == nil then
        return fallback
    end
    local cost = math.floor(tonumber(value) or fallback or DEFAULT_ROOM_HISTORY_COST)
    if cost < 0 then
        return 0
    end
    return cost
end

local function slotIdentity(slot)
    if slot == nil then
        return nil
    end
    if slot.roomHistoryIdentity ~= nil then
        return slot.roomHistoryIdentity
    end
    if slot.roomKey ~= nil then
        return tostring(slot.kind or "slot") .. ":" .. tostring(slot.roomKey)
    end
    return nil
end

local function configuredSlotCost(instance, slot)
    local config = instance.biome and instance.biome.timeline or {}
    local kindCosts = config.roomHistoryCostBySlotKind or {}
    if slot ~= nil and slot.roomHistoryCost ~= nil then
        return numericCost(slot.roomHistoryCost, DEFAULT_ROOM_HISTORY_COST)
    end
    if slot ~= nil and kindCosts[slot.kind] ~= nil then
        return numericCost(kindCosts[slot.kind], DEFAULT_ROOM_HISTORY_COST)
    end
    return numericCost(config.defaultRoomHistoryCost, DEFAULT_ROOM_HISTORY_COST)
end

function timeline.applyRouteSlots(instance)
    local seenIdentity = {}
    for _, slot in ipairs(instance.routeSlots or {}) do
        local cost = configuredSlotCost(instance, slot)
        local identity = slotIdentity(slot)
        if identity ~= nil then
            if seenIdentity[identity] then
                cost = 0
            else
                seenIdentity[identity] = true
            end
        end
        slot.roomHistoryCost = cost
        slot.roomHistoryIdentity = identity
    end
end

function timeline.afterBiome(instance)
    return instance.biome
        and instance.biome.timeline
        and instance.biome.timeline.afterBiome
        or {}
end

function timeline.entryCost(entry)
    return numericCost(entry and entry.roomHistoryCost, DEFAULT_ROOM_HISTORY_COST)
end

function timeline.rowRoomHistoryCost(row)
    return numericCost(row and row.roomHistoryCost, DEFAULT_ROOM_HISTORY_COST)
end

function timeline.rowBiomeEncounterDepthCost(row)
    if row == nil then
        return 0
    end
    if row.biomeEncounterDepthCost ~= nil then
        return numericCost(row.biomeEncounterDepthCost, 0)
    end
    return nil
end

function timeline.runDepthCache(roomHistoryOrdinal)
    return 1 + (roomHistoryOrdinal or 0)
end

function timeline.biomeDepthCacheStart(instance)
    local slotLayout = instance and instance.biome and instance.biome.slotLayout or nil
    if slotLayout == nil then
        return 0
    end
    if slotLayout.biomeDepthCacheStart ~= nil then
        return numericCost(slotLayout.biomeDepthCacheStart, 0)
    end
    local depthRange = slotLayout.depthRange
    if depthRange ~= nil and depthRange.min ~= nil then
        return numericCost(depthRange.min, 0)
    end
    return 0
end

local function nextScalarCounter(previous, valueKey, costKey, startValue)
    if previous == nil then
        return startValue
    end
    if previous[valueKey] == nil or previous[costKey] == nil then
        return nil
    end
    return previous[valueKey] + previous[costKey]
end

function timeline.nextBiomeRowCounters(instance, previous, target)
    local biomeDepthCache = nextScalarCounter(
        previous,
        "biomeDepthCache",
        "biomeDepthCacheCost",
        timeline.biomeDepthCacheStart(instance)
    )
    local biomeEncounterDepth = nextScalarCounter(
        previous,
        "biomeEncounterDepth",
        "biomeEncounterDepthCost",
        BIOME_ENCOUNTER_DEPTH_START
    )
    target = target or {}
    target.biomeDepthCache = biomeDepthCache
    target.biomeEncounterDepth = biomeEncounterDepth
    return target
end

local function routeWalkContext(route, routeState, biomeState, routeBiomeIndex, biomeKey, row, rowCost)
    return {
        route = route,
        routeKey = route and route.key or nil,
        routeBiomeIndex = routeBiomeIndex,
        biomeKey = biomeKey,
        row = row,
        rowIndex = row and row.rowIndex or nil,
        routeOrdinal = routeState.routeOrdinal,
        roomHistoryOrdinal = routeState.roomHistoryOrdinal,
        runDepthCache = timeline.runDepthCache(routeState.roomHistoryOrdinal),
        runEncounterDepth = routeState.runEncounterDepth,
        roomHistoryDepth = biomeState.roomHistoryDepth,
        biomeDepthCache = row and row.biomeDepthCache or nil,
        biomeEncounterDepth = row and row.biomeEncounterDepth or nil,
        rowRoomHistoryCost = rowCost,
    }
end

local function afterBiomeContext(route, routeState, routeBiomeIndex, biomeKey, entry, entryCost)
    return {
        route = route,
        routeKey = route and route.key or nil,
        routeBiomeIndex = routeBiomeIndex,
        biomeKey = biomeKey,
        entry = entry,
        entryKey = entry and entry.key or nil,
        roomHistoryOrdinal = routeState.roomHistoryOrdinal,
        runDepthCache = timeline.runDepthCache(routeState.roomHistoryOrdinal),
        runEncounterDepth = routeState.runEncounterDepth,
        entryRoomHistoryCost = entryCost,
    }
end

local function advanceBiomeDepth(biomeState, rowCost)
    biomeState.roomHistoryOrdinal = biomeState.roomHistoryOrdinal + rowCost
    if biomeState.roomHistoryDepthOffset == nil then
        biomeState.roomHistoryDepthOffset = biomeState.roomHistoryOrdinal
    end
    biomeState.roomHistoryDepth = biomeState.roomHistoryOrdinal - biomeState.roomHistoryDepthOffset
end

function timeline.sideRoomContext(rowContext, sideRoom, cost)
    local sideCost = numericCost(cost, DEFAULT_ROOM_HISTORY_COST)
    local roomHistoryOrdinal = (rowContext and rowContext.roomHistoryOrdinal or 0) + sideCost
    local roomHistoryDepth = (rowContext and rowContext.roomHistoryDepth or 0) + sideCost
    return {
        route = rowContext and rowContext.route or nil,
        routeKey = rowContext and rowContext.routeKey or nil,
        routeBiomeIndex = rowContext and rowContext.routeBiomeIndex or nil,
        biomeKey = rowContext and rowContext.biomeKey or nil,
        row = rowContext and rowContext.row or nil,
        rowIndex = rowContext and rowContext.rowIndex or nil,
        routeOrdinal = rowContext and rowContext.routeOrdinal or nil,
        roomHistoryOrdinal = roomHistoryOrdinal,
        runDepthCache = timeline.runDepthCache(roomHistoryOrdinal),
        runEncounterDepth = rowContext and rowContext.runEncounterDepth or nil,
        roomHistoryDepth = roomHistoryDepth,
        sideRoom = sideRoom,
        sideRoomHistoryCost = sideCost,
    }
end

function timeline.walkRoute(route, opts)
    opts = opts or {}
    local snapshotForBiome = opts.snapshotForBiome
    local biomeLookup = opts.biomeLookup or {}
    local onRow = opts.onRow
    local onAfterBiomeEntry = opts.onAfterBiomeEntry
    local routeState = {
        routeOrdinal = 0,
        roomHistoryOrdinal = 0,
        runEncounterDepth = 1,
    }

    for routeBiomeIndex, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        local snapshot = snapshotForBiome ~= nil and snapshotForBiome(route.key, biomeKey) or nil
        local biomeState = {
            roomHistoryOrdinal = 0,
            roomHistoryDepth = 0,
        }
        for _, row in ipairs(snapshot and snapshot.rows or EMPTY_LIST) do
            local rowCost = timeline.rowRoomHistoryCost(row)
            local rowEncounterDepthCost = timeline.rowBiomeEncounterDepthCost(row)
            routeState.routeOrdinal = routeState.routeOrdinal + 1
            routeState.roomHistoryOrdinal = routeState.roomHistoryOrdinal + rowCost
            advanceBiomeDepth(biomeState, rowCost)
            if onRow ~= nil then
                    onRow(routeWalkContext(route, routeState, biomeState, routeBiomeIndex, biomeKey, row, rowCost))
                end
            if routeState.runEncounterDepth ~= nil and rowEncounterDepthCost ~= nil then
                routeState.runEncounterDepth = routeState.runEncounterDepth + rowEncounterDepthCost
            else
                routeState.runEncounterDepth = nil
            end
        end

        local biome = biomeLookup[biomeKey]
        for _, entry in ipairs(biome and biome.timeline and biome.timeline.afterBiome or EMPTY_LIST) do
            local entryCost = timeline.entryCost(entry)
            routeState.roomHistoryOrdinal = routeState.roomHistoryOrdinal + entryCost
            if onAfterBiomeEntry ~= nil then
                onAfterBiomeEntry(afterBiomeContext(route, routeState, routeBiomeIndex, biomeKey, entry, entryCost))
            end
        end
    end
end

return timeline
