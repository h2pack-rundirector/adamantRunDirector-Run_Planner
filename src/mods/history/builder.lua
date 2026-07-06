local guard = import("mods/declarations/guard.lua")
local address = import("mods/forms/address.lua")

local builder = {}

local function newHistory(routeKey)
    return {
        routeKey = routeKey,
        events = {},
        roomHistory = {},
        encounterHistory = {},
        generatedDoorHistory = {},
        rewardOfferHistory = {},
        lootHistory = {},
        counters = {
            runEncounterDepth = 0,
            roomHistoryOrdinal = 0,
            biomeDepthCache = {},
            biomeEncounterDepth = {},
        },
    }
end

local function pushEvent(history, event)
    event.eventIndex = #history.events + 1
    history.events[event.eventIndex] = event
    return event
end

local function roomAddress(routeKey, biomeIndex, roomIndex)
    return address.room(routeKey, biomeIndex, roomIndex)
end

local function doorAddress(routeKey, biomeIndex, roomIndex, doorIndex)
    return address.door(routeKey, biomeIndex, roomIndex, doorIndex)
end

local function offerAddress(routeKey, biomeIndex, roomIndex, doorIndex, offerIndex)
    return address.offer(routeKey, biomeIndex, roomIndex, doorIndex, offerIndex)
end

local function expectCatalog(catalog)
    guard.expectTable(catalog, "history.catalog")
    guard.expectTable(catalog.biomes, "history.catalog.biomes")
    guard.expectTable(catalog.biomes.lookup, "history.catalog.biomes.lookup")
end

local function getBiomeDeclaration(catalog, biomeKey, context)
    local biome = catalog.biomes.lookup[biomeKey]
    if biome == nil then
        guard.fail(context, "unknown biome '" .. tostring(biomeKey) .. "'")
    end
    return biome
end

local function getRoomDeclaration(biome, roomKey, context)
    local room = biome.rooms.lookup[roomKey]
    if room == nil then
        guard.fail(context, "unknown room '" .. tostring(roomKey) .. "'")
    end
    return room
end

local function ensureBiomeCounters(history, biomeKey)
    if history.counters.biomeDepthCache[biomeKey] == nil then
        history.counters.biomeDepthCache[biomeKey] = 0
    end
    if history.counters.biomeEncounterDepth[biomeKey] == nil then
        history.counters.biomeEncounterDepth[biomeKey] = 0
    end
end

local function emitRoomEnter(history, routeKey, biomeIndex, biomeKey, roomIndex, roomNode)
    return pushEvent(history, {
        kind = "room.enter",
        phase = "room.enter",
        sourceAddress = roomAddress(routeKey, biomeIndex, roomIndex),
        biomeKey = biomeKey,
        roomIndex = roomIndex,
        roomKey = roomNode.roomKey,
    })
end

local function emitDoorAcquisitions(history, routeKey, biomeIndex, biomeKey, roomIndex, previousRoomNode)
    if previousRoomNode == nil or previousRoomNode.generatedDoors == nil then
        return
    end

    local generatedDoors = previousRoomNode.generatedDoors
    local selectedDoor = generatedDoors.doors[generatedDoors.selectedDoorIndex]
    if selectedDoor == nil or selectedDoor.offerPoint == nil then
        return
    end

    for offerIndex, offer in ipairs(selectedDoor.offerPoint.offers or {}) do
        if offer.acquired then
            local acquireEvent = pushEvent(history, {
                kind = "reward.acquire",
                phase = "room.enter",
                sourceAddress = offerAddress(routeKey, biomeIndex, roomIndex - 1, generatedDoors.selectedDoorIndex, offerIndex),
                biomeKey = biomeKey,
                targetRoomIndex = roomIndex,
                sourceRoomIndex = roomIndex - 1,
                doorIndex = generatedDoors.selectedDoorIndex,
                store = offer.store,
                rewardType = offer.rewardType,
                payload = offer.payload,
            })
            history.lootHistory[#history.lootHistory + 1] = acquireEvent
        end
    end
end

local function emitEncounter(history, routeKey, biomeIndex, biomeKey, roomIndex, roomNode, roomDeclaration)
    local counters = roomDeclaration.counters or {}
    local encounterDepthCost = counters.biomeEncounterDepthCost or 0
    if encounterDepthCost == 0 then
        return
    end

    local beforeRun = history.counters.runEncounterDepth
    local beforeBiome = history.counters.biomeEncounterDepth[biomeKey]
    history.counters.runEncounterDepth = beforeRun + encounterDepthCost
    history.counters.biomeEncounterDepth[biomeKey] = beforeBiome + encounterDepthCost

    local event = pushEvent(history, {
        kind = "encounter.start",
        phase = "room.encounters",
        sourceAddress = roomAddress(routeKey, biomeIndex, roomIndex),
        biomeKey = biomeKey,
        roomIndex = roomIndex,
        roomKey = roomNode.roomKey,
        encounterDepthCost = encounterDepthCost,
        runEncounterDepthBefore = beforeRun,
        runEncounterDepthAfter = history.counters.runEncounterDepth,
        biomeEncounterDepthBefore = beforeBiome,
        biomeEncounterDepthAfter = history.counters.biomeEncounterDepth[biomeKey],
    })
    history.encounterHistory[#history.encounterHistory + 1] = event
end

local function emitGeneratedDoorOffers(history, routeKey, biomeIndex, biomeKey, roomIndex, doorIndex, door)
    if door.offerPoint == nil then
        return
    end

    local offerPointEvent = pushEvent(history, {
        kind = "offer_point.emit",
        phase = "room.generate_next",
        sourceAddress = doorAddress(routeKey, biomeIndex, roomIndex, doorIndex),
        biomeKey = biomeKey,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
        offerPointKind = door.offerPoint.kind,
        batchKey = door.offerPoint.batchKey,
    })

    for offerIndex, offer in ipairs(door.offerPoint.offers or {}) do
        local offerEvent = pushEvent(history, {
            kind = "reward.offer",
            phase = "room.generate_next",
            sourceAddress = offerAddress(routeKey, biomeIndex, roomIndex, doorIndex, offerIndex),
            offerPointEventIndex = offerPointEvent.eventIndex,
            biomeKey = biomeKey,
            roomIndex = roomIndex,
            doorIndex = doorIndex,
            offerIndex = offerIndex,
            store = offer.store,
            rewardType = offer.rewardType,
            acquired = offer.acquired,
            payload = offer.payload,
        })
        history.rewardOfferHistory[#history.rewardOfferHistory + 1] = offerEvent
    end
end

local function emitGenerateNext(history, routeKey, biomeIndex, biomeKey, roomIndex, roomNode)
    local generatedDoors = roomNode.generatedDoors
    if generatedDoors == nil then
        return
    end

    pushEvent(history, {
        kind = "room.generate_next",
        phase = "room.generate_next",
        sourceAddress = roomAddress(routeKey, biomeIndex, roomIndex),
        biomeKey = biomeKey,
        roomIndex = roomIndex,
        roomKey = roomNode.roomKey,
        batchRule = generatedDoors.batchRule,
        selectedDoorIndex = generatedDoors.selectedDoorIndex,
    })

    for doorIndex, door in ipairs(generatedDoors.doors or {}) do
        local doorEvent = pushEvent(history, {
            kind = "generated_door",
            phase = "room.generate_next",
            sourceAddress = doorAddress(routeKey, biomeIndex, roomIndex, doorIndex),
            biomeKey = biomeKey,
            roomIndex = roomIndex,
            roomKey = roomNode.roomKey,
            doorIndex = doorIndex,
            exitIndex = door.exitIndex,
            targetRoomKey = door.targetRoomKey,
            selected = generatedDoors.selectedDoorIndex == doorIndex,
        })
        history.generatedDoorHistory[#history.generatedDoorHistory + 1] = doorEvent
        emitGeneratedDoorOffers(history, routeKey, biomeIndex, biomeKey, roomIndex, doorIndex, door)
    end
end

local function emitRoomCommit(history, routeKey, biomeIndex, biomeKey, roomIndex, roomNode, roomDeclaration)
    local counters = roomDeclaration.counters or {}
    local depthCost = counters.biomeDepthCacheCost or 0
    local beforeDepth = history.counters.biomeDepthCache[biomeKey]
    local beforeOrdinal = history.counters.roomHistoryOrdinal

    history.counters.biomeDepthCache[biomeKey] = beforeDepth + depthCost
    history.counters.roomHistoryOrdinal = beforeOrdinal + (counters.roomHistoryCost or 1)

    local event = pushEvent(history, {
        kind = "room.commit",
        phase = "room.commit",
        sourceAddress = roomAddress(routeKey, biomeIndex, roomIndex),
        biomeKey = biomeKey,
        roomIndex = roomIndex,
        roomKey = roomNode.roomKey,
        roomHistoryOrdinalBefore = beforeOrdinal,
        roomHistoryOrdinalAfter = history.counters.roomHistoryOrdinal,
        biomeDepthCacheBefore = beforeDepth,
        biomeDepthCacheAfter = history.counters.biomeDepthCache[biomeKey],
    })
    history.roomHistory[#history.roomHistory + 1] = event
end

local function materializeRoom(history, routeKey, biomeIndex, biome, biomePlan, roomIndex)
    local roomNode = biomePlan.rooms[roomIndex]
    guard.expectTable(roomNode, "history.plan.biomes[" .. tostring(biomeIndex) .. "].rooms[" .. tostring(roomIndex) .. "]")
    guard.expectString(roomNode.roomKey, "history.plan.biomes[" .. tostring(biomeIndex) .. "].rooms[" .. tostring(roomIndex) .. "].roomKey")

    local roomDeclaration = getRoomDeclaration(biome, roomNode.roomKey, "history.plan.roomKey")
    local previousRoomNode = biomePlan.rooms[roomIndex - 1]

    emitRoomEnter(history, routeKey, biomeIndex, biomePlan.biomeKey, roomIndex, roomNode)
    emitDoorAcquisitions(history, routeKey, biomeIndex, biomePlan.biomeKey, roomIndex, previousRoomNode)
    emitEncounter(history, routeKey, biomeIndex, biomePlan.biomeKey, roomIndex, roomNode, roomDeclaration)
    emitGenerateNext(history, routeKey, biomeIndex, biomePlan.biomeKey, roomIndex, roomNode)
    emitRoomCommit(history, routeKey, biomeIndex, biomePlan.biomeKey, roomIndex, roomNode, roomDeclaration)
end

local function materializeBiome(history, catalog, routeKey, biomeIndex, biomePlan)
    guard.expectTable(biomePlan, "history.plan.biomes[" .. tostring(biomeIndex) .. "]")
    local biomeKey = guard.expectString(biomePlan.biomeKey, "history.plan.biomes[" .. tostring(biomeIndex) .. "].biomeKey")
    guard.expectNonEmptyArray(biomePlan.rooms, "history.plan.biomes[" .. tostring(biomeIndex) .. "].rooms")

    local biome = getBiomeDeclaration(catalog, biomeKey, "history.plan.biomes[" .. tostring(biomeIndex) .. "].biomeKey")
    ensureBiomeCounters(history, biomeKey)

    for roomIndex, _ in ipairs(biomePlan.rooms) do
        materializeRoom(history, routeKey, biomeIndex, biome, biomePlan, roomIndex)
    end
end

function builder.build(plan, context)
    context = context or {}
    expectCatalog(context.catalog)

    guard.expectTable(plan, "history.plan")
    local routeKey = guard.expectString(plan.routeKey, "history.plan.routeKey")
    guard.expectNonEmptyArray(plan.biomes, "history.plan.biomes")

    local history = newHistory(routeKey)
    for biomeIndex, biomePlan in ipairs(plan.biomes) do
        materializeBiome(history, context.catalog, routeKey, biomeIndex, biomePlan)
    end

    return history
end

return builder
