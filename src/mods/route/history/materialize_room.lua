local materializeRoom = {}
local formAddress = import("mods/route/history/form_address.lua")

local function copyFields(target, fields)
    for key, value in pairs(fields or {}) do
        target[key] = value
    end
    return target
end

local function encounterCost(resolved)
    local cost = math.floor(tonumber(resolved and resolved.biomeEncounterDepthCost) or 0)
    if cost < 0 then
        return 0
    end
    return cost
end

local function entryEncounterCost(resolved)
    local cost = encounterCost(resolved)
    if cost > 0 then
        return 1
    end
    return 0
end

local function remainingEncounterCost(resolved)
    return encounterCost(resolved) - entryEncounterCost(resolved)
end

local function entryPhase(context)
    return {
        biomeDepthCache = context.biomeState.biomeDepthCache,
        biomeEncounterDepth = context.biomeState.biomeEncounterDepth,
        runEncounterDepth = context.routeState.runEncounterDepth,
        runDepthCache = 1 + context.routeState.roomHistoryOrdinal,
        roomHistoryOrdinal = context.routeState.roomHistoryOrdinal,
    }
end

function materializeRoom.enterRoom(context, resolved)
    local entryCost = entryEncounterCost(resolved)
    context.routeState.runEncounterDepth =
        context.routeState.runEncounterDepth + entryCost
    context.biomeState.biomeEncounterDepth =
        context.biomeState.biomeEncounterDepth + entryCost
end

function materializeRoom.emitRoom(context, selectedRow, resolved, fields)
    if resolved == nil or resolved.eventKey == nil or resolved.eventKey == "" then
        return nil
    end
    local committedRoomHistoryOrdinal =
        context.routeState.roomHistoryOrdinal + (resolved.roomHistoryCost or 0)
    local entry = context.routeHistory.emitAt(context.history, {
        routeKey = context.routeKey,
        controlName = context.snapshot.controlName,
        biomeKey = context.biome.key,
        routeBiomeIndex = context.routeBiomeIndex,
        rowIndex = selectedRow.rowIndex,
        formAddress = formAddress.withRowFallback(selectedRow.formAddress, selectedRow.rowIndex),
        routeOrdinal = resolved.routeOrdinal,
        roomHistoryOrdinal = committedRoomHistoryOrdinal,
        runDepthCache = 1 + committedRoomHistoryOrdinal,
        runEncounterDepth = context.routeState.runEncounterDepth,
        biomeDepthCache = context.biomeState.biomeDepthCache,
        biomeEncounterDepth = context.biomeState.biomeEncounterDepth,
    }, copyFields({
        kind = "room",
        eventKey = resolved.eventKey,
        groupKey = selectedRow.roleKey,
        eventSourceKind = "row",
        roomKey = resolved.roomKey,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        variantKey = selectedRow.variantKey,
        biomeDepthCacheCost = resolved.biomeDepthCacheCost,
        biomeEncounterDepthCost = resolved.biomeEncounterDepthCost,
        roomHistoryCost = resolved.roomHistoryCost,
        nextRoomTags = resolved.option and resolved.option.nextRoomTags or nil,
        tags = resolved.option and resolved.option.tags or nil,
        source = selectedRow,
    }, fields))

    entry.phases = {
        generated = context.nextGeneratedPhase,
        entry = entryPhase(context),
        offer = materializeRoom.offerPhase(context, entry, resolved),
    }
    return entry
end

function materializeRoom.offerPhase(context, entry, resolved)
    local remainingCost = remainingEncounterCost(resolved)
    return {
        biomeDepthCache = entry and entry.biomeDepthCache or nil,
        biomeEncounterDepth = entry and entry.biomeEncounterDepth + remainingCost or nil,
        runEncounterDepth = entry and entry.runEncounterDepth + remainingCost or nil,
        runDepthCache = context and 1 + context.routeState.roomHistoryOrdinal or nil,
        roomHistoryOrdinal = context and context.routeState.roomHistoryOrdinal or nil,
    }
end

function materializeRoom.advanceAfterRoom(context, resolved)
    context.routeState.runEncounterDepth =
        context.routeState.runEncounterDepth + remainingEncounterCost(resolved)
    context.routeState.roomHistoryOrdinal =
        context.routeState.roomHistoryOrdinal + (resolved.roomHistoryCost or 0)
    context.biomeState.biomeDepthCache =
        context.biomeState.biomeDepthCache + (resolved.biomeDepthCacheCost or 0)
    context.biomeState.biomeEncounterDepth =
        context.biomeState.biomeEncounterDepth + remainingEncounterCost(resolved)
end

function materializeRoom.stepRoom(context, selectedRow, resolved, opts)
    opts = opts or {}
    materializeRoom.enterRoom(context, resolved)
    local entry = materializeRoom.emitRoom(context, selectedRow, resolved, opts.fields)
    if entry == nil then
        materializeRoom.advanceAfterRoom(context, resolved)
        return nil
    end
    if opts.attachReward ~= false then
        entry.reward = opts.reward
    end
    if opts.attachTopology ~= nil then
        opts.attachTopology(entry)
    end
    context.nextGeneratedPhase = entry.phases.offer
    materializeRoom.advanceAfterRoom(context, resolved)
    return entry
end

return materializeRoom
