local materialization = import("mods/ui/planner/materialization.lua")
local plannerOptions = import("mods/ui/planner/options.lua")

local providerPreparation = {}

local function projectedSources(sources, sourceIndex, value)
    local projected = {}
    for index, source in ipairs(sources or {}) do
        projected[index] = source
    end
    projected[sourceIndex] = value
    return projected
end

local function rewardTypeOptionsFor(state, storeKey)
    return state.rewardTypeOptions[storeKey] or plannerOptions.empty()
end

local function attachRewardProvider(state, participant, offer)
    local rewardOptions = rewardTypeOptionsFor(state, offer.store)
    local provider = participant.providers.rewardType
    if provider == nil or provider.values ~= rewardOptions.values or provider.labels ~= rewardOptions.labels then
        provider = state.candidateProvider.create({
            key = "rewardType",
            version = state.providerVersion,
            values = rewardOptions.values,
            labels = rewardOptions.labels,
            semanticForValue = function(value, _, _, context)
                return {
                    kind = "rewardType",
                    store = context.candidate.store,
                    rewardType = value,
                    payload = materialization.defaultPayloadForRewardType(state.catalog, value),
                }
            end,
        })
        participant.providers.rewardType = provider
    else
        provider.version = state.providerVersion
    end
    offer.candidateProviders = nil
end

local function attachDevotionSourceProviders(state, participant, offer)
    if offer.rewardType ~= "Devotion" then
        participant.providers.devotionSource1 = nil
        participant.providers.devotionSource2 = nil
        return
    end

    for sourceIndex = 1, 2 do
        local slotIndex = sourceIndex
        local providerKey = "devotionSource" .. tostring(sourceIndex)
        local provider = participant.providers[providerKey]
        if provider == nil
            or provider.values ~= state.boonSourceOptions.values
            or provider.labels ~= state.boonSourceOptions.labels
        then
            provider = state.candidateProvider.create({
                key = providerKey,
                version = state.providerVersion,
                values = state.boonSourceOptions.values,
                labels = state.boonSourceOptions.labels,
                semanticForValue = function(value, _, _, _context)
                    return {
                        kind = "devotionSource",
                        sourceIndex = slotIndex,
                        source = value,
                        sources = projectedSources(participant.node.payload.sources, slotIndex, value),
                    }
                end,
            })
            participant.providers[providerKey] = provider
        else
            provider.version = state.providerVersion
        end
    end
end

local function generatedDoorContext(state, biomeIndex, roomIndex, doorIndex)
    return {
        routeKey = state.draft.routeKey,
        biomeIndex = biomeIndex,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
    }
end

local function attachGeneratedDoorProvider(state, room, door, context)
    local participant = state.participants:generatedDoor(context, door)
    participant.roomKey = room.roomKey
    participant.exitIndex = door.exitIndex
    local provider = participant.providers.nextDoorTarget
    if provider == nil or provider.values ~= state.roomOptions.values or provider.labels ~= state.roomOptions.labels then
        provider = state.candidateProvider.create({
            key = "nextDoorTarget",
            version = state.providerVersion,
            values = state.roomOptions.values,
            labels = state.roomOptions.labels,
            semanticForValue = function(value, _, _, candidateContext)
                return {
                    kind = "nextRoom",
                    biomeKey = candidateContext.candidate.biomeKey,
                    sourceRoomKey = candidateContext.candidate.sourceRoomKey,
                    exitIndex = candidateContext.candidate.exitIndex,
                    targetRoomKey = value,
                }
            end,
        })
        participant.providers.nextDoorTarget = provider
    else
        provider.version = state.providerVersion
    end
    door.candidateProviders = nil
end

function providerPreparation.prepare(state)
    local biome = state.currentBiome()
    local biomeIndex = 1
    for roomIndex, room in ipairs((biome and biome.rooms) or {}) do
        local roomContext = {
            routeKey = state.draft.routeKey,
            biomeIndex = biomeIndex,
            roomIndex = roomIndex,
        }
        state.participants:room(roomContext, room)

        for offerPointIndex, offerPoint in ipairs(room.offerPoints or {}) do
            for offerIndex, offer in ipairs(offerPoint.offers or {}) do
                local participant = state.participants:roomOffer(roomContext, offerPointIndex, offerIndex, offer)
                attachRewardProvider(state, participant, offer)
            end
        end

        local generatedDoors = room.generatedDoors
        if generatedDoors ~= nil then
            for doorIndex, door in ipairs(generatedDoors.doors or {}) do
                local context = generatedDoorContext(state, biomeIndex, roomIndex, doorIndex)
                attachGeneratedDoorProvider(state, room, door, context)

                local offer = door.offerPoint.offers[1]
                local participant = state.participants:generatedOffer(context, 1, offer)
                attachRewardProvider(state, participant, offer)
                attachDevotionSourceProviders(state, participant, offer)
            end
        end
    end
end

return providerPreparation
