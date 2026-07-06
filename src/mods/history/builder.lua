local guard = import("mods/declarations/guard.lua")
local address = import("mods/forms/address.lua")

local builder = {}

local function newHistory(routeKey, initialClearedBiomes)
    return {
        routeKey = routeKey,
        initialClearedBiomes = initialClearedBiomes or 0,
        events = {},
        roomHistory = {},
        clearedBiomeHistory = {},
        encounterHistory = {},
        generatedDoorHistory = {},
        rewardOfferHistory = {},
        lootHistory = {},
        pendingStoreOfferHistory = {},
        candidateRecords = {},
        counters = {
            clearedBiomes = initialClearedBiomes or 0,
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
    guard.expectTable(catalog.rewards, "history.catalog.rewards")
    guard.expectTable(catalog.rewards.primitives, "history.catalog.rewards.primitives")
    guard.expectTable(catalog.rewards.bags, "history.catalog.rewards.bags")
    guard.expectTable(catalog.rewards.shops, "history.catalog.rewards.shops")
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

local function matchingBagEntry(catalog, storeKey, rewardType)
    local bag = catalog.rewards.bags[storeKey]
    if bag == nil then
        return nil
    end

    for _, entry in ipairs(bag.entries or {}) do
        if entry.rewardType == rewardType then
            return entry
        end
    end
    return nil
end

local function matchingShopOption(catalog, shopKey, rewardType)
    local shop = catalog.rewards.shops[shopKey]
    if shop == nil then
        return nil
    end

    for _, slot in ipairs(shop.slots or {}) do
        for _, option in ipairs(slot.options or {}) do
            if option.rewardType == rewardType then
                return option
            end
        end
    end
    return nil
end

local function acquiredLootType(catalog, offer)
    local entry = matchingBagEntry(catalog, offer.store, offer.rewardType)
        or matchingShopOption(catalog, offer.store, offer.rewardType)
    if entry ~= nil and entry.acquiredLootType ~= nil then
        return entry.acquiredLootType
    end

    local primitive = catalog.rewards.primitives[offer.rewardType]
    if primitive ~= nil and primitive.acquiredLootType ~= nil then
        return primitive.acquiredLootType
    end

    return offer.rewardType
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

local function emitDoorAcquisitions(history, catalog, routeKey, biomeIndex, biomeKey, roomIndex, previousRoomNode)
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
                acquiredLootType = acquiredLootType(catalog, offer),
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
        biomeDepthCache = history.counters.biomeDepthCache[biomeKey],
        biomeEncounterDepth = history.counters.biomeEncounterDepth[biomeKey],
        runEncounterDepth = history.counters.runEncounterDepth,
        roomHistoryOrdinal = history.counters.roomHistoryOrdinal,
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

local function emitBiomeComplete(history, routeKey, biomeIndex, biomeKey)
    local before = history.counters.clearedBiomes
    history.counters.clearedBiomes = before + 1

    local event = pushEvent(history, {
        kind = "biome.complete",
        phase = "biome.complete",
        sourceAddress = address.biome(routeKey, biomeIndex),
        biomeKey = biomeKey,
        biomeIndex = biomeIndex,
        clearedBiomesBefore = before,
        clearedBiomesAfter = history.counters.clearedBiomes,
    })
    history.clearedBiomeHistory[#history.clearedBiomeHistory + 1] = event
end

local function materializeRoom(history, catalog, routeKey, biomeIndex, biome, biomePlan, roomIndex)
    local roomNode = biomePlan.rooms[roomIndex]
    guard.expectTable(roomNode, "history.plan.biomes[" .. tostring(biomeIndex) .. "].rooms[" .. tostring(roomIndex) .. "]")
    guard.expectString(roomNode.roomKey, "history.plan.biomes[" .. tostring(biomeIndex) .. "].rooms[" .. tostring(roomIndex) .. "].roomKey")

    local roomDeclaration = getRoomDeclaration(biome, roomNode.roomKey, "history.plan.roomKey")
    local previousRoomNode = biomePlan.rooms[roomIndex - 1]

    emitRoomEnter(history, routeKey, biomeIndex, biomePlan.biomeKey, roomIndex, roomNode)
    emitDoorAcquisitions(history, catalog, routeKey, biomeIndex, biomePlan.biomeKey, roomIndex, previousRoomNode)
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
        materializeRoom(history, catalog, routeKey, biomeIndex, biome, biomePlan, roomIndex)
    end

    local finalRoom = biomePlan.rooms[#biomePlan.rooms]
    local finalRoomDeclaration = finalRoom ~= nil and biome.rooms.lookup[finalRoom.roomKey] or nil
    if finalRoomDeclaration ~= nil and finalRoomDeclaration.terminal then
        emitBiomeComplete(history, routeKey, biomeIndex, biomeKey)
    end
end

function builder.build(plan, context)
    context = context or {}
    expectCatalog(context.catalog)

    guard.expectTable(plan, "history.plan")
    local routeKey = guard.expectString(plan.routeKey, "history.plan.routeKey")
    guard.expectNonEmptyArray(plan.biomes, "history.plan.biomes")

    local history = newHistory(routeKey, guard.expectOptionalNumber(context.initialClearedBiomes, "history.initialClearedBiomes"))
    if context.candidateRecords ~= nil then
        history.candidateRecords = guard.expectArray(context.candidateRecords, "history.candidateRecords")
    end

    for biomeIndex, biomePlan in ipairs(plan.biomes) do
        materializeBiome(history, context.catalog, routeKey, biomeIndex, biomePlan)
    end

    return history
end

return builder
