local common = import("mods/controls/PlannerDraft/codecs/common.lua")
local payloadCodec = import("mods/controls/PlannerDraft/codecs/payloads.lua")

local generatedDoorOffers = {}

local MAX_OFFERS = 768

local function offerFromRow(row)
    return {
        store = row.store,
        rewardType = row.rewardType,
        acquired = row.acquired == true,
        payload = payloadCodec.fromRow(row),
    }
end

local function readRow(rows, index)
    local row = {
        biomeIndex = rows:read(index, "BiomeIndex"),
        biomeKey = rows:read(index, "BiomeKey"),
        roomIndex = rows:read(index, "RoomIndex"),
        doorIndex = rows:read(index, "DoorIndex"),
        offerIndex = rows:read(index, "OfferIndex"),
        offerPointKind = rows:read(index, "OfferPointKind"),
        batchKey = rows:read(index, "BatchKey"),
        store = rows:read(index, "Store"),
        rewardType = rows:read(index, "RewardType"),
        acquired = rows:read(index, "Acquired"),
    }
    local payload = payloadCodec.readColumns(rows, index)
    row.payloadSource = payload.payloadSource
    row.payloadSourceA = payload.payloadSourceA
    row.payloadSourceB = payload.payloadSourceB
    return row
end

function generatedDoorOffers.storageNode()
    return {
        key = "GeneratedDoorOffers",
        type = "table",
        maxRows = MAX_OFFERS,
        defaultRows = 0,
        row = payloadCodec.appendStorageColumns(common.routeAddressRows({
            common.intField("DoorIndex", 1, 1, 16),
            common.intField("OfferIndex", 1, 1, 16),
            common.stringField("OfferPointKind", "", 64),
            common.stringField("BatchKey", "", 64),
            common.stringField("Store", "", 64),
            common.stringField("RewardType", "", 64),
            common.boolField("Acquired", false),
        })),
    }
end

function generatedDoorOffers.read(fields, draft)
    local rows = fields.GeneratedDoorOffers
    for index = 1, rows:count() do
        local row = readRow(rows, index)
        local biome = common.ensureBiome(draft, row.biomeIndex, row.biomeKey)
        local room = biome.rooms[row.roomIndex]
        local generatedDoors = room and room.generatedDoors or nil
        local door = generatedDoors and generatedDoors.doors[row.doorIndex] or nil
        if door ~= nil then
            door.offerPoint = door.offerPoint or {
                kind = row.offerPointKind,
                batchKey = row.batchKey,
                offers = {},
            }
            door.offerPoint.offers[row.offerIndex] = offerFromRow(row)
        end
    end
end

function generatedDoorOffers.append(fields, routeKey, biomeIndex, biomeKey, roomIndex, doorIndex, offerPoint, offerIndex, offer)
    local payload = payloadCodec.toColumns(offer)
    return fields.GeneratedDoorOffers:append({
        RouteKey = routeKey,
        BiomeIndex = biomeIndex,
        BiomeKey = biomeKey,
        RoomIndex = roomIndex,
        DoorIndex = doorIndex,
        OfferIndex = offerIndex,
        OfferPointKind = offerPoint.kind or "",
        BatchKey = offerPoint.batchKey or "",
        Store = offer.store or "",
        RewardType = offer.rewardType or "",
        Acquired = offer.acquired == true,
        PayloadSource = payload.PayloadSource,
        PayloadSourceA = payload.PayloadSourceA,
        PayloadSourceB = payload.PayloadSourceB,
    })
end

return generatedDoorOffers
