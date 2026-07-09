local plannerOptions = import("mods/ui/planner/options.lua")

local materialization = {}

function materialization.defaultPayloadForRewardType(catalog, rewardType)
    return plannerOptions.defaultPayloadForRewardType(catalog, rewardType)
end

function materialization.ensureGeneratedDoorOffer(catalog, door)
    door.offerPoint = door.offerPoint or plannerOptions.defaultGeneratedDoorOfferPoint(catalog)
    door.offerPoint.kind = door.offerPoint.kind or "generatedDoorRewards"
    door.offerPoint.batchKey = door.offerPoint.batchKey or "nextDoors"
    door.offerPoint.offers = door.offerPoint.offers or { plannerOptions.defaultOffer(catalog, "RunProgress") }
    door.offerPoint.offers[1] = door.offerPoint.offers[1] or plannerOptions.defaultOffer(catalog, "RunProgress")
    return door.offerPoint.offers[1]
end

function materialization.ensureRoomOffer(catalog, biome, room)
    room.offerPoints = plannerOptions.materializedRoomOfferPoints(catalog, biome.biomeKey, room.roomKey, room.offerPoints)
    local roomDeclaration = plannerOptions.roomDeclaration(catalog, biome.biomeKey, room.roomKey)
    room.offerPoints = room.offerPoints or { plannerOptions.defaultRoomOfferPoint(catalog, roomDeclaration or { key = room.roomKey }) }
    room.offerPoints[1] = room.offerPoints[1] or plannerOptions.defaultRoomOfferPoint(catalog, roomDeclaration or { key = room.roomKey })
    room.offerPoints[1].offers = room.offerPoints[1].offers or { plannerOptions.defaultOffer(catalog, "WorldShop") }
    room.offerPoints[1].offers[1] = room.offerPoints[1].offers[1] or plannerOptions.defaultOffer(catalog, "WorldShop")
    return room.offerPoints[1].offers[1]
end

function materialization.offerPayload(catalog, offer)
    if offer.payload == nil then
        offer.payload = materialization.defaultPayloadForRewardType(catalog, offer.rewardType)
    end
    if offer.rewardType == "Devotion" then
        offer.payload.sources = offer.payload.sources or materialization.defaultPayloadForRewardType(catalog, "Devotion").sources
    end
end

function materialization.generatedDoorOffer(catalog, door)
    local offer = materialization.ensureGeneratedDoorOffer(catalog, door)
    materialization.offerPayload(catalog, offer)
end

function materialization.roomOffer(catalog, biome, room)
    local offer = materialization.ensureRoomOffer(catalog, biome, room)
    materialization.offerPayload(catalog, offer)
end

function materialization.draftForRebuild(catalog, biome)
    for _, room in ipairs((biome and biome.rooms) or {}) do
        if room.offerPoints ~= nil then
            materialization.roomOffer(catalog, biome, room)
        end

        local generatedDoors = room.generatedDoors
        if generatedDoors ~= nil then
            for _, door in ipairs(generatedDoors.doors or {}) do
                materialization.generatedDoorOffer(catalog, door)
            end
        end
    end
end

return materialization
