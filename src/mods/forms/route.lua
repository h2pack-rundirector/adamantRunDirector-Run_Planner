local address = import("mods/forms/address.lua")
local completion = import("mods/forms/completion.lua")
local guard = import("mods/declarations/guard.lua")

local routeForm = {}

local UNRESOLVED_VALUES = {
    [""] = true,
    Auto = true,
    Vanilla = true,
    Major = true,
    Minor = true,
}

local function isConcreteString(value)
    return type(value) == "string" and not UNRESOLVED_VALUES[value]
end

local function copyTable(source)
    if source == nil then
        return nil
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = copyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function copyContext(context)
    local copy = {}
    for key, value in pairs(context or {}) do
        copy[key] = value
    end
    return copy
end

local function addConcreteStringFinding(result, value, fieldAddress, code, message, field)
    if not isConcreteString(value) then
        completion.add(result, fieldAddress, code, message, field)
        return false
    end
    return true
end

local function isArray(value)
    if type(value) ~= "table" then
        return false
    end
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
    end
    return true
end

local function getRoomDeclaration(catalog, biomeKey, roomKey)
    local biome = catalog.biomes.lookup[biomeKey]
    if biome == nil then
        return nil
    end
    return biome.rooms.lookup[roomKey]
end

local function validateOffer(result, offer, offerAddress)
    if type(offer) ~= "table" then
        completion.add(result, offerAddress, "reward_offer_required", "Reward offer must be filled.", "offer")
        return
    end

    addConcreteStringFinding(result, offer.store, offerAddress, "reward_store_required", "Reward store must be concrete.", "store")
    local hasConcreteRewardType = addConcreteStringFinding(result, offer.rewardType, offerAddress, "reward_type_required", "Reward type must be concrete.", "rewardType")

    if type(offer.acquired) ~= "boolean" then
        completion.add(result, offerAddress, "reward_acquired_required", "Reward acquisition flag must be set.", "acquired")
    end

    if offer.payload ~= nil and type(offer.payload) ~= "table" then
        completion.add(result, offerAddress, "reward_payload_invalid", "Reward payload must be a table when present.", "payload")
        return
    end

    if hasConcreteRewardType and offer.rewardType == "Devotion" then
        local payload = offer.payload
        if type(payload) ~= "table" or not isArray(payload.sources) or #payload.sources ~= 2 then
            completion.add(result, offerAddress, "devotion_sources_required", "Devotion requires two concrete source gods.", "payload.sources")
            return
        end

        for index, source in ipairs(payload.sources) do
            addConcreteStringFinding(
                result,
                source,
                offerAddress,
                "devotion_source_required",
                "Devotion source must be concrete.",
                "payload.sources[" .. tostring(index) .. "]"
            )
        end
    end
end

local function validateOfferPoint(result, offerPoint, offerAddress)
    if type(offerPoint) ~= "table" then
        completion.add(result, offerAddress, "offer_point_required", "Offer point must be filled.", "offerPoint")
        return
    end

    addConcreteStringFinding(result, offerPoint.kind, offerAddress, "offer_point_kind_required", "Offer point kind must be concrete.", "kind")

    if not isArray(offerPoint.offers) or #offerPoint.offers == 0 then
        completion.add(result, offerAddress, "offer_point_offers_required", "Offer point must contain concrete offers.", "offers")
        return
    end

    for offerIndex, offer in ipairs(offerPoint.offers) do
        validateOffer(result, offer, address.offer(offerAddress.routeKey, offerAddress.biomeIndex, offerAddress.roomIndex, offerAddress.doorIndex, offerIndex))
    end
end

local function validateGeneratedDoors(result, roomNode, nextRoomNode, roomAddress)
    local generatedDoors = roomNode.generatedDoors
    if type(generatedDoors) ~= "table" then
        completion.add(result, roomAddress, "generated_doors_required", "Generated doors must be filled.", "generatedDoors")
        return
    end

    addConcreteStringFinding(result, generatedDoors.batchRule, roomAddress, "generated_door_batch_rule_required", "Generated door batch rule must be concrete.", "batchRule")

    if type(generatedDoors.selectedDoorIndex) ~= "number" then
        completion.add(result, roomAddress, "selected_door_required", "Selected door index must be filled.", "selectedDoorIndex")
    end

    if not isArray(generatedDoors.doors) or #generatedDoors.doors == 0 then
        completion.add(result, roomAddress, "generated_door_list_required", "Generated doors must contain concrete peers.", "doors")
        return
    end

    if type(generatedDoors.selectedDoorIndex) == "number" and generatedDoors.doors[generatedDoors.selectedDoorIndex] == nil then
        completion.add(result, roomAddress, "selected_door_out_of_range", "Selected door index must reference a generated door.", "selectedDoorIndex")
    end

    for doorIndex, door in ipairs(generatedDoors.doors) do
        local doorAddress = address.door(roomAddress.routeKey, roomAddress.biomeIndex, roomAddress.roomIndex, doorIndex)
        if type(door) ~= "table" then
            completion.add(result, doorAddress, "generated_door_required", "Generated door must be filled.", "door")
        else
            if type(door.exitIndex) ~= "number" then
                completion.add(result, doorAddress, "generated_door_exit_required", "Generated door exit index must be filled.", "exitIndex")
            end
            addConcreteStringFinding(result, door.targetRoomKey, doorAddress, "generated_door_target_required", "Generated door target room must be concrete.", "targetRoomKey")
            validateOfferPoint(result, door.offerPoint, doorAddress)
        end
    end

    if nextRoomNode ~= nil and type(generatedDoors.selectedDoorIndex) == "number" then
        local selectedDoor = generatedDoors.doors[generatedDoors.selectedDoorIndex]
        if selectedDoor ~= nil and selectedDoor.targetRoomKey ~= nextRoomNode.roomKey then
            completion.add(result, roomAddress, "selected_door_target_mismatch", "Selected generated door must target the next room node.", "selectedDoorIndex")
        end
    end
end

local function validateRoom(result, catalog, routeKey, biomeKey, biomeIndex, rooms, roomIndex)
    local roomNode = rooms[roomIndex]
    local roomAddress = address.room(routeKey, biomeIndex, roomIndex)
    if type(roomNode) ~= "table" then
        completion.add(result, roomAddress, "room_node_required", "Room node must be filled.", "room")
        return
    end

    if not addConcreteStringFinding(result, roomNode.roomKey, roomAddress, "room_key_required", "Room key must be concrete.", "roomKey") then
        return
    end

    local roomDeclaration = getRoomDeclaration(catalog, biomeKey, roomNode.roomKey)
    local nextRoomNode = rooms[roomIndex + 1]
    local isTerminal = roomDeclaration ~= nil and roomDeclaration.terminal == true

    if not isTerminal then
        validateGeneratedDoors(result, roomNode, nextRoomNode, roomAddress)
    elseif roomNode.generatedDoors ~= nil and roomNode.generatedDoors.doors ~= nil and #roomNode.generatedDoors.doors > 0 then
        validateGeneratedDoors(result, roomNode, nextRoomNode, roomAddress)
    end
end

local function validateBiome(result, catalog, draft, route, biomeDraft, biomeIndex)
    local biomeAddress = address.biome(draft.routeKey, biomeIndex)
    if type(biomeDraft) ~= "table" then
        completion.add(result, biomeAddress, "biome_required", "Configured biome must be filled.", "biome")
        return
    end

    local expectedBiomeKey = route.biomeKeys[biomeIndex]
    if biomeDraft.biomeKey ~= expectedBiomeKey then
        completion.add(result, biomeAddress, "biome_prefix_mismatch", "Configured biomes must follow route order.", "biomeKey")
        return
    end

    if catalog.biomes.lookup[biomeDraft.biomeKey] == nil then
        completion.add(result, biomeAddress, "biome_not_implemented", "Configured biome declaration is not implemented.", "biomeKey")
        return
    end

    if not isArray(biomeDraft.rooms) or #biomeDraft.rooms == 0 then
        completion.add(result, biomeAddress, "biome_rooms_required", "Configured biome must contain room nodes.", "rooms")
        return
    end

    for roomIndex, _ in ipairs(biomeDraft.rooms) do
        validateRoom(result, catalog, draft.routeKey, biomeDraft.biomeKey, biomeIndex, biomeDraft.rooms, roomIndex)
    end
end

function routeForm.defaultDraft(context)
    context = context or {}
    return {
        routeKey = context.routeKey,
        biomes = {},
    }
end

function routeForm.isComplete(draft, context)
    context = context or {}
    local catalog = context.catalog
    local result = completion.ok()

    if type(catalog) ~= "table" then
        completion.add(result, {}, "catalog_required", "Route form requires a declaration catalog.", "catalog")
        return result
    end

    if type(draft) ~= "table" then
        completion.add(result, {}, "route_draft_required", "Route draft must be filled.", "draft")
        return result
    end

    local routeAddress = address.route(draft.routeKey)
    if not addConcreteStringFinding(result, draft.routeKey, routeAddress, "route_key_required", "Route key must be concrete.", "routeKey") then
        return result
    end

    local route = catalog.routes.lookup[draft.routeKey]
    if route == nil then
        completion.add(result, routeAddress, "route_unknown", "Route key must reference a declared route.", "routeKey")
        return result
    end

    if not isArray(draft.biomes) or #draft.biomes == 0 then
        completion.add(result, routeAddress, "configured_biomes_required", "At least one configured biome is required.", "biomes")
        return result
    end

    for biomeIndex, biomeDraft in ipairs(draft.biomes) do
        validateBiome(result, catalog, draft, route, biomeDraft, biomeIndex)
    end

    return result
end

local function materializeOffer(offer)
    return {
        store = offer.store,
        rewardType = offer.rewardType,
        acquired = offer.acquired,
        payload = copyTable(offer.payload),
    }
end

local function materializeOfferPoint(offerPoint)
    local offers = {}
    for index, offer in ipairs(offerPoint.offers) do
        offers[index] = materializeOffer(offer)
    end

    return {
        kind = offerPoint.kind,
        batchKey = offerPoint.batchKey,
        offers = offers,
    }
end

local function materializeGeneratedDoors(generatedDoors)
    if generatedDoors == nil then
        return nil
    end

    local doors = {}
    for index, door in ipairs(generatedDoors.doors or {}) do
        doors[index] = {
            exitIndex = door.exitIndex,
            targetRoomKey = door.targetRoomKey,
            offerPoint = materializeOfferPoint(door.offerPoint),
        }
    end

    return {
        batchRule = generatedDoors.batchRule,
        batchState = copyTable(generatedDoors.batchState),
        selectedDoorIndex = generatedDoors.selectedDoorIndex,
        doors = doors,
    }
end

local function materializeRoom(roomNode)
    return {
        roomKey = roomNode.roomKey,
        roomState = copyTable(roomNode.roomState),
        generatedDoors = materializeGeneratedDoors(roomNode.generatedDoors),
    }
end

local function materializeBiome(biomeDraft)
    local rooms = {}
    for index, roomNode in ipairs(biomeDraft.rooms) do
        rooms[index] = materializeRoom(roomNode)
    end

    return {
        biomeKey = biomeDraft.biomeKey,
        rooms = rooms,
    }
end

local function sortedProviderKeys(providers)
    local keys = {}
    for key, _ in pairs(providers) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function candidateContext(context, draft, biomeDraft, biomeIndex, roomNode, roomIndex, door, doorIndex)
    local exportContext = copyContext(context)
    exportContext.candidate = {
        routeKey = draft.routeKey,
        biomeKey = biomeDraft.biomeKey,
        biomeIndex = biomeIndex,
        sourceRoomKey = roomNode.roomKey,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
        exitIndex = door.exitIndex,
        targetRoomKey = door.targetRoomKey,
        selected = roomNode.generatedDoors.selectedDoorIndex == doorIndex,
    }
    return exportContext
end

local function exportProvider(out, provider, formAddress, context, providerContext)
    guard.expectTable(provider, providerContext)
    if type(provider.exportCandidates) ~= "function" then
        guard.fail(providerContext, "candidate provider must expose exportCandidates")
    end
    provider.exportCandidates(out, formAddress, context)
end

local function exportProviderMap(out, providers, formAddress, context, providerMapContext)
    if providers == nil then
        return
    end

    guard.expectTable(providers, providerMapContext)
    for _, key in ipairs(sortedProviderKeys(providers)) do
        exportProvider(out, providers[key], formAddress, context, providerMapContext .. "." .. tostring(key))
    end
end

local function exportDoorCandidates(out, draft, biomeDraft, biomeIndex, roomNode, roomIndex, door, doorIndex, context)
    local formAddress = address.door(draft.routeKey, biomeIndex, roomIndex, doorIndex)
    local exportContext = candidateContext(context, draft, biomeDraft, biomeIndex, roomNode, roomIndex, door, doorIndex)
    exportProviderMap(
        out,
        door.candidateProviders,
        formAddress,
        exportContext,
        "routeForm.biomes[" .. tostring(biomeIndex) .. "].rooms[" .. tostring(roomIndex) .. "].generatedDoors.doors[" .. tostring(doorIndex) .. "].candidateProviders"
    )
end

function routeForm.exportCandidates(draft, context, out)
    context = context or {}
    out = out or {}

    local completed = routeForm.isComplete(draft, context)
    if not completed.complete then
        error("Run Planner form invariant: cannot export candidate records from incomplete route draft", 2)
    end

    for biomeIndex, biomeDraft in ipairs(draft.biomes) do
        for roomIndex, roomNode in ipairs(biomeDraft.rooms) do
            if roomNode.generatedDoors ~= nil then
                for doorIndex, door in ipairs(roomNode.generatedDoors.doors or {}) do
                    exportDoorCandidates(out, draft, biomeDraft, biomeIndex, roomNode, roomIndex, door, doorIndex, context)
                end
            end
        end
    end

    return out
end

function routeForm.materialize(draft, context)
    local completed = routeForm.isComplete(draft, context)
    if not completed.complete then
        error("Run Planner form invariant: cannot materialize incomplete route draft", 2)
    end

    local biomes = {}
    for index, biomeDraft in ipairs(draft.biomes) do
        biomes[index] = materializeBiome(biomeDraft)
    end

    return {
        routeKey = draft.routeKey,
        biomes = biomes,
    }
end

return routeForm
