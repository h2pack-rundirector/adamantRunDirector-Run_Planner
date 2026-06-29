local deps = ... or {}

local routeHistory = deps.history
local adapters = deps.adapters or {}

local historyBuilder = {}

local EMPTY_LIST = {}

local function numericCost(value, fallback)
    local cost = math.floor(tonumber(value) or fallback or 0)
    if cost < 0 then
        return 0
    end
    return cost
end

local function timelineEventKey(entry)
    return entry and (entry.roomKey or entry.key) or nil
end

local function appendAfterBiomeEntry(history, route, routeState, routeBiomeIndex, biomeKey, entry)
    routeState.roomHistoryOrdinal = routeState.roomHistoryOrdinal + numericCost(entry and entry.roomHistoryCost, 1)

    local eventKey = timelineEventKey(entry)
    if eventKey == nil or eventKey == "" then
        return
    end

    routeHistory.emitAt(history, {
        routeKey = route and route.key or nil,
        biomeKey = biomeKey,
        routeBiomeIndex = routeBiomeIndex,
        roomHistoryOrdinal = routeState.roomHistoryOrdinal,
        runDepthCache = 1 + routeState.roomHistoryOrdinal,
        runEncounterDepth = routeState.runEncounterDepth,
    }, {
        kind = "room",
        eventKey = eventKey,
        groupKey = entry.key,
        sourceKind = "afterBiome",
        roomKey = entry.roomKey,
        entryKey = entry.key,
        entryLabel = entry.label,
        source = entry,
    })
end

function historyBuilder.build(args)
    args = args or {}
    local history = routeHistory.create()
    local route = args.route
    local routeState = {
        roomHistoryOrdinal = 0,
        runEncounterDepth = 1,
    }

    for routeBiomeIndex, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        local snapshot = args.snapshotForBiome and args.snapshotForBiome(route.key, biomeKey) or nil
        local biome = args.biomeLookup and args.biomeLookup[biomeKey] or nil
        local adapter = snapshot and biome and adapters[biome.adapter] or nil
        local builtBiome = false
        if adapter ~= nil then
            adapter.build({
                history = history,
                routeHistory = routeHistory,
                route = route,
                routeBiomeIndex = routeBiomeIndex,
                routeState = routeState,
                snapshot = snapshot,
                biome = biome,
            })
            builtBiome = true
        end

        if builtBiome then
            for _, entry in ipairs(biome and biome.timeline and biome.timeline.afterBiome or EMPTY_LIST) do
                appendAfterBiomeEntry(history, route, routeState, routeBiomeIndex, biomeKey, entry)
            end
        end
    end

    return history
end

return historyBuilder
